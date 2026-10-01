# Instellingen live ondersteunen via een tijdelijke code

Na activeren van de tijdelijke code toont het beheer de zichtbare instellingenrubrieken van de betreffende appinstallatie, met dezelfde volgorde, aangepaste titels en huidige waarden. De app stuurt alleen de expliciet toegestane instellingen en menuteksten. Kaartinhoud, codes, afbeeldingen, betaalgegevens en locatie blijven uitgesloten.

De medewerker kan taal, leesbaarheid, kaartvolgorde, starttab, favorieten, locatiekaartvoorkeuren/afstand, helderheid, scherm actief houden, pincodes verbergen en herinneringsvoorkeur wijzigen. De app past deze lokaal toe en bevestigt daarna de revisie. Tot die bevestiging toont het beheer een wachtstatus en blokkeert het een volgende wijziging. Beide kanten verversen iedere drie seconden tijdens gebruik. Op de achtergrond of offline volgt verwerking bij terugkeer, uitsluitend zolang de sessie geldig is.

Appvergrendeling, telefoontoestemmingen, accountacties, aankopen en back-up/herstelacties worden op het toestel bediend. Support kan geen biometrie of telefoontoestemming omzeilen en start geen herstel op afstand.

De code heeft een kopieerknop met bevestiging. Intrekken blijft zichtbaar wanneer de code na tien minuten verlopen is, ook als support al verbonden is. Een mislukte intrekking wordt gemeld en wist de zichtbare sessie niet.

## Databasecontract

Migratie: `supabase/migrations/20261001133636_live_support_settings.sql`.

- Support blijft gebonden aan de gebruiker én de authsessie van de installatie die de code maakte.
- Alleen de activerende medewerker met de bestaande MFA-beschermde `is_staff()`-controle kan de sessie bekijken/wijzigen.
- Instellingnamen, typen en mogelijke waarden worden op de server gecontroleerd.
- Optimistische revisies voorkomen overlappende wijzigingen. Een bevestiging volgt pas na toepassen op het toestel.
- Verlopen, ingetrokken of vervangen sessies kunnen geen nieuwe wijzigingen ontvangen. Een verlopen sessie levert de app geen wachtende opdracht meer op.
- Bestaande oudere apps kunnen diagnostiek blijven delen. Live bewerken vraagt de nieuwe app en een nieuwe code.
- Tabellen blijven afgeschermd; nieuwe functies zijn uitsluitend voor authenticated beschikbaar en controleren ook eigenaarschap/medewerker.

## Verificatie en uitrol

`node --test admin/tests/*_test.mjs supabase/tests/*_test.mjs` voert de beheerregressies en een lokale PostgreSQL-proef met PGlite uit. De lokale proef controleert whitelist/gegevensgrens, waardetypen, installatiebinding, medewerkersisolatie, revisieconflicten, bevestiging, intrekking, verlopen toegang en afwijzen van niet-medewerkers. Auth/MFA en digest zijn in deze lokale proef stubs; productie-MFA en echte apparaten moeten na de migratie apart worden geverifieerd.

Op 1 oktober 2026 heeft Ronald expliciet toestemming gegeven voor de volledige uitrol. Beide migraties zijn eerst toegepast in PasKluis Security Test (`ejfktacouxvtapkunmdv`) en daarna in productie (`ajldblvvlbvmgejrmhyj`). De aanvullende migratie `20261001141051_support_session_execute_permissions.sql` verwijdert de bestaande anonieme EXECUTE-grants op de oudere supportfuncties.

`supabase/tests/live_support_settings_security.sql` is in het geïsoleerde testproject uitgevoerd met echte authsessies, geverifieerde MFA-factoren en de bestaande apparaatcontrole. Alle controles op eigenaarschap, MFA, gegevensfiltering, typen, medewerkersisolatie, revisies, bevestiging en intrekking zijn geslaagd. De proef draait binnen een transactie die alle proefgebruikers en sessies terugdraait. Productiegrants zijn daarna afzonderlijk gecontroleerd: alle zes support-RPCs zijn uitsluitend voor authenticated uitvoerbaar.

GitHub-validatie van de appwijzigingen is geslaagd: 91 Flutter-tests en 53 Node/beheer/PostgreSQL-controles. PR #5 is samengevoegd in de releasebranch; de uiteindelijke mergevalidatie is ook geslaagd. Het vernieuwde beheer is op GitHub Pages gepubliceerd en de inhoud van het live app.js-bestand is gecontroleerd. iOS-build `6abe6b79c6faa033af52c8e7` en Android-build `6abe6b77eb7066dd56390b11` zijn in Codemagic gestart; voltooide builds/storeverwerking zijn nog niet bevestigd.

De Strato-VPS serveert nog het oude beheer. SSH is vanuit deze omgeving niet bereikbaar en de VNC-console is afgeschermd door native credentialbescherming van de browser. `deploy/update-admin-live-support.sh` publiceert uitsluitend de vier gewijzigde beheerbestanden, met SHA-256-controle, bestanden per stuk atomair vervangen en een voorafgaande herstelkopie. Het script vraagt een volledige releasecommit als argument en verandert geen homepage of nginx-configuratie. Kopiëren en een zichtbare wijziging moeten vervolgens op echte toestellen worden gecontroleerd; de SQL-proef verifieert het contract, niet de mobiele UI of OS-klembordfunctie.

De homepage van Jordi is niet gewijzigd.
