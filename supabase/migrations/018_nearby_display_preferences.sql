-- Independent defaults for Home visibility and loyalty-card distance ordering.
-- Stored user choices always take precedence; these controls are public defaults.
insert into public.app_settings (
  key, value, label, description, category, is_public,
  input_type, options, sort_order, platform, plus_only, is_visible
) values
  ('default_show_nearby_section', 'true', 'In de buurt op Home',
   'Toon het blok In de buurt standaard op Home. Staat los van de sortering van klantenkaarten.',
   'defaults', true, 'switch', '[]', 45, 'all', false, true),
  ('default_nearby_loyalty_cards_first', 'false', 'Dichtstbijzijnde klantenkaarten bovenaan',
   'Geef klantenkaarten binnen de gekozen winkelafstand voorrang op favorieten en normale sortering. Vereist locatiegebruik.',
   'defaults', true, 'switch', '[]', 25, 'all', false, true)
on conflict (key) do nothing;
