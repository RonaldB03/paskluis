-- Tighten only unused anonymous entry points. Guest support remains available.
revoke execute on function public.set_staff_role_by_email(text,public.paskluis_role) from public, anon;
grant execute on function public.set_staff_role_by_email(text,public.paskluis_role) to authenticated, service_role;
revoke execute on function public.share_gift_card_by_email(text,text,jsonb) from public, anon;
grant execute on function public.share_gift_card_by_email(text,text,jsonb) to authenticated, service_role;
revoke execute on function public.touch_last_seen() from public, anon;
grant execute on function public.touch_last_seen() to authenticated, service_role;

-- Trigger functions are not client RPC endpoints. Existing triggers still run.
do $$ declare f record; begin
  for f in select p.oid::regprocedure as signature
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.prosecdef
      and p.prorettype in ('trigger'::regtype,'event_trigger'::regtype)
  loop
    execute format('revoke execute on function %s from public, anon, authenticated',f.signature);
  end loop;
end $$;

-- A JWT must correspond to a still-existing Auth session, not just a device row.
create or replace function public.has_active_device_session()
returns boolean language sql stable security definer set search_path = '' as $$
 select auth.uid() is not null and exists (
   select 1 from public.account_device_sessions d
   join auth.sessions s on s.id=d.session_id and s.user_id=d.user_id
   where d.user_id=auth.uid()
     and d.session_id=nullif(auth.jwt()->>'session_id','')::uuid
     and (s.not_after is null or s.not_after > now())
 );
$$;
