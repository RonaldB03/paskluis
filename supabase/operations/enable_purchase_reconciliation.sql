-- Requires migration 027, reconcile-purchases and the existing worker secret.
-- The schedule remains dormant until store_reconciliation_enabled=true.
begin;
create or replace function public.run_purchase_reconciliation() returns void
language plpgsql security definer set search_path='' as $$
declare worker_secret text;
begin
 if not exists(select 1 from public.app_settings where key='store_reconciliation_enabled' and value='true') then return; end if;
 select decrypted_secret into worker_secret from vault.decrypted_secrets where name='paskluis_notification_worker_secret';
 if length(coalesce(worker_secret,''))<32 then return; end if;
 perform net.http_post(url:='https://ajldblvvlbvmgejrmhyj.supabase.co/functions/v1/reconcile-purchases',
  headers:=jsonb_build_object('Content-Type','application/json','x-job-secret',worker_secret),body:='{}'::jsonb,timeout_milliseconds:=90000);
end$$;
revoke all on function public.run_purchase_reconciliation() from public,anon,authenticated;
select cron.schedule('paskluis-store-reconciliation','*/10 * * * *','select public.run_purchase_reconciliation();');
commit;
