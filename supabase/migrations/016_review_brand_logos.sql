-- Audited PasKluis logo corrections, 2026-09-22.
-- Assets were visually reviewed against store backgrounds and uploaded first.
-- Previous paths/colors are retained below for rollback. Old objects are not deleted.
-- Existing featured flags, card support, ordering and manual logo layouts are preserved.
-- Eight retained/low-resolution sources remain documented for future improvement.
-- kruidvat: Previously managed repository logo, visual identity verified
-- hema: https://static.hema.nl/on/demandware.static/Sites-HemaNL-Site/-/default/dwa4287206/images/logo.svg
-- ekoplaza: https://www.ekoplaza.nl/ — embedded official logo SVG
-- electro-world: https://www.electroworld.nl/static/version1790050405/frontend/UnitedRetail/electro/nl_NL/images/logo.svg
-- gamma: Official website asset; see source lookup scripts
-- karwei: Official website asset; see source lookup scripts
-- kiko-milano: https://www.kikocosmetics.com/
-- mediamarkt: https://cms-images.mmst.eu/jq6pdee2ul1f/6GfqbLFVL6L0UxuFHPG6yO/3c1e3962cd377dba8dc6f0207fbb5029/MM_logo_red.svg?q=80
-- my-jewellery: https://www.my-jewellery.com/
-- pets-place: https://www.petsplace.nl/static/version1789048784/frontend/ISM/ijsvogel/nl_NL/images/logo.svg
-- picnic: Existing managed Picnic wordmark, incorrectly linked to Pets Place
-- praxis: https://upload.wikimedia.org/wikipedia/commons/f/f8/Praxis_logo_2018.svg
-- we-fashion: https://www.wefashion.com/nl_NL/
-- air-miles: Official website header
-- bouwmaat: https://www.bouwmaat.nl/cdn/shop/files/Bouwmaat_BlauwDonkerBlauw_RGB.svg?v=1783008129&width=150
-- makro: Official website asset; see source lookup scripts
-- hanos: Official website asset; see source lookup scripts
-- bidfood: https://www.google.com/s2/favicons?domain_url=https://bidfood.nl&sz=256 | Existing correct raster retained and centralized; official higher-resolution wordmark still needed
-- toolstation: https://cdn.toolstation.nl/website/images/logos/toolstation-logo-halo.svg
-- pontmeyer: Official website header
-- jongeneel: Official website header
-- bouwcenter: https://api.bouwcenter.nl/siteassets/corporate/footer--header/bc_logo_rgb.svg
-- hubo: https://www.hubo.nl/
-- shell: https://www.shell.nl/_jcr_content/root/metadata.shellimg.png/1701963138104/shell-logo-svg.png
-- bp: https://www.google.com/s2/favicons?domain_url=https://bp.com&sz=256 | Existing correct raster retained and centralized; official higher-resolution wordmark still needed
-- esso: https://www.google.com/s2/favicons?domain_url=https://esso.nl&sz=256 | Existing correct raster retained and centralized; official higher-resolution wordmark still needed
-- totalenergies: Official website asset; see source lookup scripts
-- tango: https://www.tango.nl/
-- tinq: https://www.tinq.nl/sites/default/files/logo_0.png
-- q8: https://www.q8.nl/
-- ok-tankstations: https://www.google.com/s2/favicons?domain_url=https://ok.nl&sz=256 | Existing correct raster retained and centralized; official higher-resolution wordmark still needed
-- texaco: https://texaco.nl/wp-content/themes/texaco/images/logos/logo-texaco.svg
-- boni: Official website header
-- nettorama: https://www.nettorama.nl/public/themes/www/_compiled/images/logo.svg
-- poiesz: https://www.poiesz-supermarkten.nl/img/logoPoiesz.svg
-- boons-markt: Official website header
-- mcd-supermarkt: https://gewooncoop.nl/assets/images/default/MCD_logo.svg
-- odin: https://www.odin.nl/ — header SVG
-- amazing-oriental: Official website asset; see source lookup scripts
-- starbucks: https://www.starbucks.nl/
-- kfc: https://www.kfc.nl/
-- subway: Official website header
-- new-york-pizza: Official website asset; see source lookup scripts
-- febo: https://www.febo.nl/wp-content/themes/febo/images/logo.png
-- dunkin: Official website asset; see source lookup scripts
-- bagels-beans: https://www.bagelsbeans.nl/wp-content/themes/bagelsbeans/images/logo.svg
-- ranzijn: https://www.ranzijn.nl/images/icons/ranzijn-logo-full.svg
-- groenrijk: https://www.groenrijk.nl/website/default-v2/images/logo.svg
-- tuinland: https://www.tuinland.nl/website/default-v2/images/logo.svg
-- profijt-meubel: https://www.profijtmeubel.nl/profijt.svg
-- woonexpress: https://www.woonexpress.nl/media/logo/default/logo_woonexpress.svg
-- babypark: https://www.babypark.nl/media/logo/stores/1/logo.png | Official website wordmark only 216x19; higher-resolution master still needed
-- expert: https://www.expert.nl/area/web/default/assets/images/logo.svg
-- ep: Existing correct EP wordmark; verified against the official site header
-- kamera-express: https://www.google.com/s2/favicons?domain_url=https://kamera-express.nl&sz=256 | Existing correct raster retained and centralized; official higher-resolution wordmark still needed
-- alternate: https://www.alternate.nl/mobile/jakarta.faces.resource/pix/headerlogo/alt.png.xhtml
-- azerty: https://www.google.com/s2/favicons?domain_url=https://azerty.nl&sz=256 | Existing correct raster retained and centralized; official higher-resolution wordmark still needed
-- zalando: https://www.zalando.nl/ — official header SVG
-- sacha: https://www.sacha.nl/
-- manfield: https://www.manfield.com/
-- ms-mode: https://www.msmode.nl/on/demandware.static/-/Sites/default/dwc43e0cfc/logo/logo-ms.png | Official website wordmark only 75x55; higher-resolution master still needed
-- intersport: https://intersport.nl/cdn/shop/t/269/assets/intersport-logo.svg?v=172557263039771480651789712841
-- sport-2000: https://cdn.nextchapter-ecommerce.com/Public/sport2000_nl/Images/logo.svg

begin;

create temporary table reviewed_brand_logos (
  slug text primary key,
  old_logo_path text not null,
  old_brand_color text not null,
  new_logo_path text not null,
  new_brand_color text not null
) on commit drop;

insert into reviewed_brand_logos values
  ('kruidvat', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/kruidvat/1789917974472.png', '#fff1f1', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/review-20260922/kruidvat.png', '#fff1f1'),
  ('hema', 'assets/logos/hema.png', '#E30613', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/review-20260922/hema.png', '#fff1f1'),
  ('ekoplaza', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/ekoplaza/1789919970497.png', '#fff0f4', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/review-20260922/ekoplaza.png', '#ffffff'),
  ('electro-world', 'https://www.google.com/s2/favicons?domain_url=https://electroworld.nl&sz=256', '#E30613', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/review-20260922/electro-world.png', '#fff1f4'),
  ('gamma', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/gamma/1789919980196.png', '#eef3fb', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/review-20260922/gamma.png', '#ffffff'),
  ('karwei', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/karwei/1789921607052.png', '#f4f4f4', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/review-20260922/karwei.png', '#ffffff'),
  ('kiko-milano', 'https://www.google.com/s2/favicons?domain_url=https://kikocosmetics.com&sz=256', '#111111', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/review-20260922/kiko-milano.png', '#f5f5f5'),
  ('mediamarkt', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/mediamarkt/1789922849498.png', '#fff3f0', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/review-20260922/mediamarkt.png', '#fff3f0'),
  ('my-jewellery', 'https://www.google.com/s2/favicons?domain_url=https://my-jewellery.com&sz=256', '#E8B8B0', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/review-20260922/my-jewellery.png', '#fff1f5'),
  ('pets-place', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/pets-place/1789923112987.png', '#fff1f1', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/review-20260922/pets-place.png', '#ffffff'),
  ('picnic', 'https://www.google.com/s2/favicons?domain_url=https://picnic.app&sz=256', '#E30613', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/review-20260922/picnic.png', '#fff1f1'),
  ('praxis', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/praxis/1789923115122.png', '#eef3ff', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/review-20260922/praxis.png', '#333333'),
  ('we-fashion', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/we-fashion/1789923281133.png', '#f4f4f4', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/review-20260922/we-fashion.png', '#f4f4f4'),
  ('air-miles', 'https://www.google.com/s2/favicons?domain_url=https://airmiles.nl&sz=256', '#005BAA', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/review-20260922/air-miles.png', '#ffffff'),
  ('bouwmaat', 'https://www.google.com/s2/favicons?domain_url=https://bouwmaat.nl&sz=256', '#E30613', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/review-20260922/bouwmaat.png', '#edf3ff'),
  ('makro', 'https://www.google.com/s2/favicons?domain_url=https://makro.nl&sz=256', '#0050A4', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/review-20260922/makro.png', '#003d7b'),
  ('hanos', 'https://www.google.com/s2/favicons?domain_url=https://hanos.nl&sz=256', '#003B70', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/review-20260922/hanos.png', '#ffffff'),
  ('bidfood', 'https://www.google.com/s2/favicons?domain_url=https://bidfood.nl&sz=256', '#E30613', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/review-20260922/bidfood.png', '#ffffff'),
  ('toolstation', 'https://www.google.com/s2/favicons?domain_url=https://toolstation.nl&sz=256', '#005EB8', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/review-20260922/toolstation.png', '#ffffff'),
  ('pontmeyer', 'https://www.google.com/s2/favicons?domain_url=https://pontmeyer.nl&sz=256', '#005A9C', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/review-20260922/pontmeyer.png', '#ffffff'),
  ('jongeneel', 'https://www.google.com/s2/favicons?domain_url=https://jongeneel.nl&sz=256', '#E30613', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/review-20260922/jongeneel.png', '#ffffff'),
  ('bouwcenter', 'https://www.google.com/s2/favicons?domain_url=https://bouwcenter.nl&sz=256', '#F58220', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/review-20260922/bouwcenter.png', '#ffffff'),
  ('hubo', 'https://www.google.com/s2/favicons?domain_url=https://hubo.nl&sz=256', '#E30613', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/review-20260922/hubo.png', '#ffeb00'),
  ('shell', 'https://www.google.com/s2/favicons?domain_url=https://shell.nl&sz=256', '#FFD500', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/review-20260922/shell.png', '#ffffff'),
  ('bp', 'https://www.google.com/s2/favicons?domain_url=https://bp.com&sz=256', '#009900', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/review-20260922/bp.png', '#ffffff'),
  ('esso', 'https://www.google.com/s2/favicons?domain_url=https://esso.nl&sz=256', '#E30613', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/review-20260922/esso.png', '#ffffff'),
  ('totalenergies', 'https://www.google.com/s2/favicons?domain_url=https://totalenergies.nl&sz=256', '#E30613', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/review-20260922/totalenergies.png', '#ffffff'),
  ('tango', 'https://www.google.com/s2/favicons?domain_url=https://tango.nl&sz=256', '#F58220', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/review-20260922/tango.png', '#ffffff'),
  ('tinq', 'https://www.google.com/s2/favicons?domain_url=https://tinq.nl&sz=256', '#E30613', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/review-20260922/tinq.png', '#ffffff'),
  ('q8', 'https://www.google.com/s2/favicons?domain_url=https://q8.nl&sz=256', '#0050A4', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/review-20260922/q8.png', '#ffffff'),
  ('ok-tankstations', 'https://www.google.com/s2/favicons?domain_url=https://ok.nl&sz=256', '#E30613', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/review-20260922/ok-tankstations.png', '#ffffff'),
  ('texaco', 'https://www.google.com/s2/favicons?domain_url=https://texaco.nl&sz=256', '#E30613', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/review-20260922/texaco.png', '#ffffff'),
  ('boni', 'https://www.google.com/s2/favicons?domain_url=https://boni.nl&sz=256', '#E30613', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/review-20260922/boni.png', '#db0200'),
  ('nettorama', 'https://www.google.com/s2/favicons?domain_url=https://nettorama.nl&sz=256', '#005BAA', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/review-20260922/nettorama.png', '#fff9df'),
  ('poiesz', 'https://www.google.com/s2/favicons?domain_url=https://poiesz-supermarkten.nl&sz=256', '#E30613', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/review-20260922/poiesz.png', '#ffffff'),
  ('boons-markt', 'https://www.google.com/s2/favicons?domain_url=https://boonsmarkt.nl&sz=256', '#009640', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/review-20260922/boons-markt.png', '#ffffff'),
  ('mcd-supermarkt', 'https://www.google.com/s2/favicons?domain_url=https://mcd-supermarkt.nl&sz=256', '#E30613', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/review-20260922/mcd-supermarkt.png', '#ffffff'),
  ('odin', 'https://www.google.com/s2/favicons?domain_url=https://odin.nl&sz=256', '#6F8F2F', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/review-20260922/odin.png', '#ffffff'),
  ('amazing-oriental', 'https://www.google.com/s2/favicons?domain_url=https://amazingoriental.com&sz=256', '#E30613', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/review-20260922/amazing-oriental.png', '#ffffff'),
  ('starbucks', 'https://www.google.com/s2/favicons?domain_url=https://starbucks.nl&sz=256', '#00754A', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/review-20260922/starbucks.png', '#ffffff'),
  ('kfc', 'https://www.google.com/s2/favicons?domain_url=https://kfc.nl&sz=256', '#E4002B', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/review-20260922/kfc.png', '#ffffff'),
  ('subway', 'https://www.google.com/s2/favicons?domain_url=https://subway.com&sz=256', '#008C15', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/review-20260922/subway.png', '#ffffff'),
  ('new-york-pizza', 'https://www.google.com/s2/favicons?domain_url=https://newyorkpizza.nl&sz=256', '#E30613', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/review-20260922/new-york-pizza.png', '#ffffff'),
  ('febo', 'https://www.google.com/s2/favicons?domain_url=https://febo.nl&sz=256', '#E30613', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/review-20260922/febo.png', '#d71920'),
  ('dunkin', 'https://www.google.com/s2/favicons?domain_url=https://dunkin.nl&sz=256', '#FF671F', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/review-20260922/dunkin.png', '#ffffff'),
  ('bagels-beans', 'https://www.google.com/s2/favicons?domain_url=https://bagelsbeans.nl&sz=256', '#6B3F2A', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/review-20260922/bagels-beans.png', '#ffffff'),
  ('ranzijn', 'https://www.google.com/s2/favicons?domain_url=https://ranzijn.nl&sz=256', '#65A30D', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/review-20260922/ranzijn.png', '#ffffff'),
  ('groenrijk', 'https://www.google.com/s2/favicons?domain_url=https://groenrijk.nl&sz=256', '#00843D', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/review-20260922/groenrijk.png', '#ffffff'),
  ('tuinland', 'https://www.google.com/s2/favicons?domain_url=https://tuinland.nl&sz=256', '#2E7D32', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/review-20260922/tuinland.png', '#006449'),
  ('profijt-meubel', 'https://www.google.com/s2/favicons?domain_url=https://profijtmeubel.nl&sz=256', '#E30613', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/review-20260922/profijt-meubel.png', '#ffffff'),
  ('woonexpress', 'https://www.google.com/s2/favicons?domain_url=https://woonexpress.nl&sz=256', '#E50046', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/review-20260922/woonexpress.png', '#ffffff'),
  ('babypark', 'https://www.google.com/s2/favicons?domain_url=https://babypark.nl&sz=256', '#7A4B9D', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/review-20260922/babypark.png', '#ffffff'),
  ('expert', 'https://www.google.com/s2/favicons?domain_url=https://expert.nl&sz=256', '#E30613', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/review-20260922/expert.png', '#ef7d00'),
  ('ep', 'https://www.google.com/s2/favicons?domain_url=https://ep.nl&sz=256', '#E30613', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/review-20260922/ep.png', '#ffffff'),
  ('kamera-express', 'https://www.google.com/s2/favicons?domain_url=https://kamera-express.nl&sz=256', '#E30613', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/review-20260922/kamera-express.png', '#ffffff'),
  ('alternate', 'https://www.google.com/s2/favicons?domain_url=https://alternate.nl&sz=256', '#E30613', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/review-20260922/alternate.png', '#ffffff'),
  ('azerty', 'https://www.google.com/s2/favicons?domain_url=https://azerty.nl&sz=256', '#F58220', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/review-20260922/azerty.png', '#ffffff'),
  ('zalando', 'https://www.google.com/s2/favicons?domain_url=https://zalando.nl&sz=256', '#FF6900', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/review-20260922/zalando.png', '#ffffff'),
  ('sacha', 'https://www.google.com/s2/favicons?domain_url=https://sacha.nl&sz=256', '#111111', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/review-20260922/sacha.png', '#f5f3f0'),
  ('manfield', 'https://www.google.com/s2/favicons?domain_url=https://manfield.com&sz=256', '#111111', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/review-20260922/manfield.png', '#f5f3f0'),
  ('ms-mode', 'https://www.google.com/s2/favicons?domain_url=https://msmode.nl&sz=256', '#111111', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/review-20260922/ms-mode.png', '#f5f5f5'),
  ('intersport', 'https://www.google.com/s2/favicons?domain_url=https://intersport.nl&sz=256', '#0055A5', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/review-20260922/intersport.png', '#ffffff'),
  ('sport-2000', 'https://www.google.com/s2/favicons?domain_url=https://sport2000.nl&sz=256', '#E30613', 'https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/object/public/brand-logos/review-20260922/sport-2000.png', '#ffffff');

-- Abort rather than overwrite an administrator's newer logo or colour adjustment.
do $$
begin
  if (select count(*) from public.brands b join reviewed_brand_logos r using (slug)) <> 63 then
    raise exception 'Logo review expects all 63 catalogued brands to exist';
  end if;
  if exists (
    select 1 from public.brands b join reviewed_brand_logos r using (slug)
    where not (
      (b.logo_path is not distinct from r.old_logo_path and b.brand_color is not distinct from r.old_brand_color)
      or
      (b.logo_path is not distinct from r.new_logo_path and b.brand_color is not distinct from r.new_brand_color)
    )
  ) then
    raise exception 'A logo or background changed since the audit; review before applying';
  end if;
end $$;

update public.brands b
set logo_path = r.new_logo_path,
    brand_color = r.new_brand_color,
    updated_at = now()
from reviewed_brand_logos r
where b.slug = r.slug
  and (b.logo_path is distinct from r.new_logo_path
       or b.brand_color is distinct from r.new_brand_color);

commit;

select count(*) as corrected_brands
from public.brands
where logo_path like '%/brand-logos/review-20260922/%';
