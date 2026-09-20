# PasKluis Beheer uitrollen

1. Voer de nog niet toegepaste migraties in volgorde uit in de Supabase SQL
   Editor. Voor de volledige winkelcatalogus is dit in ieder geval:

   - `supabase/migrations/006_admin_control_center.sql`
   - `supabase/migrations/007_seed_full_brand_catalog.sql`

   Migratie `007` is veilig opnieuw uit te voeren. Bestaande geüploade logo's en
   handmatig ingestelde herkenningsregels worden daarbij behouden.
2. Deploy de medewerkersuitnodiging:

   ```bash
   supabase functions deploy invite-staff
   ```

   De functie gebruikt automatisch `SUPABASE_URL`, `SUPABASE_ANON_KEY` en
   `SUPABASE_SERVICE_ROLE_KEY` uit het gekoppelde Supabase-project.
3. Publiceer de map `admin/` op dezelfde manier als de bestaande beheeromgeving.

Zonder de Edge Function kan een beheerder nog steeds een bestaand PasKluis-account
promoveren. Voor een volledig nieuwe medewerker is de uitnodigingsfunctie nodig.

## Rollen

- `admin`: volledige toegang tot medewerkers, Plus, winkels, herkenning,
  app-instellingen, klantenservice en activiteitenlog.
- `support`: toegang tot overzicht, gebruikersinformatie en klantenservice.
- `user`: geen toegang tot het beheer.

De webbeheeromgeving beheert alleen het logo-bestand. Schaal en positie worden in
de mobiele app ingesteld, zodat het voorbeeld altijd overeenkomt met het echte scherm.
