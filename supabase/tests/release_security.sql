-- Run after migrations 020–026 in a test database. Everything rolls back.
begin;
-- Temporary identities are rolled back; these tests send no email or push.
insert into auth.users(id,email,raw_user_meta_data) values
('ee220000-0000-4000-8000-000000000001','release-owner@example.invalid','{}'),
('ee220000-0000-4000-8000-000000000002','release-recipient@example.invalid','{}'),
('ee220000-0000-4000-8000-000000000003','release-staff@example.invalid','{}');
update public.profiles set role='support' where id='ee220000-0000-4000-8000-000000000003';
select set_config('request.jwt.claims','{"sub":"ee220000-0000-4000-8000-000000000001","role":"authenticated","session_id":"ee220000-0000-4000-8000-000000000011"}',true);
set local role authenticated;
do $$begin
 if (public.claim_device_session('release-device-a','Test device',false)->>'allowed')::boolean is not true then raise exception 'FIRST_CLAIM_FAILED'; end if;
 if not public.has_active_device_session() then raise exception 'FIRST_SESSION_NOT_ACTIVE'; end if;
end$$;
select set_config('request.jwt.claims','{"sub":"ee220000-0000-4000-8000-000000000001","role":"authenticated","session_id":"ee220000-0000-4000-8000-000000000012"}',true);
do $$begin
 if public.has_active_device_session() then raise exception 'UNCLAIMED_SESSION_HAS_ACCESS'; end if;
 if (public.claim_device_session('release-device-b','Test second device',false)->>'allowed')::boolean then raise exception 'TAKEOVER_WITHOUT_CONFIRMATION'; end if;
 if not (public.claim_device_session('release-device-b','Test second device',true)->>'allowed')::boolean then raise exception 'CONFIRMED_TAKEOVER_FAILED'; end if;
end$$;
select set_config('request.jwt.claims','{"sub":"ee220000-0000-4000-8000-000000000001","role":"authenticated","session_id":"ee220000-0000-4000-8000-000000000011"}',true);
do $$begin
 if public.has_active_device_session() or public.validate_device_session('release-device-a') then raise exception 'OLD_SESSION_STILL_ACTIVE'; end if;
end$$;
reset role;
select set_config('request.jwt.claims','{}',true);
do $$declare t uuid;before_due timestamptz;begin
 t:=public.create_support_conversation(repeat('release-test-token-',3),'Test Guest','release-guest@example.invalid','Release verification','First question','overig','nl','{"platform":"test","version":"1.5.0"}');
 if(select count(*) from public.support_messages where thread_id=t and sender_kind='automatic')<>1 then raise exception 'ACK_MISSING';end if;
 if(select first_responded_at from public.support_threads where id=t) is not null then raise exception 'AUTO_REPLY_COUNTS_AS_PERSONAL';end if;
 select response_due_at into before_due from public.support_threads where id=t;
 perform public.send_guest_support_message(repeat('release-test-token-',3),t,'Another detail');
 if(select count(*) from public.support_messages where thread_id=t and sender_kind='automatic')<>1 then raise exception 'DUPLICATE_ACK';end if;
 if(select response_due_at from public.support_threads where id=t) is distinct from before_due then raise exception 'FOLLOWUP_RESTARTS_TARGET';end if;
 insert into public.support_private_notes(thread_id,note) values(t,'STAFF ONLY');
end$$;
select set_config('request.jwt.claims','{"sub":"ee220000-0000-4000-8000-000000000001","role":"authenticated","session_id":"ee220000-0000-4000-8000-000000000012"}',true);
set local role authenticated;
do $$begin
 if exists(select 1 from public.support_private_notes) then raise exception 'CUSTOMER_CAN_READ_INTERNAL_NOTES';end if;
end$$;
reset role;
select 'PASS: single-device takeover, old-session denial, private notes, exactly one acknowledgement, 12-hour target' as security_verification;

do $$declare u uuid:='ee220000-0000-4000-8000-000000000002';begin
 perform public.record_verified_purchase(u,'apple','release-apple','production',false);
 perform public.record_verified_purchase(u,'google','release-google','production',false);
 perform public.record_verified_purchase(u,'apple','release-apple','production',true);
 if not exists(select 1 from public.entitlements where user_id=u and revoked_at is null and source='google' and expires_at is null) then raise exception 'OTHER_STORE_ACCESS_LOST';end if;
 perform public.record_verified_purchase(u,'google','release-google','production',true);
 if exists(select 1 from public.entitlements where user_id=u and revoked_at is null) then raise exception 'REFUNDED_ACCESS_REMAINS';end if;
 insert into public.entitlements(user_id,product_id,source) values(u,'paskluis_plus','complimentary');
 perform public.record_verified_purchase(u,'google','release-google','production',true);
 if not exists(select 1 from public.entitlements where user_id=u and revoked_at is null and source='complimentary') then raise exception 'STAFF_GRANTED_ACCESS_LOST';end if;
end$$;
select 'PASS: multi-store refund reconciliation and independent staff-granted access' as purchase_verification;

rollback;
