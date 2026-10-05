begin;
alter table public.store_purchases add column store_account_token text;
alter table public.store_purchases add column accountless boolean not null default false;
alter table public.store_purchases add column account_linked boolean not null default false;
update public.store_purchases set account_linked=true where user_id is not null;

-- Only the receipt-verifying Edge Function may call this. Client roles cannot
-- grant access, inspect receipts, reassign purchases or clear a revocation.
create function public.record_store_purchase_v2(p_user_id uuid,p_platform text,p_transaction_id text,p_environment text,p_revoked boolean,p_store_account_token text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare purchase public.store_purchases%rowtype; legacy_owner uuid;
begin
 if p_platform not in ('apple','google') or p_environment not in ('production','sandbox') or p_transaction_id is null or length(p_transaction_id)>256 then raise exception 'INVALID_STORE'; end if;
 -- Global lock order: receipt then account. Old builds take only the account lock.
 perform pg_advisory_xact_lock(hashtextextended(p_platform||':'||p_transaction_id,1));
 select * into purchase from public.store_purchases where platform=p_platform and transaction_id=p_transaction_id;
 if not found then
  select id into legacy_owner from auth.users where id::text=p_store_account_token;
  insert into public.store_purchases(user_id,platform,transaction_id,product_id,environment,store_account_token,accountless,account_linked)
   values(legacy_owner,p_platform,p_transaction_id,'paskluis_plus',p_environment,p_store_account_token,legacy_owner is null,legacy_owner is not null)
   on conflict(platform,transaction_id) do nothing;
 end if;
 select * into purchase from public.store_purchases where platform=p_platform and transaction_id=p_transaction_id;
 if purchase.environment<>p_environment or (purchase.store_account_token is not null and purchase.store_account_token is distinct from p_store_account_token) then raise exception 'INVALID_STORE_IDENTITY'; end if;
 if coalesce(purchase.user_id,p_user_id) is not null then
  perform pg_advisory_xact_lock(hashtextextended(coalesce(purchase.user_id,p_user_id)::text,0));
 end if;
 if p_user_id is not null and purchase.user_id is distinct from p_user_id then
  if not purchase.accountless or purchase.account_linked or p_revoked then raise exception 'PURCHASE_LINKED_TO_ANOTHER_ACCOUNT'; end if;
  update public.store_purchases set user_id=p_user_id,account_linked=true where id=purchase.id;
  purchase.user_id:=p_user_id;
 end if;
 -- Keep refund state and legacy entitlement calculation in one transaction.
 if purchase.user_id is not null then
  perform public.record_verified_purchase(purchase.user_id,p_platform,p_transaction_id,p_environment,p_revoked);
 else
  update public.store_purchases set verified_at=now(),revoked_at=case when p_revoked then now() end where id=purchase.id;
 end if;
 update public.store_purchases set store_account_token=p_store_account_token where id=purchase.id and store_account_token is null;
 return jsonb_build_object('active',not p_revoked,'linkedUserId',purchase.user_id);
end; $$;
revoke all on function public.record_store_purchase_v2(uuid,text,text,text,boolean,text) from public,anon,authenticated;
grant execute on function public.record_store_purchase_v2(uuid,text,text,text,boolean,text) to service_role;
commit;
