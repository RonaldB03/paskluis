-- Isolated test project, synthetic identities; every test row rolls back.
begin;
insert into auth.users(id,email,raw_user_meta_data) values
('ee440000-0000-4000-8000-000000000001','live-support-user@example.invalid','{}'),
('ee440000-0000-4000-8000-000000000002','live-support-staff@example.invalid','{}'),
('ee440000-0000-4000-8000-000000000003','live-support-other@example.invalid','{}');
update public.profiles set role='support' where id in ('ee440000-0000-4000-8000-000000000002','ee440000-0000-4000-8000-000000000003');
insert into auth.mfa_factors(id,user_id,factor_type,status,created_at,updated_at) values
('ee440000-0000-4000-8000-000000000012','ee440000-0000-4000-8000-000000000002','totp','verified',now(),now()),
('ee440000-0000-4000-8000-000000000013','ee440000-0000-4000-8000-000000000003','totp','verified',now(),now());
insert into auth.sessions(id,user_id,aal,factor_id,created_at,updated_at) values
('ee440000-0000-4000-8000-000000000021','ee440000-0000-4000-8000-000000000001','aal1',null,now(),now()),
('ee440000-0000-4000-8000-000000000022','ee440000-0000-4000-8000-000000000002','aal2','ee440000-0000-4000-8000-000000000012',now(),now()),
('ee440000-0000-4000-8000-000000000023','ee440000-0000-4000-8000-000000000003','aal2','ee440000-0000-4000-8000-000000000013',now(),now());
select set_config('request.jwt.claims','{"sub":"ee440000-0000-4000-8000-000000000001","session_id":"ee440000-0000-4000-8000-000000000021","role":"authenticated","aal":"aal1"}',true);
set local role authenticated;
select public.claim_device_session('live-support-test-device','Synthetic test',false);
select set_config('paskluis_test.session',public.create_support_session('{"platform":"ios","pin":"NEVER_RETURN"}')::text,true);
select public.sync_support_settings((current_setting('paskluis_test.session')::jsonb->>'id')::uuid,'{"language":"nl","nearbyRadiusMeters":250}','[{"id":"language","title":"Taal","items":[{"action":"language","title":"Taal","code":"NEVER_RETURN"}]}]','{"platform":"ios","pin":"NEVER_RETURN"}',0);
select set_config('request.jwt.claims','{"sub":"ee440000-0000-4000-8000-000000000002","session_id":"ee440000-0000-4000-8000-000000000022","role":"authenticated","aal":"aal1"}',true);
do $$begin
 begin perform public.activate_support_session(current_setting('paskluis_test.session')::jsonb->>'code'); raise exception 'MFA_NOT_ENFORCED';
 exception when raise_exception then if SQLERRM<>'STAFF_REQUIRED' then raise; end if; end;
end$$;
select set_config('request.jwt.claims','{"sub":"ee440000-0000-4000-8000-000000000002","session_id":"ee440000-0000-4000-8000-000000000022","role":"authenticated","aal":"aal2"}',true);
select public.activate_support_session(current_setting('paskluis_test.session')::jsonb->>'code');
do $$declare id uuid := (current_setting('paskluis_test.session')::jsonb->>'id')::uuid; v jsonb; begin
 v:=public.view_support_session(id);
 if v::text like '%NEVER_RETURN%' or v->'settings'->>'language'<>'nl' then raise exception 'PRIVACY_OR_SNAPSHOT_FAILED'; end if;
 begin perform public.update_support_settings(id,'{"pincodes":"bad"}',0); raise exception 'UNKNOWN_SETTING_ALLOWED';
 exception when raise_exception then if SQLERRM<>'SETTING_NOT_ALLOWED' then raise; end if; end;
 begin perform public.update_support_settings(id,'{"nearbyRadiusMeters":900}',0); raise exception 'INVALID_VALUE_ALLOWED';
 exception when raise_exception then if SQLERRM<>'INVALID_SETTING_VALUE' then raise; end if; end;
 if public.update_support_settings(id,'{"language":"en"}',0)<>1 then raise exception 'REVISION_FAILED'; end if;
 begin perform public.update_support_settings(id,'{"language":"nl"}',0); raise exception 'CONFLICT_ALLOWED';
 exception when raise_exception then if SQLERRM<>'SETTINGS_CONFLICT' then raise; end if; end;
 begin perform public.update_support_settings(id,'{"language":"nl"}',1); raise exception 'OVERLAP_ALLOWED';
 exception when raise_exception then if SQLERRM<>'CHANGE_PENDING' then raise; end if; end;
end$$;
select set_config('request.jwt.claims','{"sub":"ee440000-0000-4000-8000-000000000003","session_id":"ee440000-0000-4000-8000-000000000023","role":"authenticated","aal":"aal2"}',true);
do $$begin
 begin perform public.view_support_session((current_setting('paskluis_test.session')::jsonb->>'id')::uuid); raise exception 'OTHER_STAFF_ALLOWED';
 exception when raise_exception then if SQLERRM<>'SESSION_NOT_ACTIVE' then raise; end if; end;
end$$;
select set_config('request.jwt.claims','{"sub":"ee440000-0000-4000-8000-000000000001","session_id":"ee440000-0000-4000-8000-000000000021","role":"authenticated","aal":"aal1"}',true);
do $$declare id uuid := (current_setting('paskluis_test.session')::jsonb->>'id')::uuid; v jsonb; begin
 v:=public.sync_support_settings(id,'{"language":"nl","nearbyRadiusMeters":250}','[]','{}',0);
 if v->'patch'->>'language'<>'en' then raise exception 'PATCH_NOT_DELIVERED'; end if;
 perform public.sync_support_settings(id,'{"language":"en","nearbyRadiusMeters":250}','[]','{}',1);
end$$;
select set_config('request.jwt.claims','{"sub":"ee440000-0000-4000-8000-000000000002","session_id":"ee440000-0000-4000-8000-000000000022","role":"authenticated","aal":"aal2"}',true);
do $$declare v jsonb; begin
 v:=public.view_support_session((current_setting('paskluis_test.session')::jsonb->>'id')::uuid);
 if (v->>'appliedRevision')::int<>1 or v->'settings'->>'language'<>'en' then raise exception 'ACKNOWLEDGEMENT_FAILED'; end if;
end$$;
select set_config('request.jwt.claims','{"sub":"ee440000-0000-4000-8000-000000000001","session_id":"ee440000-0000-4000-8000-000000000021","role":"authenticated","aal":"aal1"}',true);
select public.revoke_support_session((current_setting('paskluis_test.session')::jsonb->>'id')::uuid);
do $$declare v jsonb; begin
 v:=public.sync_support_settings((current_setting('paskluis_test.session')::jsonb->>'id')::uuid,'{}','[]','{}',1);
 if v->>'status'<>'ended' or v ? 'patch' then raise exception 'REVOKED_SESSION_DELIVERED_PATCH'; end if;
end$$;
select set_config('request.jwt.claims','{"sub":"ee440000-0000-4000-8000-000000000002","session_id":"ee440000-0000-4000-8000-000000000022","role":"authenticated","aal":"aal2"}',true);
do $$begin
 begin perform public.update_support_settings((current_setting('paskluis_test.session')::jsonb->>'id')::uuid,'{"language":"nl"}',1); raise exception 'REVOKED_EDIT_ALLOWED';
 exception when raise_exception then if SQLERRM<>'SESSION_NOT_ACTIVE' then raise; end if; end;
end$$;
reset role;
select 'PASS: real MFA, typed settings, privacy filters, staff scope, conflict handling, app acknowledgement and revocation' result;
rollback;
