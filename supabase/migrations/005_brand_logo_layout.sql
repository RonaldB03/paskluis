-- Per-brand logo positioning for every place logos are shown in the app.
alter table public.brands
  add column if not exists logo_home_scale numeric not null default 1,
  add column if not exists logo_home_x numeric not null default 0,
  add column if not exists logo_home_y numeric not null default 0,
  add column if not exists logo_loyalty_scale numeric not null default 1,
  add column if not exists logo_loyalty_x numeric not null default 0,
  add column if not exists logo_loyalty_y numeric not null default 0,
  add column if not exists logo_gift_scale numeric not null default 1,
  add column if not exists logo_gift_x numeric not null default 0,
  add column if not exists logo_gift_y numeric not null default 0,
  add column if not exists logo_detail_scale numeric not null default 1,
  add column if not exists logo_detail_x numeric not null default 0,
  add column if not exists logo_detail_y numeric not null default 0,
  add column if not exists logo_picker_scale numeric not null default 1,
  add column if not exists logo_picker_x numeric not null default 0,
  add column if not exists logo_picker_y numeric not null default 0;

alter table public.brands
  drop constraint if exists brands_logo_scale_range;
alter table public.brands
  add constraint brands_logo_scale_range check (
    logo_home_scale between 0.5 and 2.5 and
    logo_loyalty_scale between 0.5 and 2.5 and
    logo_gift_scale between 0.5 and 2.5 and
    logo_detail_scale between 0.5 and 2.5 and
    logo_picker_scale between 0.5 and 2.5
  );
