-- PasKluis Plus foundation
-- Run this migration in a Supabase project before enabling online features.

create extension if not exists pgcrypto;

create type public.paskluis_role as enum ('user', 'support', 'admin');
create type public.entitlement_source as enum ('apple', 'google', 'complimentary');
create type public.support_status as enum ('open', 'waiting_for_user', 'closed');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  role public.paskluis_role not null default 'user',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.entitlements (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  product_id text not null,
  source public.entitlement_source not null,
  starts_at timestamptz not null default now(),
  expires_at timestamptz,
  revoked_at timestamptz,
  note text,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  constraint entitlement_dates_valid check (
    expires_at is null or expires_at > starts_at
  )
);

create unique index entitlements_active_product_idx
  on public.entitlements (user_id, product_id)
  where revoked_at is null;

create table public.brands (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  logo_path text,
  brand_color text not null default '#D51B46',
  supports_loyalty_card boolean not null default true,
  supports_gift_card boolean not null default false,
  is_active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.support_threads (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  subject text not null,
  status public.support_status not null default 'open',
  assigned_to uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.support_messages (
  id uuid primary key default gen_random_uuid(),
  thread_id uuid not null references public.support_threads(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  message text not null check (char_length(message) between 1 and 5000),
  attachment_path text,
  created_at timestamptz not null default now()
);

create or replace function public.is_staff()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.profiles
    where id = auth.uid()
      and role in ('support', 'admin')
  );
$$;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.profiles
    where id = auth.uid()
      and role = 'admin'
  );
$$;

alter table public.profiles enable row level security;
alter table public.entitlements enable row level security;
alter table public.brands enable row level security;
alter table public.support_threads enable row level security;
alter table public.support_messages enable row level security;

create policy "Users read own profile"
  on public.profiles for select
  using (id = auth.uid() or public.is_staff());

create policy "Users update own profile"
  on public.profiles for update
  using (id = auth.uid())
  with check (id = auth.uid());

create policy "Users read own entitlements"
  on public.entitlements for select
  using (user_id = auth.uid() or public.is_staff());

create policy "Admins manage entitlements"
  on public.entitlements for all
  using (public.is_admin())
  with check (public.is_admin());

create policy "Authenticated users read active brands"
  on public.brands for select
  using (is_active or public.is_staff());

create policy "Admins manage brands"
  on public.brands for all
  using (public.is_admin())
  with check (public.is_admin());

create policy "Users read own support threads"
  on public.support_threads for select
  using (user_id = auth.uid() or public.is_staff());

create policy "Users create own support threads"
  on public.support_threads for insert
  with check (user_id = auth.uid());

create policy "Staff update support threads"
  on public.support_threads for update
  using (public.is_staff())
  with check (public.is_staff());

create policy "Participants read support messages"
  on public.support_messages for select
  using (
    public.is_staff()
    or exists (
      select 1 from public.support_threads
      where id = thread_id and user_id = auth.uid()
    )
  );

create policy "Participants send support messages"
  on public.support_messages for insert
  with check (
    sender_id = auth.uid()
    and (
      public.is_staff()
      or exists (
        select 1 from public.support_threads
        where id = thread_id and user_id = auth.uid()
      )
    )
  );

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'name', ''));
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
