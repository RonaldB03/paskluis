# Supportgesprekken — correctie 22 september 2026

## Gewenst gedrag

- Klantberichten rechts, PasKluis-antwoorden links met de naam van de medewerker.
- Automatische ontvangstbevestiging apart herkenbaar; chronologische volgorde, nieuwste antwoord onderaan.
- Berichten verschijnen onafhankelijk van het laden van screenshotbijlagen.
- Een binnenkomende supportpush en terugkeren naar de app verversen het juiste gesprek.
- Een oudere aanvraag kan een nieuw antwoord niet overschrijven. Bij fouten blijft een duidelijke vernieuwactie zichtbaar.
- Geen antwoordmails naar klanten. Push blijft beschikbaar, de medewerkersmail voor nieuwe klantvragen blijft bestaan. Aanmeld- en herstelmails veranderen niet.
- Een beheerder die in de eigen app een klantvraag stelt, blijft in dat gesprek klant. Afzendernaam en rol worden serverzijdig bepaald.

## Uitrol

1. Voer migratie 029 en `supabase/tests/support_conversation_security.sql` samen uit in een rollback-proef. De proef mag geen blijvende testaccounts, mails of pushes opleveren.
2. Pas migratie 029 toe. Het outbox-trigger schakelt antwoordmails ook voor de bestaande worker uit; nog niet verzonden antwoordmails worden overgeslagen.
3. Publiceer `dispatch-notifications` met de bestaande secrets en bestaande JWT-instelling; controleer push-only klantantwoorden en medewerkersmail. Geen wachtwoorden opnieuw invoeren of uitlezen.
4. Publiceer de bijgewerkte beheersbestanden inclusief `support-conversation.js`. De workflow op de beheerbranch publiceert `admin/`; werk deze map bij, niet alleen bestanden in de repository-root.
5. Voer Flutter-analyse en regressietests uit, bouw daarna interne iOS/Android-tests. Geen openbare lancering.
6. Test als gast en ingelogde klant: een vraag, één automatische ontvangstbevestiging, een persoonlijk/canned antwoord van een benoemde medewerker, push openen, verversen, app hervatten en screenshotbijlage. Controleer dat geen klantmail wordt verstuurd.

## Verificatie tijdens implementatie

- 19 Node-tests geslaagd: notificaties/SMTP-herhaling, storecontrole en beheerchat (volgorde, rol, naam en HTML-escaping).
- JavaScript syntaxcontroles en gelijke NL/EN-vertaalsleutels geslaagd.
- 7 Flutter-regressietests toegevoegd, nog uit te voeren in de buildomgeving.
- Database-regressie toegevoegd: gasttoken, eigenaar/ander account, vervangen sessie, onmogelijke afzendervervalsing, bewaarde medewerkersnaam en geen antwoordmail. Nog niet live uitgevoerd.
- De browserverbinding voor Supabase/Codemagic reageerde niet tijdens deze correctie. Database-/Edge-publicatie en nieuwe distributie zijn daarom nog niet bevestigd. Broncode opslaan is geen bewijs dat de wijziging al op telefoons staat.
