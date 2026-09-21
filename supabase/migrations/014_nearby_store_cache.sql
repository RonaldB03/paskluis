create table if not exists public.nearby_store_cache (
  cache_key text primary key,
  brand_name text not null,
  origin_latitude double precision not null,
  origin_longitude double precision not null,
  store_name text not null,
  store_address text not null default '',
  store_latitude double precision not null,
  store_longitude double precision not null,
  distance_meters double precision not null,
  expires_at timestamptz not null,
  updated_at timestamptz not null default now()
);

create table if not exists public.places_api_monthly_usage (
  month_start date primary key,
  request_count integer not null default 0 check (request_count >= 0),
  updated_at timestamptz not null default now()
);

alter table public.nearby_store_cache enable row level security;
alter table public.places_api_monthly_usage enable row level security;

-- These tables are deliberately service-role only. The mobile app talks to
-- the Edge Function and never receives the Google Places API key.
revoke all on public.nearby_store_cache from anon, authenticated;
revoke all on public.places_api_monthly_usage from anon, authenticated;
