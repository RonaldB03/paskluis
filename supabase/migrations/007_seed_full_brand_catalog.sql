-- Complete PasKluis store catalogue.
--
-- The seed is deliberately idempotent: it can be run more than once without
-- creating duplicates. Existing uploaded/custom logos and recognition rules
-- win over the defaults below.

with seed (
  sort_order,
  slug,
  name,
  domain,
  brand_color,
  supports_loyalty_card,
  supports_gift_card,
  is_featured,
  aliases
) as (
  values
    (1, 'albert-heijn', 'Albert Heijn', 'ah.nl', '#00A6D6', true, true, true, array['ah', 'bonuskaart']),
    (2, 'jumbo', 'Jumbo', 'jumbo.com', '#FFC400', true, true, true, array['jumbo extra''s']),
    (3, 'kruidvat', 'Kruidvat', 'kruidvat.nl', '#E30613', true, true, true, array['kruidvat club']),
    (4, 'hema', 'HEMA', 'hema.nl', '#E30613', true, true, true, array['hema pas']),
    (5, 'lidl', 'Lidl', 'lidl.nl', '#0050AA', true, false, true, array['lidl plus']),
    (6, 'action', 'Action', 'action.com', '#0050AA', false, true, true, array['action cadeaukaart']),
    (7, 'plus', 'PLUS', 'plus.nl', '#78BE20', true, true, true, array['plus supermarkt']),
    (8, 'gall-gall', 'Gall & Gall', 'gall.nl', '#F58220', true, true, true, array['gall en gall', 'gall&gall']),
    (9, 'bol-com', 'bol.com', 'bol.com', '#0000A4', false, true, true, array['bol', 'bol cadeaukaart']),
    (10, 'vvv-cadeaukaart', 'VVV Cadeaukaart', 'vvvcadeaukaarten.nl', '#F58220', false, true, true, array['vvv', 'vvv bon']),

    (11, 'adidas', 'adidas', 'adidas.nl', '#000000', true, true, false, array['adidas membership']),
    (12, 'aldi', 'ALDI', 'aldi.nl', '#001E50', false, false, false, array['aldi nederland']),
    (13, 'amazon-nl', 'Amazon.nl', 'amazon.nl', '#FF9900', false, true, false, array['amazon', 'amazon cadeaukaart']),
    (14, 'amac', 'Amac', 'amac.nl', '#111111', true, true, false, array['amac club']),
    (15, 'america-today', 'America Today', 'america-today.com', '#C41230', true, true, false, array['america today giftcard']),
    (16, 'anwb', 'ANWB', 'anwb.nl', '#FFCC00', true, true, false, array['anwb ledenpas']),
    (17, 'apple', 'Apple', 'apple.com', '#111111', false, true, false, array['apple gift card', 'app store']),
    (18, 'bakker-bart', 'Bakker Bart', 'bakkerbart.nl', '#F5A623', true, true, false, array['bakkerbart']),
    (19, 'bax-music', 'Bax Music', 'bax-shop.nl', '#FF6B00', false, true, false, array['bax shop']),
    (20, 'beter-bed', 'Beter Bed', 'beterbed.nl', '#0057A4', true, true, false, array['beterbed']),
    (21, 'bever', 'Bever', 'bever.nl', '#007A3D', true, true, false, array['bever buitensport']),
    (22, 'bijenkorf', 'Bijenkorf', 'debijenkorf.nl', '#111111', true, true, false, array['de bijenkorf']),
    (23, 'bruna', 'Bruna', 'bruna.nl', '#E30613', true, true, false, array['bruna cadeaukaart']),
    (24, 'burger-king', 'Burger King', 'burgerking.nl', '#D62300', true, true, false, array['bk', 'burgerking']),
    (25, 'c-and-a', 'C&A', 'c-and-a.com', '#D71920', true, true, false, array['c&a', 'c en a']),
    (26, 'calzedonia', 'Calzedonia', 'calzedonia.com', '#111111', true, true, false, array['calzedonia club']),
    (27, 'chasin', 'Chasin''', 'chasin.nl', '#111111', true, true, false, array['chasin']),
    (28, 'claires', 'Claire''s', 'claires.com', '#D5007F', true, true, false, array['claires']),
    (29, 'coolblue', 'Coolblue', 'coolblue.nl', '#0090E3', true, true, false, array['cool blue']),
    (30, 'costes', 'Costes', 'costesfashion.com', '#111111', true, true, false, array['costes fashion']),
    (31, 'cotton-club', 'Cotton Club', 'cottonclub.nl', '#111111', true, true, false, array['cottonclub']),
    (32, 'decathlon', 'Decathlon', 'decathlon.nl', '#0082C3', true, true, false, array['decathlon membership']),
    (33, 'deichmann', 'Deichmann', 'deichmann.com', '#0050AA', true, true, false, array['deichmann schoenen']),
    (34, 'dille-kamille', 'Dille & Kamille', 'dille-kamille.nl', '#506B43', true, true, false, array['dille en kamille']),
    (35, 'dirk', 'Dirk', 'dirk.nl', '#D71920', true, false, false, array['dirk van den broek']),
    (36, 'dominos', 'Domino''s', 'dominos.nl', '#006491', true, true, false, array['dominos pizza']),
    (37, 'douglas', 'Douglas', 'douglas.nl', '#111111', true, true, false, array['douglas beauty card']),
    (38, 'd-reizen', 'D-reizen', 'dreizen.nl', '#E30613', false, true, false, array['d reizen']),
    (39, 'ecco', 'Ecco', 'ecco.com', '#8B0000', true, true, false, array['ecco shoes']),
    (40, 'efteling', 'Efteling', 'efteling.com', '#B2945E', true, true, false, array['efteling abonnement']),
    (41, 'ekoplaza', 'Ekoplaza', 'ekoplaza.nl', '#7AA33D', true, true, false, array['eko plaza']),
    (42, 'electro-world', 'Electro World', 'electroworld.nl', '#E30613', false, true, false, array['electroworld']),
    (43, 'etos', 'Etos', 'etos.nl', '#00A6D6', true, true, false, array['etos extra']),
    (44, 'foot-locker', 'Foot Locker', 'footlocker.nl', '#E31837', true, true, false, array['footlocker']),
    (45, 'gamma', 'GAMMA', 'gamma.nl', '#003B7A', true, true, false, array['gamma voordeelpas']),
    (46, 'g-star-raw', 'G-Star RAW', 'g-star.com', '#111111', true, true, false, array['g star', 'gstar']),
    (47, 'greetz', 'Greetz', 'greetz.nl', '#E6007E', true, true, false, array['greetz cadeaukaart']),
    (48, 'h-and-m', 'H&M', 'hm.com', '#E50010', true, true, false, array['h&m', 'h en m']),
    (49, 'holland-barrett', 'Holland & Barrett', 'hollandandbarrett.nl', '#006341', true, true, false, array['holland and barrett']),
    (50, 'hoogvliet', 'Hoogvliet', 'hoogvliet.com', '#E30613', true, true, false, array['hoogvliet supermarkt']),
    (51, 'hornbach', 'Hornbach', 'hornbach.nl', '#F28C00', true, true, false, array['hornbach projectbonus']),
    (52, 'hunkemoller', 'Hunkemöller', 'hunkemoller.nl', '#E5007D', true, true, false, array['hunkemoller', 'hunkemöller membercard']),
    (53, 'ici-paris-xl', 'ICI PARIS XL', 'iciparisxl.nl', '#6B1F7B', true, true, false, array['ici paris', 'ici paris xl beauty member']),
    (54, 'ikea', 'IKEA', 'ikea.nl', '#0058A3', true, true, false, array['ikea family']),
    (55, 'intertoys', 'Intertoys', 'intertoys.nl', '#E30613', true, true, false, array['intertoys cadeaukaart']),
    (56, 'intratuin', 'Intratuin', 'intratuin.nl', '#138A45', true, true, false, array['intratuin extra']),
    (57, 'jack-jones', 'Jack & Jones', 'jackjones.com', '#111111', true, true, false, array['jack and jones']),
    (58, 'jamin', 'Jamin', 'jamin.nl', '#E5007D', true, true, false, array['jamin snoep']),
    (59, 'jd-sports', 'JD Sports', 'jdsports.nl', '#111111', true, true, false, array['jd']),
    (60, 'jysk', 'JYSK', 'jysk.nl', '#004B8D', true, true, false, array['jysk club']),
    (61, 'karwei', 'Karwei', 'karwei.nl', '#F58220', true, true, false, array['karwei klantenkaart']),
    (62, 'kiko-milano', 'KIKO Milano', 'kikocosmetics.com', '#111111', true, true, false, array['kiko cosmetics']),
    (63, 'kwantum', 'Kwantum', 'kwantum.nl', '#E30613', true, true, false, array['kwantum voordeel']),
    (64, 'la-place', 'La Place', 'laplace.com', '#72A942', true, true, false, array['laplace']),
    (65, 'leen-bakker', 'Leen Bakker', 'leenbakker.nl', '#E30613', true, true, false, array['leenbakker']),
    (66, 'lego', 'LEGO', 'lego.com', '#E3000B', true, true, false, array['lego insiders']),
    (67, 'loods-5', 'Loods 5', 'loods5.nl', '#111111', true, true, false, array['loods5']),
    (68, 'lucardi', 'Lucardi', 'lucardi.nl', '#E5007D', true, true, false, array['lucardi juwelier']),
    (69, 'mango', 'Mango', 'mango.com', '#111111', true, true, false, array['mango likes you']),
    (70, 'mcdonalds', 'McDonald''s', 'mcdonalds.com', '#FFC72C', true, true, false, array['mcdonalds', 'mcdonald''s app']),
    (71, 'mediamarkt', 'MediaMarkt', 'mediamarkt.nl', '#DF0000', true, true, false, array['media markt']),
    (72, 'my-jewellery', 'My Jewellery', 'my-jewellery.com', '#E8B8B0', true, true, false, array['my jewellery member']),
    (73, 'nelson', 'Nelson', 'nelson.nl', '#111111', true, true, false, array['nelson schoenen']),
    (74, 'nespresso', 'Nespresso', 'nespresso.com', '#6F4E37', true, true, false, array['nespresso club']),
    (75, 'nike', 'Nike', 'nike.com', '#111111', true, true, false, array['nike member']),
    (76, 'only', 'ONLY', 'only.com', '#111111', true, true, false, array['only members']),
    (77, 'omoda', 'Omoda', 'omoda.nl', '#111111', true, true, false, array['omoda shoes']),
    (78, 'open32', 'OPEN32', 'open32.nl', '#111111', true, true, false, array['open 32']),
    (79, 'pathe', 'Pathé', 'pathe.nl', '#FFD500', true, true, false, array['pathe', 'pathé unlimited']),
    (80, 'pearle', 'Pearle', 'pearle.nl', '#006341', true, true, false, array['pearle opticiens']),
    (81, 'pets-place', 'Pets Place', 'petsplace.nl', '#F58220', true, true, false, array['petsplace', 'pets place friends']),
    (82, 'picnic', 'Picnic', 'picnic.app', '#E30613', true, false, false, array['picnic supermarkt']),
    (83, 'praxis', 'Praxis', 'praxis.nl', '#F58220', true, true, false, array['praxis plus']),
    (84, 'primera', 'Primera', 'primera.nl', '#0050AA', true, true, false, array['primera cadeaukaart']),
    (85, 'prenatal', 'Prénatal', 'prenatal.nl', '#E5007D', true, true, false, array['prenatal', 'prénatal club']),
    (86, 'rituals', 'Rituals', 'rituals.com', '#111111', true, true, false, array['rituals member']),
    (87, 'scapino', 'Scapino', 'scapino.nl', '#E30613', true, true, false, array['scapino club']),
    (88, 'shoeby', 'Shoeby', 'shoeby.nl', '#111111', true, true, false, array['shoeby member']),
    (89, 'sligro', 'Sligro', 'sligro.nl', '#0057A4', true, true, false, array['sligro klantenkaart']),
    (90, 'spar', 'SPAR', 'spar.nl', '#00843D', true, true, false, array['spar supermarkt']),
    (91, 'specsavers', 'Specsavers', 'specsavers.nl', '#009639', true, true, false, array['specsavers opticien']),
    (92, 'trekpleister', 'Trekpleister', 'trekpleister.nl', '#E30613', true, true, false, array['trekpleister voordeel']),
    (93, 'vanharen', 'vanHaren', 'vanharen.nl', '#0050AA', true, true, false, array['van haren']),
    (94, 'vomar', 'Vomar', 'vomar.nl', '#E30613', true, true, false, array['vomar voordeelmarkt']),
    (95, 'we-fashion', 'WE Fashion', 'wefashion.nl', '#111111', true, true, false, array['we', 'we fashion member']),
    (96, 'wehkamp', 'Wehkamp', 'wehkamp.nl', '#00A6A6', false, true, false, array['wehkamp cadeaukaart']),
    (97, 'welkoop', 'Welkoop', 'welkoop.nl', '#00843D', true, true, false, array['welkoop klantenkaart']),
    (98, 'wibra', 'Wibra', 'wibra.nl', '#E30613', true, true, false, array['wibra nederland']),
    (99, 'xenos', 'Xenos', 'xenos.nl', '#E5007D', true, true, false, array['xenos cadeaukaart']),
    (100, 'zeeman', 'Zeeman', 'zeeman.com', '#FFD100', true, true, false, array['zeeman klantenkaart'])
)
insert into public.brands (
  slug,
  name,
  logo_path,
  brand_color,
  supports_loyalty_card,
  supports_gift_card,
  is_featured,
  is_active,
  sort_order,
  aliases,
  recognition_keywords
)
select
  slug,
  name,
  format(
    'https://www.google.com/s2/favicons?domain_url=https://%s&sz=256',
    domain
  ),
  brand_color,
  supports_loyalty_card,
  supports_gift_card,
  is_featured,
  true,
  sort_order,
  aliases,
  array_append(aliases, lower(name))
from seed
on conflict (slug) do update set
  name = excluded.name,
  logo_path = coalesce(nullif(public.brands.logo_path, ''), excluded.logo_path),
  brand_color = excluded.brand_color,
  supports_loyalty_card = excluded.supports_loyalty_card,
  supports_gift_card = excluded.supports_gift_card,
  is_featured = excluded.is_featured,
  is_active = true,
  sort_order = excluded.sort_order,
  aliases = case
    when cardinality(public.brands.aliases) = 0 then excluded.aliases
    else public.brands.aliases
  end,
  recognition_keywords = case
    when cardinality(public.brands.recognition_keywords) = 0
      then excluded.recognition_keywords
    else public.brands.recognition_keywords
  end,
  updated_at = now();

-- Exactly ten entries should appear in the popular section.
update public.brands
set is_featured = false,
    updated_at = now()
where slug not in (
  'albert-heijn',
  'jumbo',
  'kruidvat',
  'hema',
  'lidl',
  'action',
  'plus',
  'gall-gall',
  'bol-com',
  'vvv-cadeaukaart'
)
and is_featured = true;

-- Merge the three legacy records that were created through the first admin
-- version. Their uploaded logo and carefully tuned layout are more valuable
-- than the generated defaults, so copy those settings before archiving them.
with legacy_map (legacy_slug, canonical_slug) as (
  values
    ('Bol-com', 'bol-com'),
    ('Jumbo', 'jumbo'),
    ('vvv', 'vvv-cadeaukaart')
)
update public.brands as target
set
  logo_path = source.logo_path,
  brand_color = source.brand_color,
  logo_home_scale = source.logo_home_scale,
  logo_home_x = source.logo_home_x,
  logo_home_y = source.logo_home_y,
  logo_loyalty_scale = source.logo_loyalty_scale,
  logo_loyalty_x = source.logo_loyalty_x,
  logo_loyalty_y = source.logo_loyalty_y,
  logo_gift_scale = source.logo_gift_scale,
  logo_gift_x = source.logo_gift_x,
  logo_gift_y = source.logo_gift_y,
  logo_detail_scale = source.logo_detail_scale,
  logo_detail_x = source.logo_detail_x,
  logo_detail_y = source.logo_detail_y,
  logo_picker_scale = source.logo_picker_scale,
  logo_picker_x = source.logo_picker_x,
  logo_picker_y = source.logo_picker_y,
  updated_at = now()
from public.brands as source
join legacy_map on source.slug = legacy_map.legacy_slug
where target.slug = legacy_map.canonical_slug;

update public.brands
set
  name = case when name like '% (oud)' then name else name || ' (oud)' end,
  is_active = false,
  is_featured = false,
  sort_order = 10000,
  updated_at = now()
where slug in ('Bol-com', 'Jumbo', 'vvv');
