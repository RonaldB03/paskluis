-- Existing session tables stay private. All writes use authenticated, scoped RPCs.
alter table public.support_sessions
 add column owner_session_id uuid,
 add column settings jsonb not null default '{}',
 add column menu jsonb not null default '[]',
 add column settings_revision bigint not null default 0,
 add column applied_revision bigint not null default 0,
 add column pending_patch jsonb not null default '{}',
 add column app_updated_at timestamptz;

create or replace function public.clean_support_settings(p jsonb) returns jsonb
language plpgsql immutable set search_path='' as $$
declare k text; v jsonb; result jsonb := '{}';
begin
 if p is null or jsonb_typeof(p) <> 'object' or octet_length(p::text)>4000 then raise exception 'INVALID_SETTINGS'; end if;
 for k,v in select * from jsonb_each(p) loop
  if k in ('extraClearEnabled','locationCardsEnabled','favoritesFirst','showFavoritesSection','showNearbySection','showCardDistances','nearbyLoyaltyCardsFirst','autoBrightnessEnabled','keepScreenAwakeEnabled','hideSensitiveCodes','giftExpiryNotificationsEnabled') then
   if jsonb_typeof(v)<>'boolean' then raise exception 'INVALID_SETTING_VALUE'; end if;
  elsif k='nearbyRadiusMeters' then
   if v not in ('100'::jsonb,'250'::jsonb,'500'::jsonb,'1000'::jsonb) then raise exception 'INVALID_SETTING_VALUE'; end if;
  elsif k='cardSortOrder' then
   if v not in ('"recent"'::jsonb,'"added"'::jsonb,'"alphabetical"'::jsonb) then raise exception 'INVALID_SETTING_VALUE'; end if;
  elsif k='defaultStartTab' then
   if v not in ('"home"'::jsonb,'"cards"'::jsonb,'"qr"'::jsonb,'"gift"'::jsonb) then raise exception 'INVALID_SETTING_VALUE'; end if;
  elsif k='language' then
   if v not in ('"system"'::jsonb,'"nl"'::jsonb,'"en"'::jsonb) then raise exception 'INVALID_SETTING_VALUE'; end if;
  else raise exception 'SETTING_NOT_ALLOWED'; end if;
  result:=result||jsonb_build_object(k,v);
 end loop;
 return result;
end; $$;
revoke all on function public.clean_support_settings(jsonb) from public,anon,authenticated;

-- Never accept arbitrary menu payload fields (no URLs, codes or images).
create or replace function public.clean_support_menu(p jsonb) returns jsonb
language plpgsql immutable set search_path='' as $$
declare s jsonb; i jsonb; items jsonb; result jsonb := '[]';
begin
 if p is null or jsonb_typeof(p)<>'array' or jsonb_array_length(p)>20 or octet_length(p::text)>50000 then raise exception 'INVALID_MENU'; end if;
 for s in select value from jsonb_array_elements(p) loop
  if jsonb_typeof(s->'items')<>'array' or jsonb_array_length(s->'items')>100 then raise exception 'INVALID_MENU'; end if;
  items := '[]';
  for i in select value from jsonb_array_elements(s->'items') loop
   if i->>'action' in ('help','support','share','lock','hidePins','privacy','backupAuto','backupNow','restore','favoritesFirst','favoritesHome','sorting','start','clarity','location','radius','distances','nearbyFirst','nearbyHome','brightness','awake','notifications','language','plus','device','external') then
    items := items || jsonb_build_array(jsonb_build_object('action',i->>'action','title',left(i->>'title',120),'description',left(i->>'description',500),'locked',i->'locked'));
   end if;
  end loop;
  result := result || jsonb_build_array(jsonb_build_object('id',left(s->>'id',64),'title',left(s->>'title',120),'description',left(s->>'description',500),'collapsed',s->'collapsed','items',items));
 end loop;
 return result;
end; $$;
revoke all on function public.clean_support_menu(jsonb) from public,anon,authenticated;

-- The creating auth session binds support to this installation, not another phone.
create or replace function public.create_support_session(p_diagnostics jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_code text; v_id uuid; v_expires timestamptz;
begin
 if auth.uid() is null or not public.has_active_device_session() then raise exception 'ACTIVE_SESSION_REQUIRED'; end if;
 update public.support_sessions set status='revoked',revoked_at=now(),pending_patch='{}' where user_id=auth.uid() and status in ('pending','active');
 loop
  v_code:=lpad((floor(random()*1000000))::int::text,6,'0');
  exit when not exists(select 1 from public.support_sessions where status='pending' and code_expires_at>now() and code_hash=extensions.digest(v_code,'sha256'));
 end loop;
 v_expires:=now()+interval '10 minutes';
 insert into public.support_sessions(user_id,owner_session_id,code_hash,diagnostics,code_expires_at)
 values(auth.uid(),(auth.jwt()->>'session_id')::uuid,extensions.digest(v_code,'sha256'),public.clean_support_diagnostics(coalesce(p_diagnostics,'{}')),v_expires) returning id into v_id;
 insert into public.admin_audit_log(actor_id,action,entity_type,entity_id,summary) values(auth.uid(),'create','support_session',v_id::text,'Supportmoduscode aangemaakt');
 return jsonb_build_object('id',v_id,'code',v_code,'codeExpiresAt',v_expires);
end; $$;

create or replace function public.sync_support_settings(p_session_id uuid,p_settings jsonb,p_menu jsonb,p_diagnostics jsonb,p_applied_revision bigint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v public.support_sessions%rowtype; clean jsonb;
begin
 if auth.uid() is null or not public.has_active_device_session() then raise exception 'ACTIVE_SESSION_REQUIRED'; end if;
 select * into v from public.support_sessions where id=p_session_id and user_id=auth.uid()
 and owner_session_id=(auth.jwt()->>'session_id')::uuid for update;
 if not found then raise exception 'SESSION_NOT_FOUND'; end if;
 if v.status not in ('pending','active') or (v.status='pending' and v.code_expires_at<=now()) or (v.status='active' and v.expires_at<=now()) then
  return jsonb_build_object('status','ended');
 end if;
 if p_applied_revision is null or p_applied_revision<0 or p_applied_revision>v.settings_revision then raise exception 'INVALID_REVISION'; end if;
 clean:=public.clean_support_settings(p_settings);
 update public.support_sessions set settings=clean,menu=public.clean_support_menu(p_menu),diagnostics=public.clean_support_diagnostics(p_diagnostics),app_updated_at=now(),
 applied_revision=greatest(applied_revision,p_applied_revision),
 pending_patch=case when p_applied_revision=settings_revision then '{}'::jsonb else pending_patch end where id=v.id;
 return jsonb_build_object('status',v.status,'expiresAt',v.expires_at,'revision',v.settings_revision,'patch',case when p_applied_revision=v.settings_revision then '{}'::jsonb else v.pending_patch end);
end; $$;

create or replace function public.update_support_settings(p_session_id uuid,p_patch jsonb,p_expected_revision bigint)
returns bigint language plpgsql security definer set search_path='' as $$
declare v public.support_sessions%rowtype; clean jsonb;
begin
 if auth.uid() is null or public.is_staff() is not true then raise exception 'STAFF_REQUIRED'; end if;
 select * into v from public.support_sessions where id=p_session_id and activated_by=auth.uid() and status='active' and expires_at>now() for update;
 if not found then raise exception 'SESSION_NOT_ACTIVE'; end if;
 if v.app_updated_at is null or v.owner_session_id is null then raise exception 'APP_UPDATE_REQUIRED'; end if;
 if v.settings_revision is distinct from p_expected_revision then raise exception 'SETTINGS_CONFLICT'; end if;
 if v.applied_revision<>v.settings_revision then raise exception 'CHANGE_PENDING'; end if;
 clean:=public.clean_support_settings(p_patch);
 if clean='{}' then raise exception 'EMPTY_PATCH'; end if;
 update public.support_sessions set pending_patch=clean,settings_revision=settings_revision+1 where id=v.id;
 insert into public.admin_audit_log(actor_id,action,entity_type,entity_id,summary) values(auth.uid(),'update','support_session',v.id::text,'Instellingenwijziging aangevraagd: '||(select string_agg(key,', ') from jsonb_object_keys(clean) key));
 return v.settings_revision+1;
end; $$;

create or replace function public.view_support_session(p_session_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v public.support_sessions%rowtype; v_profile jsonb;
begin
 if auth.uid() is null or public.is_staff() is not true then raise exception 'STAFF_REQUIRED'; end if;
 select * into v from public.support_sessions where id=p_session_id and activated_by=auth.uid() and status='active' and expires_at>now();
 if not found then raise exception 'SESSION_NOT_ACTIVE'; end if;
 update public.support_sessions set last_viewed_at=now() where id=v.id;
 select jsonb_build_object('id',p.id,'name',p.display_name,'email',p.email) into v_profile from public.profiles p where p.id=v.user_id;
 return jsonb_build_object('id',v.id,'expiresAt',v.expires_at,'user',v_profile,'diagnostics',v.diagnostics,'settings',v.settings,'menu',v.menu,'revision',v.settings_revision,'appliedRevision',v.applied_revision,'updatedAt',v.app_updated_at);
end; $$;
revoke all on function public.sync_support_settings(uuid,jsonb,jsonb,jsonb,bigint),public.update_support_settings(uuid,jsonb,bigint) from public,anon;
grant execute on function public.sync_support_settings(uuid,jsonb,jsonb,jsonb,bigint),public.update_support_settings(uuid,jsonb,bigint) to authenticated;
notify pgrst,'reload schema';
