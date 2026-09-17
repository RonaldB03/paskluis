-- Admin portal and support conversation improvements.

alter table public.profiles
  add column if not exists email text;

update public.profiles as profile
set email = auth_user.email
from auth.users as auth_user
where auth_user.id = profile.id
  and profile.email is distinct from auth_user.email;

create index if not exists profiles_email_lower_idx
  on public.profiles (lower(email));

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name, email)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'name', ''),
    new.email
  );
  return new;
end;
$$;

create or replace function public.update_support_thread_activity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.support_threads
  set
    updated_at = now(),
    status = case
      when exists (
        select 1
        from public.profiles
        where id = new.sender_id
          and role in ('support', 'admin')
      ) then 'waiting_for_user'::public.support_status
      else 'open'::public.support_status
    end
  where id = new.thread_id;
  return new;
end;
$$;

drop trigger if exists on_support_message_created
  on public.support_messages;

create trigger on_support_message_created
  after insert on public.support_messages
  for each row execute function public.update_support_thread_activity();

grant select (email) on public.profiles to authenticated;
