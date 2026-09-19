-- PasKluis admin control center
-- Adds staff management, remote settings, recognition metadata and an audit trail.

alter table public.profiles
  add column if not exists last_seen_at timestamptz;

alter table public.brands
  add column if not exists aliases text[] not null default '{}',
  add column if not exists recognition_keywords text[] not null default '{}',
  add column if not exists barcode_prefixes text[] not null default '{}',
  add column if not exists is_featured boolean not null default false;

alter table public.support_threads
  add column if not exists priority text not null default 'normal',
  add column if not exists category text not null default 'overig',
  add column if not exists internal_note text,
  add column if not exists first_responded_at timestamptz;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'support_threads_priority_check'
  ) then
    alter table public.support_threads add constraint support_threads_priority_check
      check (priority in ('low', 'normal', 'high', 'urgent'));
  end if;
end $$;

create table if not exists public.app_settings (
  key text primary key,
  value jsonb not null,
  label text not null,
  description text,
  category text not null default 'general',
  is_public boolean not null default false,
  updated_by uuid references public.profiles(id) on delete set null,
  updated_at timestamptz not null default now()
);

create table if not exists public.admin_audit_log (
  id bigint generated always as identity primary key,
  actor_id uuid references public.profiles(id) on delete set null,
  action text not null,
  entity_type text not null,
  entity_id text,
  summary text not null,
  before_data jsonb,
  after_data jsonb,
  created_at timestamptz not null default now()
);

create index if not exists admin_audit_log_created_at_idx
  on public.admin_audit_log (created_at desc);
create index if not exists brands_aliases_gin_idx
  on public.brands using gin (aliases);
create index if not exists brands_recognition_keywords_gin_idx
  on public.brands using gin (recognition_keywords);

alter table public.app_settings enable row level security;
alter table public.admin_audit_log enable row level security;

drop policy if exists "Public reads public app settings" on public.app_settings;
create policy "Public reads public app settings"
  on public.app_settings for select
  using (is_public or public.is_admin());

drop policy if exists "Admins manage app settings" on public.app_settings;
create policy "Admins manage app settings"
  on public.app_settings for all
  using (public.is_admin())
  with check (public.is_admin());

drop policy if exists "Staff reads audit log" on public.admin_audit_log;
drop policy if exists "Admins read audit log" on public.admin_audit_log;
create policy "Admins read audit log"
  on public.admin_audit_log for select
  using (public.is_admin());

grant select on public.app_settings to anon, authenticated;
grant select on public.admin_audit_log to authenticated;
grant insert, update, delete on public.app_settings to authenticated;
grant update (aliases, recognition_keywords, barcode_prefixes, is_featured, sort_order)
  on public.brands to authenticated;
grant update (priority, category, internal_note, first_responded_at)
  on public.support_threads to authenticated;

insert into public.app_settings (key, value, label, description, category, is_public)
values
  ('free_gift_card_limit', '1', 'Gratis cadeaukaarten', 'Aantal cadeaukaarten in de gratis versie.', 'plus', true),
  ('lifetime_price_label', '"€ 2 eenmalig"', 'Lifetime prijsweergave', 'Tekst die bij de eenmalige toegang wordt getoond.', 'plus', true),
  ('nearby_radius_km', '10', 'Straal In de buurt', 'Afstand in kilometers voor kaarten in de buurt.', 'home', true),
  ('maintenance_enabled', 'false', 'Onderhoudsmodus', 'Toon een onderhoudsmelding in de app.', 'app', true),
  ('maintenance_message', '"PasKluis is tijdelijk in onderhoud."', 'Onderhoudstekst', 'Melding die tijdens onderhoud wordt getoond.', 'app', true),
  ('minimum_ios_version', '"1.0.0"', 'Minimale iOS-versie', 'Oudere versies kunnen een updateadvies krijgen.', 'versions', true),
  ('minimum_android_version', '"1.0.0"', 'Minimale Android-versie', 'Oudere versies kunnen een updateadvies krijgen.', 'versions', true)
on conflict (key) do nothing;

create or replace function public.write_admin_audit_log()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  row_id text;
  label text;
begin
  row_id := coalesce(to_jsonb(new) ->> 'id', to_jsonb(old) ->> 'id', to_jsonb(new) ->> 'key', to_jsonb(old) ->> 'key');
  label := case tg_op
    when 'INSERT' then tg_table_name || ' toegevoegd'
    when 'UPDATE' then tg_table_name || ' gewijzigd'
    when 'DELETE' then tg_table_name || ' verwijderd'
  end;

  insert into public.admin_audit_log (
    actor_id, action, entity_type, entity_id, summary, before_data, after_data
  ) values (
    auth.uid(), lower(tg_op), tg_table_name, row_id, label,
    case when tg_op in ('UPDATE', 'DELETE') then to_jsonb(old) else null end,
    case when tg_op in ('INSERT', 'UPDATE') then to_jsonb(new) else null end
  );
  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

drop trigger if exists audit_profiles on public.profiles;
create trigger audit_profiles after update of display_name, role on public.profiles
  for each row when (old.* is distinct from new.*) execute function public.write_admin_audit_log();
drop trigger if exists audit_entitlements on public.entitlements;
create trigger audit_entitlements after insert or update or delete on public.entitlements
  for each row execute function public.write_admin_audit_log();
drop trigger if exists audit_brands on public.brands;
create trigger audit_brands after insert or update or delete on public.brands
  for each row execute function public.write_admin_audit_log();
drop trigger if exists audit_app_settings on public.app_settings;
create trigger audit_app_settings after insert or update or delete on public.app_settings
  for each row execute function public.write_admin_audit_log();
drop trigger if exists audit_support_threads on public.support_threads;
create trigger audit_support_threads after update on public.support_threads
  for each row when (old.* is distinct from new.*) execute function public.write_admin_audit_log();

create or replace function public.set_staff_role_by_email(
  p_email text,
  p_role public.paskluis_role
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  target public.profiles;
  admin_count integer;
begin
  if not public.is_admin() then
    raise exception 'Alleen beheerders kunnen medewerkers beheren.';
  end if;
  if p_role not in ('user', 'support', 'admin') then
    raise exception 'Ongeldige rol.';
  end if;

  select * into target
  from public.profiles
  where lower(email) = lower(trim(p_email))
  limit 1;

  if target.id is null then
    raise exception 'Geen PasKluis-account gevonden met dit e-mailadres.';
  end if;
  if target.id = auth.uid() and p_role <> 'admin' then
    raise exception 'Je kunt je eigen beheerdersrol niet verwijderen.';
  end if;
  if target.role = 'admin' and p_role <> 'admin' then
    select count(*) into admin_count from public.profiles where role = 'admin';
    if admin_count <= 1 then
      raise exception 'De laatste beheerder kan niet worden verwijderd.';
    end if;
  end if;

  update public.profiles
  set role = p_role, updated_at = now()
  where id = target.id;

  return jsonb_build_object('id', target.id, 'email', target.email, 'role', p_role);
end;
$$;

grant execute on function public.set_staff_role_by_email(text, public.paskluis_role)
  to authenticated;

create or replace function public.touch_last_seen()
returns void
language sql
security definer
set search_path = ''
as $$
  update public.profiles set last_seen_at = now(), updated_at = now() where id = auth.uid();
$$;

grant execute on function public.touch_last_seen() to authenticated;
