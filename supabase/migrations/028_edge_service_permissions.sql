begin;
-- This project does not grant new public tables to service_role by default.
-- Edge Functions need explicit SQL privileges in addition to bypassing RLS.
-- Keep app-user grants and RLS unchanged; expose only operations used by the
-- server handlers, rather than granting every table to every future function.
grant usage on schema public to service_role;
grant select on public.profiles,public.brands,public.support_threads,
 public.card_share_members,public.account_device_sessions to service_role;
grant update(role,display_name,email,updated_at) on public.profiles to service_role;
grant select,insert,update on public.nearby_store_cache to service_role;
grant select,update on public.notification_outbox,public.store_purchases,
 public.purchase_reconciliation_state to service_role;
grant select,delete on public.push_device_tokens,public.guest_support_push_tokens to service_role;
grant select,insert on public.support_attachments to service_role;
notify pgrst,'reload schema';
commit;
