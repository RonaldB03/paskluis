-- Staff privileges require a current, verified MFA session, including RPC and Storage checks.
create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path='' as $$
 select coalesce(auth.jwt()->>'aal' = 'aal2', false)
 and exists (
   select 1 from public.profiles p
   join auth.sessions s on s.user_id=p.id
   join auth.mfa_factors f on f.id=s.factor_id and f.user_id=s.user_id
   where p.id=auth.uid() and p.role='admin'
     and s.id=nullif(auth.jwt()->>'session_id','')::uuid
     and s.aal='aal2' and (s.not_after is null or s.not_after>now())
     and f.status='verified'
 );
$$;
create or replace function public.is_staff() returns boolean
language sql stable security definer set search_path='' as $$
 select coalesce(auth.jwt()->>'aal' = 'aal2', false)
 and exists (
   select 1 from public.profiles p
   join auth.sessions s on s.user_id=p.id
   join auth.mfa_factors f on f.id=s.factor_id and f.user_id=s.user_id
   where p.id=auth.uid() and p.role in ('admin','support')
     and s.id=nullif(auth.jwt()->>'session_id','')::uuid
     and s.aal='aal2' and (s.not_after is null or s.not_after>now())
     and f.status='verified'
 );
$$;
create or replace function public.backup_admin_overview() returns jsonb
language plpgsql security definer set search_path='' as $$
begin
 if not public.is_admin() or not public.has_active_device_session() then raise exception 'ADMIN_REQUIRED'; end if;
 return jsonb_build_object('users',(select count(*) from backup_private.accounts where last_success is not null),'versions',(select count(*) from backup_private.versions),'storageBytes',(select coalesce(sum((metadata->>'size')::bigint),0) from storage.objects where bucket_id='card-backups'),'failures',(select count(*) from backup_private.accounts where last_error is not null),'quotaPerUser',10000000,'reviewAtUsers',50);
end; $$;
revoke all on function public.backup_admin_overview() from public,anon;
grant execute on function public.backup_admin_overview() to authenticated;
