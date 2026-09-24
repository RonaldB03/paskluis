begin;
do $$
declare u uuid:=gen_random_uuid(); s uuid:=gen_random_uuid(); st jsonb; n integer; oldkey text; lease text;
begin
 insert into auth.users(id,email) values(u,'backup-test-'||u||'@example.invalid');
 insert into auth.sessions(id,user_id) values(s,u);
 insert into public.account_device_sessions(user_id,device_id,device_name,session_id) values(u,'synthetic','Synthetic backup test',s);
 if has_function_privilege('authenticated','public.backup_service(uuid,uuid,text,jsonb)','execute') then raise exception 'service endpoint exposed'; end if;
 if has_schema_privilege('authenticated','backup_private','usage') then raise exception 'private keys exposed'; end if;
 begin perform public.backup_service(u,gen_random_uuid(),'lock');raise exception 'wrong session accepted';
 exception when others then if sqlerrm<>'SESSION_REPLACED' then raise; end if;end;
 st:=public.backup_service(u,s,'lock');
 if st->>'available' is distinct from 'true' then raise exception 'new account cannot use backup';end if;
 lease:=st->>'lease';oldkey:=st->>'key';
 begin perform public.backup_service(u,s,'lock');raise exception 'concurrent lease accepted';
 exception when others then if sqlerrm<>'BACKUP_BUSY' then raise; end if;end;
 for n in 1..4 loop
  perform public.backup_service(u,s,'commit',jsonb_build_object('lease',lease,'id',gen_random_uuid(),'cardCount',n,'manifest','manifest-'||n,'objects',jsonb_build_array(jsonb_build_object('id','shared-image','size',100),jsonb_build_object('id','manifest-'||n,'size',100))));
 end loop;
 select count(*) into n from backup_private.versions where user_id=u;if n<>3 then raise exception 'retention failed';end if;
 begin
  perform public.backup_service(u,s,'commit',jsonb_build_object('lease',lease,'id',gen_random_uuid(),'cardCount',1,'manifest','huge','objects',jsonb_build_array(jsonb_build_object('id','huge','size',10000001))));
  raise exception 'quota not enforced';
 exception when others then if sqlerrm<>'BACKUP_QUOTA' then raise; end if;end;
 select count(*) into n from backup_private.versions where user_id=u;if n<>3 then raise exception 'quota destroyed old history';end if;
 perform public.backup_service(u,s,'delete',jsonb_build_object('lease',lease));
 if exists(select 1 from backup_private.versions where user_id=u) then raise exception 'delete failed';end if;
 perform public.backup_service(u,s,'finish',jsonb_build_object('lease',lease));
 st:=public.backup_service(u,s,'lock');if st->>'key'=oldkey then raise exception 'key not rotated';end if;
 perform public.backup_service(u,s,'finish',jsonb_build_object('lease',st->>'lease'));
 perform public.backup_disable_for_deletion(u);
 st:=public.backup_service(u,s,'lock');
 if st->>'available' is distinct from 'false' then raise exception 'deletion safeguard re-enabled';end if;
end $$;
rollback;
