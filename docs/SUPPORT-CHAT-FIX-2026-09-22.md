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
- Database-regressie live geslaagd: gasttoken, eigenaar/ander account, vervangen sessie, onmogelijke afzendervervalsing, bewaarde medewerkersnaam en geen antwoordmail. Migratie 029 is op 22 september toegepast als `20260922151424_support_conversation_delivery`. Regressietests draaiden binnen dezelfde transactie met een savepoint; alle tijdelijke gebruikers, berichten en outbox-items zijn teruggedraaid (0 testidentiteiten over).
- Beheer gepubliceerd op commit `7893b29`; [publicatieworkflow geslaagd](https://github.com/RonaldB03/paskluis/actions/runs/35744389547).
- Appcode + gecorrigeerde tests staan op `7337179`. GitHub heeft nieuwe Codemagic-kandidaten gestart: [iOS](https://codemagic.io/app/69f36f732d8b59f24897933a/build/6ab298fb08d49cdfa6141caf) en [Android](https://codemagic.io/app/69f36f732d8b59f24897933a/build/6ab298fb63b018b798b210ae). Het starten is bevestigd; voltooiing en verspreiding naar TestFlight/Play zijn nog niet gecontroleerd.
- Na koppeling van Supabase is de backend live bijgewerkt. `dispatch-notifications` versie 8 is actief; de opgehaalde live bron komt exact overeen met de geteste bron. Bestaande secrets en JWT-instelling zijn behouden. De cronworker is actief. Er staan 0 klantantwoordmails klaar voor verzending.
- De oorspronkelijke testvraag bleek als medewerkersbericht te zijn opgeslagen, doordat de eigenaar zelf beheerrechten heeft. Dat veroorzaakte direct een onterechte antwoordmelding en onderdrukte de automatische ontvangstbevestiging. Migratie 029 herstelt uitsluitend zulke eerste eigen berichten, met behoud van tekst en tijdstip; de eerste echte reactie blijft een medewerkersantwoord. Er wordt geen ontvangstbevestiging of push achteraf verstuurd.
- Het bestaande gesprek is nu correct: klantvraag om 14:30 UTC, echt medewerkersantwoord om 14:33 UTC met opgeslagen afzendernaam.
- Interne distributie volgt nu de geslaagde backend- en appcontroles. Controleer na installatie nog een echte push en het openen van het antwoord op beide telefoons, als gast en als ingelogde gebruiker. Geen nieuwe SMTP-inlog nodig.

## Interne testuitrol na backendcorrectie

- De nieuwe Edge-worker is ook via dezelfde serverauthenticatie aangeroepen met een lege wachtrij: HTTP 200, `processed: 0`, `completed: 0`. Geen testpush of testmail verzonden.
- Geïsoleerde releasebranch: `codex/support-chat-internal-test`, commit `4b5d45c`. Deze bevat dezelfde geteste appcode plus de live toegepaste datacorrectie.
- [Interne releaseworkflow](https://github.com/RonaldB03/paskluis/actions/runs/35747091683) controleert per platform eerst de geslaagde kandidaat en start vervolgens de bestaande `ios-release` / `android-test` workflows. Alleen TestFlight/App Store Connect en Google Play internal; geen openbare lancering.
- De normale appbranch blijft kandidaten bouwen zonder publicatie. De releaseworkflow gebruikt het bestaande Codemagic-secret zonder dit uit te lezen of te loggen en volgt beide resultaten.
- Status bij start: interne uitrol loopt. Noteer het definitieve resultaat en de buildlinks na voltooiing.
