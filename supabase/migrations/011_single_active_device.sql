create table if not exists public.account_device_sessions (
  user_id uuid primary key references auth.users(id) on delete cascade,
  device_id text not null,
  device_name text not null,
  last_seen_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.account_device_sessions enable row level security;

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
    'is_current_device', current_session.device_id = p_device_id,
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
      user_id, device_id, device_name, last_seen_at, updated_at
    ) values (
      auth.uid(), p_device_id, left(coalesce(p_device_name, 'Apparaat'), 80), now(), now()
    )
    on conflict (user_id) do nothing;

    select * into current_session
    from public.account_device_sessions
    where user_id = auth.uid()
    for update;
  end if;

  if current_session.device_id = p_device_id or p_replace then
    update public.account_device_sessions
    set device_id = p_device_id,
        device_name = left(coalesce(p_device_name, 'Apparaat'), 80),
        last_seen_at = now(),
        updated_at = now()
    where user_id = auth.uid();
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
  set last_seen_at = now()
  where user_id = auth.uid() and device_id = p_device_id;
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
  where user_id = auth.uid() and device_id = p_device_id;
$$;

revoke all on function public.check_device_session(text) from public;
revoke all on function public.claim_device_session(text, text, boolean) from public;
revoke all on function public.validate_device_session(text) from public;
revoke all on function public.release_device_session(text) from public;
grant execute on function public.check_device_session(text) to authenticated;
grant execute on function public.claim_device_session(text, text, boolean) to authenticated;
grant execute on function public.validate_device_session(text) to authenticated;
grant execute on function public.release_device_session(text) to authenticated;
