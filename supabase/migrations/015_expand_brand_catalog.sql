-- Expand the managed PasKluis catalogue from 100 to 150 active brands.
--
-- Idempotent: existing brand records, uploaded logos and logo positioning are
-- preserved. New records start with a recognisable domain icon until an admin
-- uploads a dedicated transparent wordmark through the brand manager.

with seed (
  sort_order,
  slug,
  name,
  domain,
  brand_color,
  supports_loyalty_card,
  supports_gift_card,
  aliases
) as (
  values
    (101, 'air-miles', 'Air Miles', 'airmiles.nl', '#005BAA', true, false, array['airmiles', 'air miles kaart']),
    (102, 'bouwmaat', 'Bouwmaat', 'bouwmaat.nl', '#E30613', true, false, array['bouwmaat pas', 'bouwmaat klantenkaart']),
    (103, 'makro', 'Makro', 'makro.nl', '#0050A4', true, true, array['makro pas', 'makro card']),
    (104, 'hanos', 'HANOS', 'hanos.nl', '#003B70', true, false, array['hanos pas', 'hanos klantenkaart']),
    (105, 'bidfood', 'Bidfood', 'bidfood.nl', '#E30613', true, false, array['bidfood pas', 'deli xl']),
    (106, 'toolstation', 'Toolstation', 'toolstation.nl', '#005EB8', true, false, array['tool station', 'toolstation account']),
    (107, 'pontmeyer', 'PontMeyer', 'pontmeyer.nl', '#005A9C', true, false, array['pont meyer', 'pontmeyer pas']),
    (108, 'jongeneel', 'Jongeneel', 'jongeneel.nl', '#E30613', true, false, array['jongeneel pas', 'jongeneel klantenkaart']),
    (109, 'bouwcenter', 'Bouwcenter', 'bouwcenter.nl', '#F58220', true, false, array['bouw center', 'bouwcenter pas']),
    (110, 'hubo', 'Hubo', 'hubo.nl', '#E30613', true, true, array['hubo klantenkaart', 'hubo cadeaukaart']),

    (111, 'shell', 'Shell', 'shell.nl', '#FFD500', true, true, array['shell go plus', 'shell kaart', 'shell card']),
    (112, 'bp', 'bp', 'bp.com', '#009900', true, false, array['bp kaart', 'bpme']),
    (113, 'esso', 'Esso', 'esso.nl', '#E30613', true, false, array['esso extras', 'esso kaart']),
    (114, 'totalenergies', 'TotalEnergies', 'totalenergies.nl', '#E30613', true, false, array['total energies', 'total club']),
    (115, 'tango', 'Tango', 'tango.nl', '#F58220', true, false, array['tango tanken', 'tango kaart']),
    (116, 'tinq', 'TinQ', 'tinq.nl', '#E30613', true, false, array['tinq tanken', 'tin q']),
    (117, 'q8', 'Q8', 'q8.nl', '#0050A4', true, false, array['q8 smiles', 'q8 kaart']),
    (118, 'ok-tankstations', 'OK', 'ok.nl', '#E30613', true, false, array['ok tankstations', 'ok app']),
    (119, 'texaco', 'Texaco', 'texaco.nl', '#E30613', true, false, array['texaco stars', 'texaco kaart']),

    (120, 'boni', 'Boni', 'boni.nl', '#E30613', true, true, array['boni supermarkt', 'boni klantenkaart']),
    (121, 'nettorama', 'Nettorama', 'nettorama.nl', '#005BAA', true, false, array['netto rama', 'nettorama supermarkt']),
    (122, 'poiesz', 'Poiesz', 'poiesz-supermarkten.nl', '#E30613', true, true, array['poiesz supermarkt', 'poiesz voordeelpas']),
    (123, 'boons-markt', 'Boon''s Markt', 'boonsmarkt.nl', '#009640', true, true, array['boons markt', 'boon supermarkt']),
    (124, 'mcd-supermarkt', 'MCD Supermarkt', 'mcd-supermarkt.nl', '#E30613', true, true, array['mcd', 'mcd supermarkt']),
    (125, 'odin', 'Odin', 'odin.nl', '#6F8F2F', true, true, array['odin foodcoop', 'odin winkel']),
    (126, 'amazing-oriental', 'Amazing Oriental', 'amazingoriental.com', '#E30613', true, true, array['oriental', 'amazing oriental supermarkt']),

    (127, 'starbucks', 'Starbucks', 'starbucks.nl', '#00754A', true, true, array['starbucks rewards', 'starbucks card']),
    (128, 'kfc', 'KFC', 'kfc.nl', '#E4002B', true, true, array['kentucky fried chicken', 'kfc app']),
    (129, 'subway', 'Subway', 'subway.com', '#008C15', true, true, array['subcard', 'subway rewards']),
    (130, 'new-york-pizza', 'New York Pizza', 'newyorkpizza.nl', '#E30613', true, true, array['nyp', 'new york pizza cadeaukaart']),
    (131, 'febo', 'FEBO', 'febo.nl', '#E30613', false, true, array['febo cadeaukaart', 'febo automatiek']),
    (132, 'dunkin', 'Dunkin''', 'dunkin.nl', '#FF671F', true, true, array['dunkin donuts', 'dunkin card']),
    (133, 'bagels-beans', 'Bagels & Beans', 'bagelsbeans.nl', '#6B3F2A', true, true, array['bagels and beans', 'bagels beans cadeaukaart']),

    (134, 'ranzijn', 'Ranzijn', 'ranzijn.nl', '#65A30D', true, true, array['ranzijn tuin dier', 'ranzijn klantenkaart']),
    (135, 'groenrijk', 'GroenRijk', 'groenrijk.nl', '#00843D', true, true, array['groen rijk', 'groenrijk klantenkaart']),
    (136, 'tuinland', 'Tuinland', 'tuinland.nl', '#2E7D32', true, true, array['tuinland klantenkaart', 'tuinland cadeaukaart']),
    (137, 'profijt-meubel', 'Profijt Meubel', 'profijtmeubel.nl', '#E30613', true, true, array['profijt meubel cadeaukaart', 'profijt']),
    (138, 'woonexpress', 'Woonexpress', 'woonexpress.nl', '#E50046', true, true, array['woon express', 'woonexpress voordeel']),
    (139, 'babypark', 'Babypark', 'babypark.nl', '#7A4B9D', true, true, array['baby park', 'babypark cadeaukaart']),

    (140, 'expert', 'Expert', 'expert.nl', '#E30613', true, true, array['expert winkels', 'expert cadeaukaart']),
    (141, 'ep', 'EP:', 'ep.nl', '#E30613', false, true, array['electronic partner', 'ep elektronica']),
    (142, 'kamera-express', 'Kamera Express', 'kamera-express.nl', '#E30613', true, true, array['camera express', 'kamera express cadeaukaart']),
    (143, 'alternate', 'Alternate', 'alternate.nl', '#E30613', false, true, array['alternate computer', 'alternate cadeaukaart']),
    (144, 'azerty', 'Azerty', 'azerty.nl', '#F58220', false, true, array['azerty computer', 'azerty cadeaukaart']),

    (145, 'zalando', 'Zalando', 'zalando.nl', '#FF6900', true, true, array['zalando plus', 'zalando cadeaukaart']),
    (146, 'sacha', 'Sacha', 'sacha.nl', '#111111', true, true, array['sacha shoes', 'sacha cadeaukaart']),
    (147, 'manfield', 'Manfield', 'manfield.com', '#111111', true, true, array['manfield schoenen', 'manfield member']),
    (148, 'ms-mode', 'MS Mode', 'msmode.nl', '#111111', true, true, array['msmode', 'ms mode member']),
    (149, 'intersport', 'INTERSPORT', 'intersport.nl', '#0055A5', true, true, array['inter sport', 'intersport club']),
    (150, 'sport-2000', 'SPORT 2000', 'sport2000.nl', '#E30613', true, true, array['sport2000', 'sport 2000 cadeaukaart'])
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
  false,
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

