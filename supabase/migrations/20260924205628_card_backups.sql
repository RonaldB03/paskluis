begin;
create schema if not exists backup_private;
revoke all on schema backup_private from public, anon, authenticated;
create table backup_private.accounts (
 user_id uuid primary key references auth.users(id) on delete cascade,
 enabled boolean not null default false,
 key bytea not null default extensions.gen_random_bytes(32),
 generation uuid not null default gen_random_uuid(),
 lease uuid, lease_until timestamptz,
 last_error text, last_success timestamptz
);
create table backup_private.versions (
 user_id uuid not null references backup_private.accounts(user_id) on delete cascade,
 id uuid not null, created_at timestamptz not null default now(),
 card_count integer not null check(card_count between 0 and 5000),
 manifest text not null, objects jsonb not null,
 primary key(user_id,id)
);
alter table backup_private.accounts enable row level security;
alter table backup_private.versions enable row level security;
-- Only existing testers are admitted initially. No card contents or keys are exposed in the Data API.
insert into backup_private.accounts(user_id,enabled) select id,true from auth.users;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('card-backups','card-backups',false,11000000,array['application/octet-stream'])
on conflict(id) do nothing;
create policy card_backups_private_only on storage.objects as restrictive for all to anon,authenticated using(bucket_id <> 'card-backups') with check(bucket_id <> 'card-backups');
-- All object traffic goes through an authenticated function, never a public URL.
create or replace function public.backup_service(p_user uuid,p_session uuid,p_action text,p_data jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare a backup_private.accounts%rowtype; v jsonb; total bigint; token uuid;
begin
 if not exists(select 1 from auth.sessions s join public.account_device_sessions d on d.user_id=s.user_id and d.session_id=s.id where s.user_id=p_user and s.id=p_session) then raise exception 'SESSION_REPLACED'; end if;
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
  delete from backup_private.versions where user_id=p_user and id in (select id from backup_private.versions where user_id=p_user order by created_at desc,id desc offset 3);
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
create or replace function public.backup_admin_overview() returns jsonb
language plpgsql security definer set search_path='' as $$
begin
 if not exists(select 1 from public.profiles where id=auth.uid() and role='admin') or not public.has_active_device_session() then raise exception 'ADMIN_REQUIRED'; end if;
 return jsonb_build_object('users',(select count(*) from backup_private.accounts where last_success is not null),'versions',(select count(*) from backup_private.versions),'storageBytes',(select coalesce(sum((metadata->>'size')::bigint),0) from storage.objects where bucket_id='card-backups'),'failures',(select count(*) from backup_private.accounts where last_error is not null),'quotaPerUser',10000000,'reviewAtUsers',50);
end; $$;
revoke all on function public.backup_admin_overview() from public,anon;
grant execute on function public.backup_admin_overview() to authenticated;
create or replace function public.backup_disable_for_deletion(p_user uuid) returns void
language plpgsql security definer set search_path='' as $$
begin
 perform 1 from backup_private.accounts where user_id=p_user for update;
 if exists(select 1 from backup_private.accounts where user_id=p_user and lease_until>now()) then raise exception 'BACKUP_BUSY'; end if;
 update backup_private.accounts set enabled=false where user_id=p_user;
end; $$;
revoke all on function public.backup_disable_for_deletion(uuid) from public,anon,authenticated;
grant execute on function public.backup_disable_for_deletion(uuid) to service_role;
commit;
