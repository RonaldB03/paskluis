begin;
alter table public.nearby_store_cache add column if not exists candidates jsonb;
create or replace function public.reserve_places_request() returns boolean
language plpgsql security definer set search_path='' as $$
declare claimed integer;
begin
 insert into public.places_api_monthly_usage(month_start,request_count,updated_at)
 values(date_trunc('month',now() at time zone 'UTC')::date,1,now())
 on conflict(month_start) do update set request_count=public.places_api_monthly_usage.request_count+1,updated_at=now()
 where public.places_api_monthly_usage.request_count<4500 returning request_count into claimed;
 return claimed is not null;
end; $$;
revoke all on function public.reserve_places_request() from public,anon,authenticated;
grant execute on function public.reserve_places_request() to service_role;
commit;
