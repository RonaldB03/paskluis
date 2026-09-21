-- FCM tokens are account-scoped and can only be registered by the currently
-- authenticated user. Delivery itself is handled by a service-role Edge Function.
create table if not exists public.push_device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  token text not null unique,
  platform text not null check (platform in ('ios', 'android')),
  device_id text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, device_id)
);

alter table public.push_device_tokens enable row level security;

create policy "Users can read their own push tokens"
on public.push_device_tokens for select to authenticated
using (user_id = auth.uid());

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

create or replace function public.unregister_push_token(p_token text)
returns void
language sql
security definer
set search_path = public
as $$
  delete from public.push_device_tokens
  where user_id = auth.uid() and token = p_token;
$$;

revoke all on function public.register_push_token(text, text, text) from public;
revoke all on function public.unregister_push_token(text) from public;
grant execute on function public.register_push_token(text, text, text) to authenticated;
grant execute on function public.unregister_push_token(text) to authenticated;
grant select on public.push_device_tokens to authenticated;
