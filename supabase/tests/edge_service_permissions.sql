-- Read/write permission checks without inspecting or changing customer rows.
begin;
set local role service_role;
select count(*) from public.profiles where false;
select count(*) from public.brands where false;
select count(*) from public.support_threads where false;
select count(*) from public.card_share_members where false;
select count(*) from public.account_device_sessions where false;
select count(*) from public.push_device_tokens where false;
select count(*) from public.guest_support_push_tokens where false;
select count(*) from public.support_attachments where false;
update public.notification_outbox set last_error=last_error where false;
update public.store_purchases set reconcile_after=reconcile_after where false;
update public.purchase_reconciliation_state set last_error=last_error where false;
update public.nearby_store_cache set updated_at=updated_at where false;
reset role;
select 'PASS: Edge Functions have the required table access without changing customer rows' as result;
rollback;
