create table if not exists public.gift_card_shares (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  recipient_id uuid not null references auth.users(id) on delete cascade,
  recipient_email text not null,
  card_external_id text not null,
  card_payload jsonb not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  revoked_at timestamptz,
  unique (owner_id, recipient_id, card_external_id),
  check (owner_id <> recipient_id)
);

alter table public.gift_card_shares enable row level security;

create policy "Owners can read gift card shares"
on public.gift_card_shares for select to authenticated
using (owner_id = auth.uid());

create policy "Recipients can read gift card shares"
on public.gift_card_shares for select to authenticated
using (recipient_id = auth.uid() and revoked_at is null);

create policy "Owners can update gift card shares"
on public.gift_card_shares for update to authenticated
using (owner_id = auth.uid()) with check (owner_id = auth.uid());

create policy "Owners can delete gift card shares"
on public.gift_card_shares for delete to authenticated
using (owner_id = auth.uid());

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

grant execute on function public.share_gift_card_by_email(text, text, jsonb) to authenticated;
grant select, update, delete on public.gift_card_shares to authenticated;
