-- Run only after dispatch-notifications is deployed and a random 32+ character
-- secret is stored BOTH as Edge secret NOTIFICATION_WORKER_SECRET and in Vault
-- under paskluis_notification_worker_secret. No secret is stored in this file.
begin;
create extension if not exists pg_cron;
create extension if not exists pg_net;
do $$begin
 if not exists(select 1 from vault.decrypted_secrets where name='paskluis_notification_worker_secret' and length(decrypted_secret)>=32) then
  raise exception 'Configure the matching worker secret in Edge Functions and Vault first';
 end if;
end$$;
create or replace function public.run_notification_worker() returns void
language plpgsql security definer set search_path='' as $$
declare worker_secret text;
begin
 if not exists(select 1 from public.notification_outbox where delivered_at is null and attempts<8 and available_at<=now() and (locked_until is null or locked_until<now())) then return; end if;
 select decrypted_secret into worker_secret from vault.decrypted_secrets where name='paskluis_notification_worker_secret';
 if length(coalesce(worker_secret,''))<32 then return; end if;
 perform net.http_post(url:='https://ajldblvvlbvmgejrmhyj.supabase.co/functions/v1/dispatch-notifications',
  headers:=jsonb_build_object('Content-Type','application/json','x-job-secret',worker_secret),body:='{}'::jsonb,timeout_milliseconds:=90000);
end$$;
revoke all on function public.run_notification_worker() from public,anon,authenticated;
select cron.schedule('paskluis-notification-outbox','* * * * *','select public.run_notification_worker();');
select cron.schedule('paskluis-location-cache-cleanup','17 * * * *','delete from public.nearby_store_cache where expires_at<now();');
select cron.schedule('paskluis-delivery-log-cleanup','23 3 * * *','delete from public.notification_outbox where delivered_at<now()-interval ''30 days''; delete from public.guest_support_push_tokens g where not exists(select 1 from public.support_threads t where t.guest_token_hash=g.guest_token_hash);');
commit;
