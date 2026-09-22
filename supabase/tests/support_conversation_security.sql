-- Run after migration 029. All fixtures, messages and queued notifications roll back.
begin;
insert into auth.users(id,email,raw_user_meta_data) values
 ('ee290000-0000-4000-8000-000000000001','chat-owner@example.invalid','{}'),
 ('ee290000-0000-4000-8000-000000000002','chat-other@example.invalid','{}'),
 ('ee290000-0000-4000-8000-000000000003','chat-staff@example.invalid','{}');
update public.profiles set role='support',display_name='Ronald Test'
where id='ee290000-0000-4000-8000-000000000003';

select set_config('request.jwt.claims','{}',true);
select set_config('test.guest_thread', public.create_support_conversation(
 repeat('chat-test-token-',3),'Test Guest','chat-guest@example.invalid','Guest question',
 'Customer first message','overig','nl','{}')::text,true);

select set_config('request.jwt.claims','{"sub":"ee290000-0000-4000-8000-000000000001","role":"authenticated","session_id":"ee290000-0000-4000-8000-000000000011"}',true);
set local role authenticated;
select public.claim_device_session('chat-test-device','Test device',false);
select set_config('test.own_thread',public.create_support_conversation(
 repeat('chat-test-token-',3),'','','Own question','My first question','overig','nl','{}')::text,true);
-- A customer cannot claim a staff identity/name by altering an insert.
insert into public.support_messages(thread_id,sender_id,sender_kind,sender_name,message)
values(current_setting('test.own_thread')::uuid,auth.uid(),'staff','Forged staff','Customer follow-up');
do $$declare data jsonb;begin
 data:=public.support_conversation(current_setting('test.own_thread')::uuid);
 if exists(select 1 from jsonb_array_elements(data->'messages') m
           where m->>'message'='Customer follow-up' and
           (m->>'sender_kind'<>'user' or m->>'sender_name' is not null)) then
  raise exception 'CUSTOMER_CAN_FORGE_STAFF';
 end if;
end$$;
reset role;

select set_config('request.jwt.claims','{"sub":"ee290000-0000-4000-8000-000000000003","role":"authenticated"}',true);
set local role authenticated;
insert into public.support_messages(thread_id,sender_id,sender_kind,sender_name,message,created_at) values
 (current_setting('test.guest_thread')::uuid,auth.uid(),'staff','Forged name','Personal answer',clock_timestamp()),
 (current_setting('test.own_thread')::uuid,auth.uid(),'staff','Forged name','Own answer',clock_timestamp());
-- Staff asking a question in the customer app must receive an acknowledgement,
-- not an erroneous notification saying their own question is a staff reply.
select set_config('test.staff_question',public.create_support_conversation(
 repeat('staff-test-token-',3),'','','Staff own question','My customer question','overig','nl','{}')::text,true);
do $$begin
 if (select count(*) from public.support_messages where thread_id=current_setting('test.staff_question')::uuid and sender_kind='automatic')<>1 then
  raise exception 'STAFF_CUSTOMER_ACK_MISSING'; end if;
 if exists(select 1 from public.notification_outbox where thread_id=current_setting('test.staff_question')::uuid and event_type='support_reply') then
  raise exception 'STAFF_QUESTION_QUEUED_AS_REPLY'; end if;
 if exists(select 1 from public.notification_outbox where event_type='support_reply' and email_done is not true) then
  raise exception 'CUSTOMER_REPLY_EMAIL_QUEUED'; end if;
end$$;
reset role;

-- Renaming a staff profile does not rewrite the author of an existing answer.
update public.profiles set display_name='Changed Name' where id='ee290000-0000-4000-8000-000000000003';
select set_config('request.jwt.claims','{}',true);
set local role anon;
do $$declare data jsonb; denied boolean:=false;begin
 data:=public.support_conversation(current_setting('test.guest_thread')::uuid,repeat('chat-test-token-',3));
 if data->'messages'->0->>'message'<>'Customer first message' then raise exception 'WRONG_MESSAGE_ORDER'; end if;
 if not exists(select 1 from jsonb_array_elements(data->'messages') m where
   m->>'message'='Personal answer' and m->>'sender_name'='Ronald Test' and m->>'sender_kind'='staff') then
  raise exception 'STAFF_AUTHOR_MISSING'; end if;
 if data::text like '%example.invalid%' or data::text like '%guest_token_hash%' then
  raise exception 'PRIVATE_METADATA_LEAKED'; end if;
 begin perform public.support_conversation(current_setting('test.guest_thread')::uuid,repeat('wrong-token-',4));
 exception when insufficient_privilege then denied:=true;end;
 if not denied then raise exception 'WRONG_GUEST_TOKEN_ACCEPTED';end if;
end$$;
reset role;

select set_config('request.jwt.claims','{"sub":"ee290000-0000-4000-8000-000000000002","role":"authenticated","session_id":"ee290000-0000-4000-8000-000000000012"}',true);
set local role authenticated;
select public.claim_device_session('chat-other-device','Other device',false);
do $$declare denied boolean:=false;begin
 begin perform public.support_conversation(current_setting('test.own_thread')::uuid);
 exception when insufficient_privilege then denied:=true;end;
 if not denied then raise exception 'OTHER_ACCOUNT_CAN_READ_CONVERSATION';end if;
end$$;
reset role;
select set_config('request.jwt.claims','{"sub":"ee290000-0000-4000-8000-000000000001","role":"authenticated","session_id":"ee290000-0000-4000-8000-000000000099"}',true);
set local role authenticated;
do $$declare denied boolean:=false;begin
 begin perform public.support_conversation(current_setting('test.own_thread')::uuid);
 exception when insufficient_privilege then denied:=true;end;
 if not denied then raise exception 'REPLACED_SESSION_CAN_READ_CONVERSATION';end if;
end$$;
reset role;
select 'PASS: conversation isolation, staff identity, chronological replies, staff-as-customer, push-only replies' as support_verification;
rollback;
