-- Finish the eight pending logo sources from migration 016, plus GAMMA.
-- Reviewed visually on their card backgrounds on 2026-09-22.
-- Versioned PNGs are uploaded first; old files remain available for rollback.
-- Preserve all manual layout, featured, recognition and card-support settings.
-- OK: original vector from the branding agency, using red #ca2030 from
-- https://assets.tango.nl/f/318005/2b28a56cc5/ok-logo.png (official partner).
-- gamma: https://www.gamma.nl/; PNG 1200x400
-- babypark: https://static.wekelijkse-folders.nl/image/shop/babypark/logo.jpg; PNG 994x98
-- ms-mode: https://upload.wikimedia.org/wikipedia/commons/f/f4/MS_Mode_logo_2018.jpg; PNG 640x470
-- bidfood: https://www.bidfood.co.uk/wp-content/themes/bidvest/images/bidfood_logo_scaled.png; PNG 511x190
-- bp: https://upload.wikimedia.org/wikipedia/en/d/d2/BP_Helios_logo.svg; PNG 1200x1594
-- esso: https://upload.wikimedia.org/wikipedia/commons/2/22/Esso_textlogo.svg; PNG 1200x851
-- kamera-express: https://www.kamera-express.academy/; PNG 1000x1000
-- azerty: https://www.connectingthedots.nl/azerty-pim; PNG 1146x228
-- ok-tankstations: https://schmuhl.nl/wp-content/uploads/2024/02/LogoOK.svg; PNG 964x440

begin;
create temporary table final_brand_logos (
  slug text primary key,
  old_logo_path text not null,
  old_brand_color text not null,
  new_logo_path text not null,
  new_brand_color text not null
) on commit drop;

insert into final_brand_logos values
  ('gamma', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/review-20260922/gamma.png', '#ffffff', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/review-20260922/gamma-v2.png', '#003878'),
  ('babypark', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/review-20260922/babypark.png', '#ffffff', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/review-20260922/babypark-v2.png', '#ffffff'),
  ('ms-mode', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/review-20260922/ms-mode.png', '#f5f5f5', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/review-20260922/ms-mode-v2.png', '#ffffff'),
  ('bidfood', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/review-20260922/bidfood.png', '#ffffff', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/review-20260922/bidfood-v2.png', '#ffffff'),
  ('bp', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/review-20260922/bp.png', '#ffffff', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/review-20260922/bp-v2.png', '#ffffff'),
  ('esso', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/review-20260922/esso.png', '#ffffff', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/review-20260922/esso-v2.png', '#ffffff'),
  ('kamera-express', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/review-20260922/kamera-express.png', '#ffffff', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/review-20260922/kamera-express-v2.png', '#ffffff'),
  ('azerty', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/review-20260922/azerty.png', '#ffffff', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/review-20260922/azerty-v2.png', '#ffffff'),
  ('ok-tankstations', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/review-20260922/ok-tankstations.png', '#ffffff', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/review-20260922/ok-tankstations-v2.png', '#ffffff');

-- A concurrent administrator change must be reviewed, never overwritten.
do $$
begin
  if (select count(*) from public.brands b join final_brand_logos r using (slug)) <> 9 then
    raise exception 'Expected all nine reviewed brands to exist';
  end if;
  if exists (
    select 1 from public.brands b join final_brand_logos r using (slug)
    where not (
      (b.logo_path is not distinct from r.old_logo_path and b.brand_color is not distinct from r.old_brand_color)
      or
      (b.logo_path is not distinct from r.new_logo_path and b.brand_color is not distinct from r.new_brand_color)
    )
  ) then
    raise exception 'A logo or background changed after review; inspect before applying';
  end if;
end $$;

update public.brands b
set logo_path = r.new_logo_path,
    brand_color = r.new_brand_color,
    updated_at = now()
from final_brand_logos r
where b.slug = r.slug
  and (b.logo_path is distinct from r.new_logo_path
       or b.brand_color is distinct from r.new_brand_color);

commit;

select count(*) as final_logos_verified
from public.brands
where logo_path like '%/brand-logos/review-20260922/%-v2.png';
