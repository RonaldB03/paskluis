-- Central feature controls and privacy-safe defaults for PasKluis.
-- Personal choices remain on the user's device; this table only controls
-- availability, defaults and editable public copy.

alter table public.app_settings
  add column if not exists input_type text not null default 'auto',
  add column if not exists options jsonb not null default '[]'::jsonb,
  add column if not exists sort_order integer not null default 0,
  add column if not exists platform text not null default 'all',
  add column if not exists plus_only boolean not null default false,
  add column if not exists is_visible boolean not null default true;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'app_settings_input_type_check'
  ) then
    alter table public.app_settings
      add constraint app_settings_input_type_check
      check (input_type in ('auto', 'switch', 'number', 'text', 'textarea', 'select'));
  end if;
  if not exists (
    select 1 from pg_constraint
    where conname = 'app_settings_platform_check'
  ) then
    alter table public.app_settings
      add constraint app_settings_platform_check
      check (platform in ('all', 'ios', 'android'));
  end if;
end $$;

insert into public.app_settings (
  key, value, label, description, category, is_public,
  input_type, options, sort_order, platform, plus_only, is_visible
)
values
  ('feature_location_cards', 'true', 'Locatiegestuurde kaarten',
   'Gebruikers kunnen kaarten laten rangschikken op basis van een lokaal opgeslagen gebruikslocatie.',
   'features', true, 'switch', '[]', 10, 'all', false, true),
  ('feature_card_sharing', 'true', 'Kaarten delen',
   'Klantenkaarten en cadeaukaarten delen. De verzender heeft Plus nodig.',
   'features', true, 'switch', '[]', 20, 'all', true, true),
  ('feature_gift_expiry_notifications', 'true', 'Cadeaukaartherinneringen',
   'Gebruikers kunnen lokale meldingen voor vervaldatums ontvangen.',
   'features', true, 'switch', '[]', 30, 'all', false, true),

  ('default_location_cards_enabled', 'true', 'Locatiekaarten standaard aan',
   'Startwaarde voor nieuwe installaties. Een gebruiker kan dit zelf aanpassen.',
   'defaults', true, 'switch', '[]', 10, 'all', false, true),
  ('default_nearby_radius_meters', '250', 'Standaard winkelafstand',
   'Afstand waarbinnen een kaart als dichtbij wordt getoond.',
   'defaults', true, 'select',
   '[{"value":100,"label":"100 meter"},{"value":250,"label":"250 meter"},{"value":500,"label":"500 meter"},{"value":1000,"label":"1 kilometer"}]',
   20, 'all', false, true),
  ('default_favorites_first', 'true', 'Favorieten eerst',
   'Zet favoriete kaarten standaard vóór andere kaarten.',
   'defaults', true, 'switch', '[]', 30, 'all', false, true),
  ('default_show_favorites_section', 'true', 'Favorietenblok op Home',
   'Toon standaard een apart favorietenblok op het beginscherm.',
   'defaults', true, 'switch', '[]', 40, 'all', false, true),
  ('default_card_sort_order', '"recent"', 'Standaard sortering',
   'Volgorde voor gebruikers die nog geen eigen keuze hebben gemaakt.',
   'defaults', true, 'select',
   '[{"value":"recent","label":"Laatst gebruikt"},{"value":"added","label":"Laatst toegevoegd"},{"value":"alphabetical","label":"Alfabetisch"}]',
   50, 'all', false, true),
  ('default_start_tab', '"home"', 'Standaard startscherm',
   'Onderdeel dat nieuwe installaties als eerste openen.',
   'defaults', true, 'select',
   '[{"value":"home","label":"Home"},{"value":"cards","label":"Klantenkaarten"},{"value":"qr","label":"QR-codes"},{"value":"gift","label":"Cadeaukaarten"}]',
   55, 'all', false, true),
  ('default_auto_brightness', 'true', 'Helderheid automatisch verhogen',
   'Verhoog standaard de helderheid wanneer een kaart wordt geopend.',
   'defaults', true, 'switch', '[]', 60, 'all', false, true),
  ('default_keep_screen_awake', 'true', 'Scherm wakker houden',
   'Voorkom standaard dat het scherm uitgaat terwijl een kaart zichtbaar is.',
   'defaults', true, 'switch', '[]', 70, 'all', false, true),
  ('default_hide_sensitive_codes', 'true', 'Pincodes standaard verbergen',
   'Verberg pincodes en krascodes totdat de gebruiker ze bewust toont.',
   'defaults', true, 'switch', '[]', 80, 'all', false, true),
  ('default_gift_expiry_notifications', 'true', 'Vervaldatummeldingen standaard aan',
   'Startwaarde voor lokale cadeaukaartherinneringen.',
   'defaults', true, 'switch', '[]', 90, 'all', false, true),

  ('help_add_card_text',
   '"Tik op + om een klantenkaart, QR-code of cadeaukaart toe te voegen. Je kunt scannen, handmatig invoeren of een foto of screenshot importeren. Controleer altijd de winkel en code voordat je de kaart opslaat."',
   'Hulptekst kaarten toevoegen',
   'Tekst bij Hulp en uitleg in de instellingen van de app.',
   'content', true, 'textarea', '[]', 10, 'all', false, true),
  ('privacy_message',
   '"Je kaarten, codes en pincodes blijven lokaal op dit apparaat. PasKluis bewaart geen precieze locatie of locatiegeschiedenis in het beheer. Alleen accountgegevens, Plus-status en gedeelde kaarten worden online verwerkt wanneer je die functies gebruikt."',
   'Privacytekst in de app',
   'Korte, begrijpelijke uitleg voor gebruikers.',
   'content', true, 'textarea', '[]', 20, 'all', false, true)
on conflict (key) do update
set label = excluded.label,
    description = excluded.description,
    category = excluded.category,
    is_public = excluded.is_public,
    input_type = excluded.input_type,
    options = excluded.options,
    sort_order = excluded.sort_order,
    platform = excluded.platform,
    plus_only = excluded.plus_only,
    is_visible = excluded.is_visible;

update public.app_settings
set input_type = 'number', sort_order = 10
where key = 'free_gift_card_limit';

update public.app_settings
set input_type = 'text', sort_order = 20
where key = 'lifetime_price_label';

update public.app_settings
set input_type = 'switch', sort_order = 10
where key = 'maintenance_enabled';

update public.app_settings
set input_type = 'textarea', sort_order = 20
where key = 'maintenance_message';

update public.app_settings
set input_type = 'text', sort_order = 10, platform = 'ios'
where key = 'minimum_ios_version';

update public.app_settings
set input_type = 'text', sort_order = 20, platform = 'android'
where key = 'minimum_android_version';

update public.app_settings
set is_visible = false
where key = 'nearby_radius_km';
