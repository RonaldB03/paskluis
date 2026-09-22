-- Bind access to the authenticated Supabase session, not a client device label.
-- Existing devices bind their legacy row on the next successful validation.
begin;
alter table public.account_device_sessions add column if not exists session_id uuid;
create or replace function public.has_active_device_session() returns boolean
language sql stable security definer set search_path = '' as $$
 select auth.uid() is not null and exists (
 select 1 from public.account_device_sessions d where d.user_id=auth.uid()
 and d.session_id=nullif(auth.jwt()->>'session_id','')::uuid);
$$;
create or replace function public.require_active_device_session() returns void
language plpgsql security definer set search_path = '' as $$
begin
 if not public.has_active_device_session() then
  raise exception 'SESSION_REPLACED' using errcode='42501';
 end if;
end; $$;
create or replace function public.check_device_session(p_device_id text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  current_session public.account_device_sessions%rowtype;
begin
  if auth.uid() is null then raise exception 'Not authenticated'; end if;
  select * into current_session
  from public.account_device_sessions
  where user_id = auth.uid();

  if not found then
    return jsonb_build_object(
      'has_active_device', false,
      'is_current_device', false,
      'active_device_name', ''
    );
  end if;

  return jsonb_build_object(
    'has_active_device', true,
    'is_current_device', current_session.device_id = p_device_id and (current_session.session_id is null or current_session.session_id = nullif(auth.jwt()->>'session_id','')::uuid),
    'active_device_name', current_session.device_name
  );
end;
$$;

create or replace function public.claim_device_session(
  p_device_id text,
  p_device_name text,
  p_replace boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  current_session public.account_device_sessions%rowtype;
begin
  if auth.uid() is null then raise exception 'Not authenticated'; end if;

  select * into current_session
  from public.account_device_sessions
  where user_id = auth.uid()
  for update;

  if not found then
    insert into public.account_device_sessions (
      user_id, device_id, device_name, last_seen_at, updated_at, session_id
    ) values (
      auth.uid(), p_device_id, left(coalesce(p_device_name, 'Apparaat'), 80), now(), now(), nullif(auth.jwt()->>'session_id','')::uuid
    )
    on conflict (user_id) do nothing;

    select * into current_session
    from public.account_device_sessions
    where user_id = auth.uid()
    for update;
  end if;

  if (current_session.device_id = p_device_id and (current_session.session_id is null or current_session.session_id = nullif(auth.jwt()->>'session_id','')::uuid)) or p_replace then
    update public.account_device_sessions
    set device_id = p_device_id,
        session_id = nullif(auth.jwt()->>'session_id','')::uuid,
        device_name = left(coalesce(p_device_name, 'Apparaat'), 80),
        last_seen_at = now(),
        updated_at = now()
    where user_id = auth.uid();
    delete from public.push_device_tokens where user_id=auth.uid() and device_id<>p_device_id;
    return jsonb_build_object('allowed', true);
  end if;

  return jsonb_build_object(
    'allowed', false,
    'active_device_name', current_session.device_name
  );
end;
$$;

create or replace function public.validate_device_session(p_device_id text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then return false; end if;
  update public.account_device_sessions
  set last_seen_at = now(), session_id = nullif(auth.jwt()->>'session_id','')::uuid
  where user_id = auth.uid() and device_id = p_device_id
    and (session_id is null or session_id = nullif(auth.jwt()->>'session_id','')::uuid);
  return found;
end;
$$;

create or replace function public.release_device_session(p_device_id text)
returns void
language sql
security definer
set search_path = public
as $$
  delete from public.account_device_sessions
  where user_id = auth.uid() and device_id = p_device_id
    and session_id = nullif(auth.jwt()->>'session_id','')::uuid;
$$;

revoke all on function public.check_device_session(text) from public;
revoke all on function public.claim_device_session(text, text, boolean) from public;
revoke all on function public.validate_device_session(text) from public;
revoke all on function public.release_device_session(text) from public;
grant execute on function public.check_device_session(text) to authenticated;
grant execute on function public.claim_device_session(text, text, boolean) to authenticated;
grant execute on function public.validate_device_session(text) to authenticated;
grant execute on function public.release_device_session(text) to authenticated;

drop policy if exists "Active session required" on public.shared_cards;
create policy "Active session required" on public.shared_cards as restrictive to authenticated using (public.has_active_device_session()) with check (public.has_active_device_session());

drop policy if exists "Active session required" on public.card_share_members;
create policy "Active session required" on public.card_share_members as restrictive to authenticated using (public.has_active_device_session()) with check (public.has_active_device_session());

drop policy if exists "Active session required" on public.card_share_events;
create policy "Active session required" on public.card_share_events as restrictive to authenticated using (public.has_active_device_session()) with check (public.has_active_device_session());

drop policy if exists "Active session required" on public.gift_card_shares;
create policy "Active session required" on public.gift_card_shares as restrictive to authenticated using (public.has_active_device_session()) with check (public.has_active_device_session());
drop policy if exists "Active session required" on public.entitlements;
create policy "Active session required" on public.entitlements as restrictive to authenticated
using (public.has_active_device_session() or public.is_staff()) with check (public.is_admin());

create or replace function public.share_card_by_email(
  p_recipient_email text,
  p_card_external_id text,
  p_card_type text,
  p_card_payload jsonb
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_recipient uuid;
  v_card public.shared_cards;
  v_member uuid;
begin
  perform public.require_active_device_session();
  if auth.uid() is null then raise exception 'Je moet ingelogd zijn.'; end if;
  if not public.has_paskluis_plus(auth.uid()) then
    raise exception 'PasKluis Plus is vereist om kaarten te delen.';
  end if;
  if p_card_external_id is null or trim(p_card_external_id) = '' then
    raise exception 'Deze kaart heeft geen geldig kaartnummer.';
  end if;
  if p_card_type not in ('Pasje', 'QR-code', 'QR-set', 'Cadeaukaart') then
    raise exception 'Dit kaarttype kan niet worden gedeeld.';
  end if;

  select id into v_recipient
  from public.profiles
  where lower(email) = lower(trim(p_recipient_email))
  limit 1;
  if v_recipient is null then
    raise exception 'Geen PasKluis-account gevonden met dit e-mailadres.';
  end if;
  if v_recipient = auth.uid() then
    raise exception 'Je kunt een kaart niet met jezelf delen.';
  end if;

  insert into public.shared_cards (
    owner_id, card_external_id, card_type, card_payload, updated_by
  ) values (
    auth.uid(), p_card_external_id, p_card_type, p_card_payload, auth.uid()
  )
  on conflict (owner_id, card_external_id) do update
    set deleted_at = null
  returning * into v_card;

  insert into public.card_share_members (
    shared_card_id, recipient_id, recipient_email
  ) values (
    v_card.id, v_recipient, lower(trim(p_recipient_email))
  )
  on conflict (shared_card_id, recipient_id) do update
    set recipient_email = excluded.recipient_email,
        revoked_at = null,
        removed_by_recipient_at = null
  returning id into v_member;

  insert into public.card_share_events (shared_card_id, actor_id, action, version)
  values (v_card.id, auth.uid(), 'shared', v_card.version);

  return jsonb_build_object(
    'membership_id', v_member,
    'shared_card_id', v_card.id,
    'version', v_card.version,
    'recipient_can_edit', public.has_paskluis_plus(v_recipient)
  );
end;
$$;

create or replace function public.update_shared_card(
  p_shared_card_id uuid,
  p_expected_version bigint,
  p_card_payload jsonb
) returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  v_card public.shared_cards;
  v_next_version bigint;
begin
  perform public.require_active_device_session();
  if auth.uid() is null then raise exception 'Je moet ingelogd zijn.'; end if;

  select * into v_card
  from public.shared_cards
  where id = p_shared_card_id and deleted_at is null;
  if v_card.id is null then raise exception 'De gedeelde kaart bestaat niet meer.'; end if;

  if v_card.owner_id <> auth.uid() then
    if not exists (
      select 1 from public.card_share_members
      where shared_card_id = p_shared_card_id
        and recipient_id = auth.uid()
        and revoked_at is null
        and removed_by_recipient_at is null
    ) then
      raise exception 'Je hebt geen toegang tot deze kaart.';
    end if;
    if not public.has_paskluis_plus(auth.uid())
       or not public.has_paskluis_plus(v_card.owner_id) then
      raise exception 'Beide gebruikers hebben PasKluis Plus nodig om te bewerken.';
    end if;
  end if;

  update public.shared_cards
  set card_payload = p_card_payload,
      version = version + 1,
      updated_at = now(),
      updated_by = auth.uid()
  where id = p_shared_card_id
    and version = p_expected_version
  returning version into v_next_version;
  if v_next_version is null then
    raise exception 'De kaart is ondertussen gewijzigd. Vernieuw de kaart en probeer opnieuw.';
  end if;

  insert into public.card_share_events (shared_card_id, actor_id, action, version)
  values (p_shared_card_id, auth.uid(), 'updated', v_next_version);
  return v_next_version;
end;
$$;

create or replace function public.revoke_shared_card_access(p_membership_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare v_card_id uuid;
begin
  perform public.require_active_device_session();
  update public.card_share_members member
  set revoked_at = now()
  from public.shared_cards card
  where member.id = p_membership_id
    and member.shared_card_id = card.id
    and card.owner_id = auth.uid()
  returning member.shared_card_id into v_card_id;
  if v_card_id is null then raise exception 'Gedeelde toegang niet gevonden.'; end if;
  insert into public.card_share_events (shared_card_id, actor_id, action)
  values (v_card_id, auth.uid(), 'revoked');
end;
$$;

create or replace function public.revoke_all_shared_card_access(
  p_card_external_id text
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare v_card_id uuid;
begin
  perform public.require_active_device_session();
  select id into v_card_id from public.shared_cards
  where owner_id = auth.uid() and card_external_id = p_card_external_id;
  if v_card_id is null then return; end if;
  update public.card_share_members
  set revoked_at = now()
  where shared_card_id = v_card_id and revoked_at is null;
  update public.shared_cards set deleted_at = now() where id = v_card_id;
  insert into public.card_share_events (shared_card_id, actor_id, action)
  values (v_card_id, auth.uid(), 'revoked');
end;
$$;

create or replace function public.remove_received_shared_card(
  p_membership_id uuid
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare v_card_id uuid;
begin
  perform public.require_active_device_session();
  update public.card_share_members
  set removed_by_recipient_at = now()
  where id = p_membership_id
    and recipient_id = auth.uid()
    and revoked_at is null
  returning shared_card_id into v_card_id;
  if v_card_id is null then raise exception 'Gedeelde kaart niet gevonden.'; end if;
  insert into public.card_share_events (shared_card_id, actor_id, action)
  values (v_card_id, auth.uid(), 'removed');
end;
$$;

create or replace function public.share_gift_card_by_email(
  p_recipient_email text,
  p_card_external_id text,
  p_card_payload jsonb
) returns uuid
language plpgsql security definer set search_path = public
as $$
declare
  v_recipient uuid;
  v_share uuid;
begin
  perform public.require_active_device_session();
  if auth.uid() is null then raise exception 'Je moet ingelogd zijn.'; end if;
  if not exists (
    select 1 from public.entitlements
    where user_id = auth.uid() and product_id = 'paskluis_plus'
      and revoked_at is null and (expires_at is null or expires_at > now())
  ) then raise exception 'PasKluis Plus is vereist om kaarten te delen.'; end if;

  select id into v_recipient from public.profiles
  where lower(email) = lower(trim(p_recipient_email)) limit 1;
  if v_recipient is null then raise exception 'Geen PasKluis-account gevonden met dit e-mailadres.'; end if;
  if v_recipient = auth.uid() then raise exception 'Je kunt een kaart niet met jezelf delen.'; end if;

  insert into public.gift_card_shares
    (owner_id, recipient_id, recipient_email, card_external_id, card_payload, revoked_at, updated_at)
  values (auth.uid(), v_recipient, lower(trim(p_recipient_email)), p_card_external_id, p_card_payload, null, now())
  on conflict (owner_id, recipient_id, card_external_id) do update
    set card_payload = excluded.card_payload, recipient_email = excluded.recipient_email,
        revoked_at = null, updated_at = now()
  returning id into v_share;
  return v_share;
end;
$$;

create or replace function public.register_push_token(
  p_token text,
  p_platform text,
  p_device_id text
) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.require_active_device_session();
  if auth.uid() is null then raise exception 'Je moet ingelogd zijn.'; end if;
  if trim(coalesce(p_token, '')) = '' then raise exception 'Ongeldig meldingstoken.'; end if;
  if p_platform not in ('ios', 'android') then raise exception 'Ongeldig platform.'; end if;
  if trim(coalesce(p_device_id, '')) = '' then raise exception 'Ongeldig apparaat.'; end if;

  delete from public.push_device_tokens
  where token = p_token
     or (user_id = auth.uid() and device_id = p_device_id);

  insert into public.push_device_tokens (user_id, token, platform, device_id)
  values (auth.uid(), p_token, p_platform, p_device_id);
end;
$$;

-- Internal notes are staff data; customer-readable rows contain no internal note.
create table if not exists public.support_private_notes (
 thread_id uuid primary key references public.support_threads(id) on delete cascade,
 note text not null default '', updated_at timestamptz not null default now(),
 updated_by uuid references auth.users(id) on delete set null
);
alter table public.support_private_notes enable row level security;
create policy "Staff manage internal notes" on public.support_private_notes
 for all to authenticated using (public.is_staff()) with check (public.is_staff());
grant select, insert, update, delete on public.support_private_notes to authenticated;
insert into public.support_private_notes(thread_id,note)
select id,internal_note from public.support_threads where coalesce(internal_note,'')<>''
on conflict(thread_id) do update set note=excluded.note;
alter table public.support_threads drop column internal_note;
revoke insert on public.support_threads from authenticated;
grant insert(user_id,subject,category) on public.support_threads to authenticated;
revoke all on function public.has_active_device_session() from public;
revoke all on function public.require_active_device_session() from public;
grant execute on function public.has_active_device_session() to authenticated;
grant execute on function public.require_active_device_session() to authenticated;
commit;
