-- Run after support_inbox_retention.sql in an isolated test database only.
begin;

do $$
declare tid uuid:=gen_random_uuid(); oldid uuid:=gen_random_uuid(); heldid uuid:=gen_random_uuid();
 token text:=repeat('retention-test-',4); mid uuid; inbox jsonb; rejected boolean:=false;
begin
 if has_function_privilege('anon','public.purge_expired_support()','execute') then raise exception 'public purge access'; end if;
 if has_table_privilege('authenticated','public.support_storage_cleanup','select') then raise exception 'public queue access'; end if;
 insert into public.support_threads(id,subject,guest_name,guest_email,guest_token_hash)
 values(tid,'Rollback inbox test','Test','test@example.invalid',encode(extensions.digest(token,'sha256'),'hex'));
 perform public.support_customer_action(tid,'hide',token);
 if exists(select 1 from jsonb_array_elements(public.support_inbox(token)) x where x->>'id'=tid::text) then raise exception 'hide failed'; end if;
 begin perform public.support_customer_action(tid,'hide',repeat('wrong',12));
 exception when insufficient_privilege then rejected:=true; end;
 if not rejected then raise exception 'foreign guest authorized'; end if;
 insert into public.support_messages(thread_id,message) values(tid,'Rollback message') returning id into mid;
 -- Fixture-only classification; no notification is sent for this update.
 update public.support_messages set sender_kind='staff',created_at=clock_timestamp()+interval '1 second' where id=mid;
 inbox:=public.support_inbox(token);
 if not exists(select 1 from jsonb_array_elements(inbox) x where x->>'id'=tid::text and (x->>'has_unread_reply')::boolean) then raise exception 'new reply did not restore hidden thread'; end if;
 -- Move both fixture watermarks into the past before testing read acknowledgement.
 update public.support_customer_state set hidden_at=now()-interval '2 days' where thread_id=tid;
 update public.support_messages set created_at=now()-interval '1 day' where id=mid;
 perform public.support_customer_action(tid,'read',token,now());
 if exists(select 1 from jsonb_array_elements(public.support_inbox(token)) x where x->>'id'=tid::text and (x->>'has_unread_reply')::boolean) then raise exception 'read failed'; end if;
 insert into public.support_attachments(thread_id,message_id,storage_path,mime_type,size_bytes)
 values(tid,mid,tid::text||'/fixture.jpg','image/jpeg',10);
 update public.support_threads set status='closed' where id=tid;
 insert into public.support_threads(id,subject,status) values(oldid,'Rollback expired','closed'),(heldid,'Rollback hold','closed');
 insert into public.support_retention_holds(thread_id,reason,review_at) values(heldid,'Test documented dispute',now()+interval '30 days');
 -- Only in the isolated test project and rolled back, to simulate the clock.
 alter table public.support_threads disable trigger support_closure;
 update public.support_threads set closed_at=now()-interval '31 days' where id=tid;
 update public.support_threads set closed_at=now()-interval '7 months' where id in(oldid,heldid);
 alter table public.support_threads enable trigger support_closure;
 perform public.purge_expired_support();
 if exists(select 1 from public.support_attachments where thread_id=tid) then raise exception 'attachment retention failed'; end if;
 if not exists(select 1 from public.support_storage_cleanup where storage_path=tid::text||'/fixture.jpg') then raise exception 'storage deletion not queued'; end if;
 if not exists(select 1 from public.support_threads where id=tid) then raise exception 'thread removed too early'; end if;
 if exists(select 1 from public.support_threads where id=oldid) then raise exception 'expired thread retained'; end if;
 if exists(select 1 from public.admin_audit_log where entity_type='support_threads' and entity_id=oldid::text) then raise exception 'audit personal data retained'; end if;
 if not exists(select 1 from public.support_threads where id=heldid) then raise exception 'hold ignored'; end if;
 update public.support_threads set status='open' where id=tid;
 if exists(select 1 from public.support_threads where id=tid and closed_at is not null) then raise exception 'reopen clock failed'; end if;
end $$;
select 'PASS: ownership, hiding, new reply, read state, retention, attachments, audit, holds and reopening' as result;
rollback;
