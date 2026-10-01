-- Remotely managed public content and privacy-first, time-limited support mode.
create extension if not exists pgcrypto with schema extensions;

create table public.managed_content (
  key text primary key check (key ~ '^[a-z0-9][a-z0-9._-]{1,79}$'),
  channel text not null check (channel in ('site','app','shared')),
  label text not null check (length(label) between 1 and 120),
  schema_version integer not null default 1 check (schema_version between 1 and 20),
  revision bigint not null default 1 check (revision > 0),
  draft jsonb not null default '{}'::jsonb,
  published jsonb not null default '{}'::jsonb,
  updated_by uuid references public.profiles(id) on delete set null,
  published_by uuid references public.profiles(id) on delete set null,
  updated_at timestamptz not null default now(),
  published_at timestamptz not null default now(),
  check (jsonb_typeof(draft) = 'object' and octet_length(draft::text) <= 250000),
  check (jsonb_typeof(published) = 'object' and octet_length(published::text) <= 250000)
);

create table public.managed_content_history (
  id bigint generated always as identity primary key,
  content_key text not null references public.managed_content(key) on delete cascade,
  revision bigint not null,
  content jsonb not null check (jsonb_typeof(content) = 'object' and octet_length(content::text) <= 250000),
  published_by uuid references public.profiles(id) on delete set null,
  published_at timestamptz not null default now(),
  unique(content_key, revision)
);

alter table public.managed_content enable row level security;
alter table public.managed_content_history enable row level security;
revoke all on public.managed_content, public.managed_content_history from anon, authenticated;
grant select on public.managed_content, public.managed_content_history to authenticated;
create policy "Admins read managed content" on public.managed_content for select to authenticated using ((select public.is_admin()));
create policy "Admins read managed content history" on public.managed_content_history for select to authenticated using ((select public.is_admin()));

create or replace function public.get_published_content(p_key text)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'key', c.key, 'channel', c.channel, 'schemaVersion', c.schema_version,
    'revision', c.revision, 'publishedAt', c.published_at, 'content', c.published
  ) from public.managed_content c where c.key = p_key;
$$;
revoke all on function public.get_published_content(text) from public;
grant execute on function public.get_published_content(text) to anon, authenticated;

create or replace function public.save_managed_content(
  p_key text, p_channel text, p_label text, p_content jsonb, p_expected_revision bigint
) returns bigint language plpgsql security definer set search_path = '' as $$
declare v_revision bigint;
begin
  if not public.is_admin() then raise exception 'ADMIN_REQUIRED'; end if;
  if p_content is null or jsonb_typeof(p_content) <> 'object' or octet_length(p_content::text) > 250000 then raise exception 'INVALID_CONTENT'; end if;
  select revision into v_revision from public.managed_content where key=p_key for update;
  if not found then
    if p_expected_revision is distinct from 0 then raise exception 'CONTENT_CONFLICT'; end if;
    insert into public.managed_content(key,channel,label,draft,published,updated_by,published_by)
      values(p_key,p_channel,p_label,p_content,p_content,auth.uid(),auth.uid()) returning revision into v_revision;
    insert into public.managed_content_history(content_key,revision,content,published_by) values(p_key,v_revision,p_content,auth.uid());
  else
    if v_revision is distinct from p_expected_revision then raise exception 'CONTENT_CONFLICT'; end if;
    update public.managed_content set channel=p_channel,label=p_label,draft=p_content,
      revision=revision+1,updated_by=auth.uid(),updated_at=now() where key=p_key returning revision into v_revision;
  end if;
  insert into public.admin_audit_log(actor_id,action,entity_type,entity_id,summary)
    values(auth.uid(),'save','managed_content',p_key,'Conceptinhoud opgeslagen');
  return v_revision;
end; $$;

create or replace function public.publish_managed_content(p_key text, p_expected_revision bigint, p_restore_revision bigint default null)
returns bigint language plpgsql security definer set search_path = '' as $$
declare v_row public.managed_content%rowtype; v_content jsonb; v_revision bigint;
begin
  if not public.is_admin() then raise exception 'ADMIN_REQUIRED'; end if;
  select * into v_row from public.managed_content where key=p_key for update;
  if not found then raise exception 'CONTENT_NOT_FOUND'; end if;
  if v_row.revision is distinct from p_expected_revision then raise exception 'CONTENT_CONFLICT'; end if;
  v_content := v_row.draft;
  if p_restore_revision is not null then
    select content into v_content from public.managed_content_history where content_key=p_key and revision=p_restore_revision;
    if v_content is null then raise exception 'CONTENT_VERSION_NOT_FOUND'; end if;
  end if;
  update public.managed_content set published=v_content,draft=v_content,revision=revision+1,
    published_by=auth.uid(),updated_by=auth.uid(),published_at=now(),updated_at=now()
    where key=p_key returning revision into v_revision;
  insert into public.managed_content_history(content_key,revision,content,published_by) values(p_key,v_revision,v_content,auth.uid());
  insert into public.admin_audit_log(actor_id,action,entity_type,entity_id,summary)
    values(auth.uid(),'publish','managed_content',p_key,case when p_restore_revision is null then 'Inhoud gepubliceerd' else 'Inhoud hersteld' end);
  return v_revision;
end; $$;
revoke all on function public.save_managed_content(text,text,text,jsonb,bigint) from public;
revoke all on function public.publish_managed_content(text,bigint,bigint) from public;
grant execute on function public.save_managed_content(text,text,text,jsonb,bigint) to authenticated;
grant execute on function public.publish_managed_content(text,bigint,bigint) to authenticated;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('public-content','public-content',true,2097152,array['image/png','image/jpeg','image/webp'])
on conflict(id) do update set public=true,file_size_limit=2097152,allowed_mime_types=excluded.allowed_mime_types;
create policy "Admins upload public content" on storage.objects for insert to authenticated
  with check(bucket_id='public-content' and (select public.is_admin()));
create policy "Admins update public content" on storage.objects for update to authenticated
  using(bucket_id='public-content' and (select public.is_admin())) with check(bucket_id='public-content' and (select public.is_admin()));
create policy "Admins delete public content" on storage.objects for delete to authenticated
  using(bucket_id='public-content' and (select public.is_admin()));

create table public.support_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  code_hash bytea not null,
  status text not null default 'pending' check(status in ('pending','active','revoked','expired')),
  diagnostics jsonb not null default '{}'::jsonb check(jsonb_typeof(diagnostics)='object' and octet_length(diagnostics::text)<=20000),
  created_at timestamptz not null default now(),
  code_expires_at timestamptz not null default (now()+interval '10 minutes'),
  activated_at timestamptz,
  expires_at timestamptz,
  revoked_at timestamptz,
  activated_by uuid references public.profiles(id) on delete set null,
  last_viewed_at timestamptz,
  failed_attempts integer not null default 0 check(failed_attempts between 0 and 20)
);
create table public.support_session_attempts (
  id bigint generated always as identity primary key,
  staff_id uuid not null references public.profiles(id) on delete cascade,
  attempted_at timestamptz not null default now(),
  succeeded boolean not null default false
);
create index support_session_attempts_staff_idx on public.support_session_attempts(staff_id,attempted_at desc);
alter table public.support_session_attempts enable row level security;
revoke all on public.support_session_attempts from anon, authenticated;
create index support_sessions_user_idx on public.support_sessions(user_id,created_at desc);
create index support_sessions_pending_idx on public.support_sessions(code_expires_at) where status='pending';
alter table public.support_sessions enable row level security;
revoke all on public.support_sessions from anon, authenticated;
grant select on public.support_sessions to authenticated;
create policy "Users inspect own support sessions" on public.support_sessions for select to authenticated using((select auth.uid())=user_id);
create policy "Staff inspect active support sessions" on public.support_sessions for select to authenticated using((select public.is_staff()) and status='active' and expires_at>now());

create or replace function public.clean_support_diagnostics(p jsonb)
returns jsonb language sql immutable set search_path='' as $$
  select jsonb_strip_nulls(jsonb_build_object(
    'platform', left(p->>'platform',20), 'osVersion', left(p->>'osVersion',80),
    'appVersion', left(p->>'appVersion',30), 'buildNumber', left(p->>'buildNumber',20),
    'locale', left(p->>'locale',20), 'accountState', left(p->>'accountState',30),
    'plusState', left(p->>'plusState',30), 'backupEnabled', case when jsonb_typeof(p->'backupEnabled')='boolean' then p->'backupEnabled' end,
    'backupStatus', left(p->>'backupStatus',40), 'backupLastSuccess', left(p->>'backupLastSuccess',40),
    'notificationPermission', left(p->>'notificationPermission',40), 'locationPermission', left(p->>'locationPermission',40),
    'appLockEnabled', case when jsonb_typeof(p->'appLockEnabled')='boolean' then p->'appLockEnabled' end,
    'biometricsAvailable', case when jsonb_typeof(p->'biometricsAvailable')='boolean' then p->'biometricsAvailable' end,
    'brightnessMode', left(p->>'brightnessMode',30), 'keepScreenAwake', case when jsonb_typeof(p->'keepScreenAwake')='boolean' then p->'keepScreenAwake' end,
    'hideSensitiveCodes', case when jsonb_typeof(p->'hideSensitiveCodes')='boolean' then p->'hideSensitiveCodes' end,
    'defaultStartTab', left(p->>'defaultStartTab',30), 'sortOrder', left(p->>'sortOrder',30),
    'capturedAt', left(p->>'capturedAt',40)
  ));
$$;
revoke all on function public.clean_support_diagnostics(jsonb) from public,anon,authenticated;

create or replace function public.create_support_session(p_diagnostics jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_code text; v_id uuid; v_expires timestamptz;
begin
  if auth.uid() is null or not public.has_active_device_session() then raise exception 'ACTIVE_SESSION_REQUIRED'; end if;
  update public.support_sessions set status='revoked',revoked_at=now() where user_id=auth.uid() and status in ('pending','active');
  v_code := lpad((floor(random()*1000000))::int::text,6,'0');
  v_expires := now()+interval '10 minutes';
  insert into public.support_sessions(user_id,code_hash,diagnostics,code_expires_at)
    values(auth.uid(),extensions.digest(v_code,'sha256'),public.clean_support_diagnostics(coalesce(p_diagnostics,'{}'::jsonb)),v_expires)
    returning id into v_id;
  insert into public.admin_audit_log(actor_id,action,entity_type,entity_id,summary)
    values(auth.uid(),'create','support_session',v_id::text,'Supportmoduscode aangemaakt');
  return jsonb_build_object('id',v_id,'code',v_code,'codeExpiresAt',v_expires);
end; $$;

create or replace function public.activate_support_session(p_code text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v public.support_sessions%rowtype;
begin
  if not public.is_staff() then raise exception 'STAFF_REQUIRED'; end if;
  if p_code !~ '^[0-9]{6}$' then raise exception 'INVALID_CODE'; end if;
  if (select count(*) from public.support_session_attempts where staff_id=auth.uid() and attempted_at>now()-interval '15 minutes') >= 10 then
    raise exception 'TOO_MANY_ATTEMPTS';
  end if;
  insert into public.support_session_attempts(staff_id) values(auth.uid());
  select * into v from public.support_sessions where status='pending' and code_expires_at>now()
    and code_hash=extensions.digest(p_code,'sha256') order by created_at desc limit 1 for update skip locked;
  if not found then raise exception 'INVALID_OR_EXPIRED_CODE'; end if;
  update public.support_session_attempts set succeeded=true where id=(select max(id) from public.support_session_attempts where staff_id=auth.uid());
  update public.support_sessions set status='active',activated_at=now(),expires_at=now()+interval '30 minutes',activated_by=auth.uid()
    where id=v.id;
  insert into public.admin_audit_log(actor_id,action,entity_type,entity_id,summary)
    values(auth.uid(),'activate','support_session',v.id::text,'Tijdelijke Supportmodus geactiveerd');
  return jsonb_build_object('id',v.id,'expiresAt',now()+interval '30 minutes');
end; $$;

create or replace function public.view_support_session(p_session_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v public.support_sessions%rowtype; v_profile jsonb;
begin
  if not public.is_staff() then raise exception 'STAFF_REQUIRED'; end if;
  select * into v from public.support_sessions where id=p_session_id and status='active' and expires_at>now();
  if not found then raise exception 'SESSION_NOT_ACTIVE'; end if;
  update public.support_sessions set last_viewed_at=now() where id=v.id;
  select jsonb_build_object('id',p.id,'name',p.display_name,'email',p.email) into v_profile from public.profiles p where p.id=v.user_id;
  insert into public.admin_audit_log(actor_id,action,entity_type,entity_id,summary)
    values(auth.uid(),'view','support_session',v.id::text,'Supportdiagnose bekeken');
  return jsonb_build_object('id',v.id,'expiresAt',v.expires_at,'user',v_profile,'diagnostics',v.diagnostics);
end; $$;

create or replace function public.revoke_support_session(p_session_id uuid)
returns void language plpgsql security definer set search_path='' as $$
begin
  update public.support_sessions set status='revoked',revoked_at=now()
    where id=p_session_id and user_id=auth.uid() and status in ('pending','active');
  if not found then raise exception 'SESSION_NOT_FOUND'; end if;
  insert into public.admin_audit_log(actor_id,action,entity_type,entity_id,summary)
    values(auth.uid(),'revoke','support_session',p_session_id::text,'Supportmodus ingetrokken');
end; $$;
revoke all on function public.create_support_session(jsonb) from public;
revoke all on function public.activate_support_session(text) from public;
revoke all on function public.view_support_session(uuid) from public;
revoke all on function public.revoke_support_session(uuid) from public;
grant execute on function public.create_support_session(jsonb),public.revoke_support_session(uuid) to authenticated;
grant execute on function public.activate_support_session(text),public.view_support_session(uuid) to authenticated;

insert into public.managed_content(key,channel,label,draft,published) values
('site.home','site','Website home','{"brand":{"name":"PasKluis","byline":"Ronald & Jordi"},"hero":{"title":"Al je kaarten. Eén veilige plek.","body":"Bewaar klantenkaarten, QR-codes en cadeaukaarten overzichtelijk in PasKluis.","primaryCta":"Download binnenkort","secondaryCta":"Bekijk de functies"},"features":[{"title":"Altijd bij de hand","body":"Open je kaart direct bij de kassa."},{"title":"Duidelijk en persoonlijk","body":"Favorieten, saldo en kaarten in de buurt."},{"title":"Veilig ondersteund","body":"Support kan nooit je kaartcodes, pincodes of barcodes zien."}]}','{"brand":{"name":"PasKluis","byline":"Ronald & Jordi"},"hero":{"title":"Al je kaarten. Eén veilige plek.","body":"Bewaar klantenkaarten, QR-codes en cadeaukaarten overzichtelijk in PasKluis.","primaryCta":"Download binnenkort","secondaryCta":"Bekijk de functies"},"features":[{"title":"Altijd bij de hand","body":"Open je kaart direct bij de kassa."},{"title":"Duidelijk en persoonlijk","body":"Favorieten, saldo en kaarten in de buurt."},{"title":"Veilig ondersteund","body":"Support kan nooit je kaartcodes, pincodes of barcodes zien."}]}'::jsonb),
('app.copy','app','Appteksten en afbeeldingen','{"supportMode":{"title":{"nl":"Veilige Supportmodus","en":"Secure Support Mode"},"description":{"nl":"Geef klantenservice tijdelijk en alleen-lezen inzage in technische instellingen. Kaartcodes, barcodes, QR-codes, pincodes, afbeeldingen, wachtwoorden, betaalgegevens en je exacte locatie zijn nooit zichtbaar.","en":"Temporarily share read-only technical settings with support. Card codes, barcodes, QR codes, PINs, images, passwords, payment details and your exact location are never visible."}}}','{"supportMode":{"title":{"nl":"Veilige Supportmodus","en":"Secure Support Mode"},"description":{"nl":"Geef klantenservice tijdelijk en alleen-lezen inzage in technische instellingen. Kaartcodes, barcodes, QR-codes, pincodes, afbeeldingen, wachtwoorden, betaalgegevens en je exacte locatie zijn nooit zichtbaar.","en":"Temporarily share read-only technical settings with support. Card codes, barcodes, QR codes, PINs, images, passwords, payment details and your exact location are never visible."}}}'::jsonb)
on conflict(key) do nothing;
