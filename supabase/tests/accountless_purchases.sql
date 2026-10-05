-- Executed inside a rollback-only migration rehearsal.
do $$
declare a uuid; b uuid; result jsonb; rejected boolean;
begin
 select id into a from auth.users order by id limit 1;
 select id into b from auth.users where id<>a order by id limit 1;
 if a is null or b is null then raise exception 'Need two existing accounts for rollback-only ownership test'; end if;
 result:=public.record_store_purchase_v2(null,'apple','regression-guest','sandbox',false,'11111111-1111-4111-8111-111111111111');
 if result->>'active'<>'true' or result->>'linkedUserId' is not null then raise exception 'Guest grant failed'; end if;
 result:=public.record_store_purchase_v2(a,'apple','regression-guest','sandbox',false,'11111111-1111-4111-8111-111111111111');
 if result->>'linkedUserId'<>a::text then raise exception 'Claim failed'; end if;
 rejected:=false;
 begin perform public.record_store_purchase_v2(b,'apple','regression-guest','sandbox',false,'11111111-1111-4111-8111-111111111111');
 exception when others then if sqlerrm like '%PURCHASE_LINKED%' then rejected:=true; else raise; end if; end;
 if not rejected then raise exception 'Cross-account claim accepted'; end if;
 result:=public.record_store_purchase_v2(null,'apple','regression-guest','sandbox',true,'11111111-1111-4111-8111-111111111111');
 if result->>'active'<>'false' then raise exception 'Refund failed'; end if;
 perform public.record_store_purchase_v2(null,'google','regression-google','production',false,null);
 perform public.record_store_purchase_v2(null,'google','regression-google','production',true,null);
 if not exists(select 1 from public.store_purchases where transaction_id='regression-google' and revoked_at is not null) then raise exception 'Guest refund missing'; end if;
 perform public.record_verified_purchase(a,'apple','regression-legacy','production',false);
 rejected:=false;
 begin perform public.record_store_purchase_v2(b,'apple','regression-legacy','production',false,a::text);
 exception when others then if sqlerrm like '%PURCHASE_LINKED%' then rejected:=true; else raise; end if; end;
 if not rejected then raise exception 'Legacy transfer accepted'; end if;
 -- Deleting an account cannot make a previously linked receipt claimable again.
 update public.store_purchases set user_id=null where transaction_id='regression-guest';
 rejected:=false;
 begin perform public.record_store_purchase_v2(b,'apple','regression-guest','sandbox',false,'11111111-1111-4111-8111-111111111111');
 exception when others then if sqlerrm like '%PURCHASE_LINKED%' then rejected:=true; else raise; end if; end;
 if not rejected then raise exception 'Deleted owner claim accepted'; end if;
 if has_function_privilege('anon','public.record_store_purchase_v2(uuid,text,text,text,boolean,text)','execute') or has_function_privilege('authenticated','public.record_store_purchase_v2(uuid,text,text,text,boolean,text)','execute') then raise exception 'Client may grant purchases'; end if;
end $$;
