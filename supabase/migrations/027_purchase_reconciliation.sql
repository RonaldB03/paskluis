begin;
alter table public.store_purchases add column reconcile_after timestamptz not null default now();
create index store_purchases_reconcile on public.store_purchases(platform,reconcile_after) where user_id is not null;
create table public.purchase_reconciliation_state (
 platform text primary key check(platform in ('apple','google')),
 next_check timestamptz not null default now(),locked_until timestamptz,
 page_token text,last_success_at timestamptz,last_error text
);
alter table public.purchase_reconciliation_state enable row level security;
create policy "Admins inspect reconciliation" on public.purchase_reconciliation_state for select to authenticated using(public.is_admin());
grant select on public.purchase_reconciliation_state to authenticated;
insert into public.purchase_reconciliation_state(platform) values('apple'),('google');
create or replace function public.claim_purchase_reconciliation(p_platform text) returns boolean
language plpgsql security definer set search_path='' as $$
begin
 update public.purchase_reconciliation_state set locked_until=now()+interval '5 minutes'
 where platform=p_platform and next_check<=now() and (locked_until is null or locked_until<now());
 return found;
end$$;
revoke all on function public.claim_purchase_reconciliation(text) from public,anon,authenticated;
grant execute on function public.claim_purchase_reconciliation(text) to service_role;
insert into public.app_settings(key,value,label,description,category,is_public) values
('store_reconciliation_enabled','false','Store-terugbetalingen controleren','Pas activeren na configuratie en controle van beide storekoppelingen.','plus',false)
on conflict(key) do nothing;
commit;
