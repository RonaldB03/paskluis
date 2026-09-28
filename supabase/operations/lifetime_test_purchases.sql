-- Give verified one-time test purchases the same access duration as production.
-- Run after migrations/024_store_purchases.sql. Does not re-enable revoked access.
begin;
CREATE OR REPLACE FUNCTION public.record_verified_purchase(p_user_id uuid, p_platform text, p_transaction_id text, p_environment text, p_revoked boolean)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare owner_id uuid; source_value public.entitlement_source; until_date timestamptz; best_purchase public.store_purchases%rowtype;
begin
 if p_platform not in ('apple','google') or p_environment not in ('production','sandbox') then raise exception 'INVALID_STORE'; end if;
 perform pg_advisory_xact_lock(hashtextextended(p_user_id::text,0));
 insert into public.store_purchases(user_id,platform,transaction_id,product_id,environment,revoked_at)
 values(p_user_id,p_platform,p_transaction_id,'paskluis_plus',p_environment,case when p_revoked then now() end)
 on conflict(platform,transaction_id) do nothing;
 select user_id into owner_id from public.store_purchases where platform=p_platform and transaction_id=p_transaction_id for update;
 if owner_id is distinct from p_user_id then raise exception 'PURCHASE_LINKED_TO_ANOTHER_ACCOUNT'; end if;
 update public.store_purchases set verified_at=now(),revoked_at=case when p_revoked then now() end
 where platform=p_platform and transaction_id=p_transaction_id;
 -- A user may own purchases on both stores. Recompute access from all valid
 -- purchases, so refunding them in either order cannot leave stale Plus access.
 -- Active staff-granted access is independent of store purchases.
 if exists(select 1 from public.entitlements where user_id=p_user_id and product_id='paskluis_plus'
  and source='complimentary' and revoked_at is null and starts_at<=now()
  and (expires_at is null or expires_at>now())) then return not p_revoked; end if;
 select * into best_purchase from public.store_purchases where user_id=p_user_id
  and product_id='paskluis_plus' and revoked_at is null
  order by (environment='production') desc,verified_at desc,id limit 1;
 if not found then
  update public.entitlements set revoked_at=now() where user_id=p_user_id and product_id='paskluis_plus'
   and source in ('apple','google') and revoked_at is null;
  return false;
 end if;
 source_value:=best_purchase.platform::public.entitlement_source;
 -- One-time test and production purchases both grant access without an expiry.
 until_date:=null;
 update public.entitlements set revoked_at=now() where user_id=p_user_id and product_id='paskluis_plus' and revoked_at is null;
 insert into public.entitlements(user_id,product_id,source,expires_at,note)
 values(p_user_id,'paskluis_plus',source_value,until_date,case when best_purchase.environment='sandbox' then 'Verified store test purchase' else 'Verified store purchase' end);
 return not p_revoked;
end; $function$
;
revoke all on function public.record_verified_purchase(uuid,text,text,text,boolean) from public,anon,authenticated;
grant execute on function public.record_verified_purchase(uuid,text,text,text,boolean) to service_role;
update public.entitlements e set expires_at=null
where e.product_id='paskluis_plus' and e.source in ('apple','google')
 and e.note='Verified store test purchase' and e.revoked_at is null
 and e.expires_at is not null
 and exists(select 1 from public.store_purchases p where p.user_id=e.user_id
  and p.platform=e.source::text and p.product_id=e.product_id
  and p.environment='sandbox' and p.revoked_at is null);
commit;
