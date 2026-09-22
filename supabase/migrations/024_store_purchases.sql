begin;
create table public.store_purchases (
 id uuid primary key default gen_random_uuid(),user_id uuid references auth.users(id) on delete set null,
 platform text not null check(platform in ('apple','google')),transaction_id text not null,
 product_id text not null,environment text not null check(environment in ('production','sandbox')),
 revoked_at timestamptz,verified_at timestamptz not null default now(),created_at timestamptz not null default now(),
 unique(platform,transaction_id)
);
alter table public.store_purchases enable row level security;
create policy "Admins inspect purchase status" on public.store_purchases for select to authenticated using(public.is_admin());
grant select on public.store_purchases to authenticated;
create or replace function public.record_verified_purchase(p_user_id uuid,p_platform text,p_transaction_id text,p_environment text,p_revoked boolean)
returns boolean language plpgsql security definer set search_path='' as $$
declare owner_id uuid; source_value public.entitlement_source; until_date timestamptz;
begin
 if p_platform not in ('apple','google') or p_environment not in ('production','sandbox') then raise exception 'INVALID_STORE'; end if;
 perform pg_advisory_xact_lock(hashtextextended(p_user_id::text,0));
 source_value:=p_platform::public.entitlement_source;
 insert into public.store_purchases(user_id,platform,transaction_id,product_id,environment,revoked_at)
 values(p_user_id,p_platform,p_transaction_id,'paskluis_plus',p_environment,case when p_revoked then now() end)
 on conflict(platform,transaction_id) do nothing;
 select user_id into owner_id from public.store_purchases where platform=p_platform and transaction_id=p_transaction_id for update;
 if owner_id is distinct from p_user_id then raise exception 'PURCHASE_LINKED_TO_ANOTHER_ACCOUNT'; end if;
 update public.store_purchases set verified_at=now(),revoked_at=case when p_revoked then now() end
 where platform=p_platform and transaction_id=p_transaction_id;
 if p_revoked then
  update public.entitlements set revoked_at=now() where user_id=p_user_id and product_id='paskluis_plus' and source=source_value and revoked_at is null
   and not exists(select 1 from public.store_purchases where user_id=p_user_id and revoked_at is null);
  return false;
 end if;
 until_date:=case when p_environment='sandbox' then now()+interval '7 days' else null end;
 -- Preserve complimentary and existing permanent access; a sandbox restore cannot downgrade it.
 if exists(select 1 from public.entitlements where user_id=p_user_id and product_id='paskluis_plus' and revoked_at is null and expires_at is null) then return true; end if;
 update public.entitlements set revoked_at=now() where user_id=p_user_id and product_id='paskluis_plus' and revoked_at is null;
 insert into public.entitlements(user_id,product_id,source,expires_at,note)
 values(p_user_id,'paskluis_plus',source_value,until_date,case when p_environment='sandbox' then 'Verified store test purchase' else 'Verified store purchase' end);
 return true;
end; $$;
revoke all on function public.record_verified_purchase(uuid,text,text,text,boolean) from public,anon,authenticated;
grant execute on function public.record_verified_purchase(uuid,text,text,text,boolean) to service_role;
insert into public.app_settings(key,value,label,description,category,is_public) values
('store_purchase_enabled','false','Winkelaankopen beschikbaar','Pas aanzetten nadat beide storeproducten en de serververificatie zijn getest.','plus',true)
on conflict(key) do nothing;
commit;
