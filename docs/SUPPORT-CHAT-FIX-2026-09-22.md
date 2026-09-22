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
- Flutter-analyse en alle 30 appregressietests geslaagd, waaronder 7 nieuwe supporttests. De eerste run ontdekte een onjuiste lifecycle-simulatie in de test; na correctie slaagt de volledige suite. [Verificatie](https://github.com/RonaldB03/paskluis/actions/runs/35744752065).
- Database-regressie toegevoegd: gasttoken, eigenaar/ander account, vervangen sessie, onmogelijke afzendervervalsing, bewaarde medewerkersnaam en geen antwoordmail. Nog niet live uitgevoerd.
- Beheer gepubliceerd op commit `7893b29`; [publicatieworkflow geslaagd](https://github.com/RonaldB03/paskluis/actions/runs/35744389547).
- Appcode + gecorrigeerde tests staan op `7337179`. GitHub heeft nieuwe Codemagic-kandidaten gestart: [iOS](https://codemagic.io/app/69f36f732d8b59f24897933a/build/6ab298fb08d49cdfa6141caf) en [Android](https://codemagic.io/app/69f36f732d8b59f24897933a/build/6ab298fb63b018b798b210ae). Het starten is bevestigd; voltooiing en verspreiding naar TestFlight/Play zijn nog niet gecontroleerd.
- De browserverbinding voor Supabase/Codemagic reageert niet. Migratie 029 en de nieuwe Edge-worker zijn nog NIET live toegepast. Klantantwoordmails zijn live dus nog niet gegarandeerd uitgeschakeld. Een beschikbare rechtstreekse Supabase-plugin is voorgesteld, maar nog niet verbonden; na verbinding eerst de SQL-proef uitvoeren en daarna toepassen/deployen.
- Begin bij hervatten met migratie 029 + rollback-test; controleer daarna de echte push en het openen van het antwoord op beide telefoons. Geen nieuwe SMTP-inlog nodig.
