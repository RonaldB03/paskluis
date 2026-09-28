-- Reject revoked or expired Auth sessions before binding devices or accessing backups.
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
  if auth.uid() is null or not exists(select 1 from auth.sessions s where s.user_id=auth.uid()
    and s.id=nullif(auth.jwt()->>'session_id','')::uuid
    and (s.not_after is null or s.not_after>now())) then raise exception 'SESSION_REPLACED' using errcode='42501'; end if;

  select * into current_session
  from public.account_device_sessions
  where user_id = auth.uid()
  for update;

  if not found then
    insert into public.account_device_sessions (
      user_id, device_id, device_name, last_seen_at, updated_at, session_id
    ) values (
      auth.uid(), p_device_id, left(coalesce(p_device_name, 'Apparaat'), 80), now(), now(), nullif(auth.jwt()->>'session_id','')::uuid
    )
    on conflict (user_id) do nothing;

    select * into current_session
    from public.account_device_sessions
    where user_id = auth.uid()
    for update;
  end if;

  if (current_session.device_id = p_device_id and (current_session.session_id is null or current_session.session_id = nullif(auth.jwt()->>'session_id','')::uuid)) or p_replace then
    update public.account_device_sessions
    set device_id = p_device_id,
        session_id = nullif(auth.jwt()->>'session_id','')::uuid,
        device_name = left(coalesce(p_device_name, 'Apparaat'), 80),
        last_seen_at = now(),
        updated_at = now()
    where user_id = auth.uid();
    delete from public.push_device_tokens where user_id=auth.uid() and device_id<>p_device_id;
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
  if auth.uid() is null or not exists(select 1 from auth.sessions s where s.user_id=auth.uid()
    and s.id=nullif(auth.jwt()->>'session_id','')::uuid
    and (s.not_after is null or s.not_after>now())) then return false; end if;
  update public.account_device_sessions
  set last_seen_at = now(), session_id = nullif(auth.jwt()->>'session_id','')::uuid
  where user_id = auth.uid() and device_id = p_device_id
    and (session_id is null or session_id = nullif(auth.jwt()->>'session_id','')::uuid);
  return found;
end;
$$;

create or replace function public.backup_service(p_user uuid,p_session uuid,p_action text,p_data jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare a backup_private.accounts%rowtype; v jsonb; total bigint; token uuid;
begin
 if not exists(select 1 from auth.sessions s join public.account_device_sessions d on d.user_id=s.user_id and d.session_id=s.id where s.user_id=p_user and s.id=p_session and (s.not_after is null or s.not_after>now())) then raise exception 'SESSION_REPLACED'; end if;
 insert into backup_private.accounts(user_id) values(p_user) on conflict do nothing;
 select * into a from backup_private.accounts where user_id=p_user for update;
 if not a.enabled then return jsonb_build_object('available',false); end if;
 if p_action='lock' then
  if a.lease_until>now() then raise exception 'BACKUP_BUSY'; end if;
  token:=gen_random_uuid();
  update backup_private.accounts set lease=token,lease_until=now()+interval '3 minutes' where user_id=p_user;
  select coalesce(jsonb_agg(to_jsonb(b) - 'user_id' order by created_at desc),'[]'::jsonb) into v from backup_private.versions b where user_id=p_user;
  return jsonb_build_object('available',true,'lease',token,'key',encode(a.key,'base64'),'generation',a.generation,'versions',v,'lastError',a.last_error,'lastSuccess',a.last_success);
 end if;
 if a.lease is distinct from (p_data->>'lease')::uuid or a.lease_until<=now() then raise exception 'BACKUP_BUSY'; end if;
 if p_action='commit' then
  insert into backup_private.versions(user_id,id,card_count,manifest,objects)
  values(p_user,(p_data->>'id')::uuid,(p_data->>'cardCount')::integer,p_data->>'manifest',p_data->'objects');
  delete from backup_private.versions where user_id=p_user and id in (select id from backup_private.versions where user_id=p_user and id<>(p_data->>'id')::uuid order by created_at desc,id desc offset 2);
  select coalesce(sum(bytes),0) into total from (select (o->>'id') id,max((o->>'size')::bigint) bytes from backup_private.versions b cross join lateral jsonb_array_elements(b.objects) o where b.user_id=p_user group by o->>'id') objects;
  if total>10000000 then raise exception 'BACKUP_QUOTA'; end if;
  update backup_private.accounts set last_success=now(),last_error=null where user_id=p_user;
 elsif p_action='delete' then
  delete from backup_private.versions where user_id=p_user;
  update backup_private.accounts set key=extensions.gen_random_bytes(32),generation=gen_random_uuid(),last_success=null,last_error=null where user_id=p_user;
 elsif p_action='finish' then
  update backup_private.accounts set lease=null,lease_until=null,last_error=p_data->>'error' where user_id=p_user;
 else raise exception 'INVALID_ACTION'; end if;
 return jsonb_build_object('ok',true);
end; $$;
revoke all on function public.backup_service(uuid,uuid,text,jsonb) from public,anon,authenticated;
grant execute on function public.backup_service(uuid,uuid,text,jsonb) to service_role;
