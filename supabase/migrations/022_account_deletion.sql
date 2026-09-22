begin;
alter table public.entitlements drop constraint entitlements_created_by_fkey;
alter table public.entitlements add constraint entitlements_created_by_fkey foreign key(created_by) references public.profiles(id) on delete set null;
alter table public.support_threads drop constraint support_threads_assigned_to_fkey;
alter table public.support_threads add constraint support_threads_assigned_to_fkey foreign key(assigned_to) references public.profiles(id) on delete set null;
create or replace function public.prepare_account_deletion(p_user_id uuid) returns void
language plpgsql security definer set search_path='' as $$
declare email_address text;
begin
 select email into email_address from auth.users where id=p_user_id;
 if exists(select 1 from public.profiles where id=p_user_id and role<>'user') then raise exception 'STAFF_ROLE_MUST_BE_REMOVED_FIRST'; end if;
 -- Remove guest support associated with the confirmed account's email too.
 delete from public.support_threads where user_id=p_user_id or (user_id is null and lower(guest_email)=lower(email_address));
 delete from public.admin_audit_log where actor_id=p_user_id or (entity_type='profiles' and entity_id=p_user_id::text);
end; $$;
revoke all on function public.prepare_account_deletion(uuid) from public,anon,authenticated;
grant execute on function public.prepare_account_deletion(uuid) to service_role;
commit;
