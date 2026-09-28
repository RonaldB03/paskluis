-- Isolated test project only. Synthetic identities, no mail, all rolled back.
begin;
insert into auth.users(id,email,raw_user_meta_data) values
('ee330000-0000-4000-8000-000000000001','mfa-admin@example.invalid','{}'),
('ee330000-0000-4000-8000-000000000002','mfa-support@example.invalid','{}'),
('ee330000-0000-4000-8000-000000000003','mfa-user@example.invalid','{}');
update public.profiles set role='admin' where id='ee330000-0000-4000-8000-000000000001';
update public.profiles set role='support' where id='ee330000-0000-4000-8000-000000000002';
insert into auth.mfa_factors(id,user_id,factor_type,status,created_at,updated_at) values
('ee330000-0000-4000-8000-000000000011','ee330000-0000-4000-8000-000000000001','totp','verified',now(),now()),
('ee330000-0000-4000-8000-000000000012','ee330000-0000-4000-8000-000000000002','totp','verified',now(),now()),
('ee330000-0000-4000-8000-000000000013','ee330000-0000-4000-8000-000000000003','totp','verified',now(),now());
insert into auth.sessions(id,user_id,aal,factor_id,created_at,updated_at) values
('ee330000-0000-4000-8000-000000000021','ee330000-0000-4000-8000-000000000001','aal2','ee330000-0000-4000-8000-000000000011',now(),now()),
('ee330000-0000-4000-8000-000000000022','ee330000-0000-4000-8000-000000000002','aal2','ee330000-0000-4000-8000-000000000012',now(),now()),
('ee330000-0000-4000-8000-000000000023','ee330000-0000-4000-8000-000000000003','aal2','ee330000-0000-4000-8000-000000000013',now(),now());
select set_config('request.jwt.claims','{"sub":"ee330000-0000-4000-8000-000000000001","session_id":"ee330000-0000-4000-8000-000000000021","role":"authenticated","aal":"aal1"}',true);
set local role authenticated;
do $$begin
 if public.is_admin() or public.is_staff() then raise exception 'AAL1_STAFF_ACCESS'; end if;
 if (select count(*) from public.profiles)<>1 then raise exception 'AAL1_PROFILE_ISOLATION'; end if;
 if exists(select 1 from public.app_menu_draft) then raise exception 'AAL1_READ_DRAFT'; end if;
 begin
  insert into public.brands(slug,name) values('mfa-denied','Denied');
  raise exception 'AAL1_WRITE_BRAND';
 exception when insufficient_privilege then null; end;
 begin
  insert into storage.objects(bucket_id,name) values('brand-logos','mfa-denied.png');
  raise exception 'AAL1_WRITE_LOGO';
 exception when insufficient_privilege then null; end;
 begin
  perform public.save_app_menu('{}',0);
  raise exception 'AAL1_MENU_RPC';
 exception when raise_exception then if SQLERRM<>'ADMIN_REQUIRED' then raise; end if; end;
 begin
  perform public.backup_admin_overview();
  raise exception 'AAL1_BACKUP_ADMIN';
 exception when raise_exception then if SQLERRM<>'ADMIN_REQUIRED' then raise; end if; end;
end$$;
select set_config('request.jwt.claims','{"sub":"ee330000-0000-4000-8000-000000000001","session_id":"ee330000-0000-4000-8000-000000000021","role":"authenticated","aal":"aal2"}',true);
do $$begin
 if not public.is_admin() or not public.is_staff() then raise exception 'AAL2_ADMIN_DENIED'; end if;
 if (select count(*) from public.profiles)<3 then raise exception 'AAL2_PROFILE_ACCESS'; end if;
 if not exists(select 1 from public.app_menu_draft) then raise exception 'AAL2_DRAFT_ACCESS'; end if;
 insert into public.brands(slug,name) values('mfa-allowed','Allowed');
 insert into storage.objects(bucket_id,name) values('brand-logos','mfa-allowed.png');
end$$;
select set_config('request.jwt.claims','{"sub":"ee330000-0000-4000-8000-000000000002","session_id":"ee330000-0000-4000-8000-000000000022","role":"authenticated","aal":"aal2"}',true);
do $$begin
 if public.is_admin() or not public.is_staff() then raise exception 'SUPPORT_ROLE_BOUNDARY'; end if;
 if exists(select 1 from public.app_menu_draft) then raise exception 'SUPPORT_READ_DRAFT'; end if;
end$$;
select set_config('request.jwt.claims','{"sub":"ee330000-0000-4000-8000-000000000003","session_id":"ee330000-0000-4000-8000-000000000023","role":"authenticated","aal":"aal2"}',true);
do $$begin
 if public.is_admin() or public.is_staff() then raise exception 'USER_PRIVILEGE_ESCALATION'; end if;
end$$;
reset role;
select set_config('request.jwt.claims','{"sub":"ee330000-0000-4000-8000-000000000001","session_id":"ee330000-0000-4000-8000-000000000021","role":"authenticated","aal":"aal2"}',true);
update auth.sessions set not_after=now()-interval '1 minute' where id='ee330000-0000-4000-8000-000000000021';
do $$begin if public.is_admin() or public.is_staff() then raise exception 'EXPIRED_MFA_SESSION'; end if; end$$;
update auth.sessions set not_after=null,aal='aal1' where id='ee330000-0000-4000-8000-000000000021';
do $$begin if public.is_admin() or public.is_staff() then raise exception 'DOWNGRADED_MFA_SESSION'; end if; end$$;
update auth.sessions set aal='aal2' where id='ee330000-0000-4000-8000-000000000021';
update auth.mfa_factors set status='unverified' where id='ee330000-0000-4000-8000-000000000011';
do $$begin if public.is_admin() or public.is_staff() then raise exception 'UNVERIFIED_FACTOR'; end if; end$$;
update auth.mfa_factors set status='verified' where id='ee330000-0000-4000-8000-000000000011';
delete from auth.sessions where id='ee330000-0000-4000-8000-000000000021';
do $$begin if public.is_admin() or public.is_staff() then raise exception 'DELETED_MFA_SESSION'; end if; end$$;
select set_config('request.jwt.claims','{}',true);
set local role anon;
do $$begin
 if public.is_admin() or public.is_staff() then raise exception 'ANON_PRIVILEGES'; end if;
 if not exists(select 1 from public.brands where is_active) then raise exception 'PUBLIC_CATALOG_BROKEN'; end if;
end$$;
reset role;
select 'PASS: staff MFA enforced for RLS, RPC and Storage; enrollment profile readable; roles, sessions and public catalog verified' as result;
rollback;
