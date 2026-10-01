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

De live database is nog niet gewijzigd. Automatische goedkeuringscontrole wees het toepassen van de migratie in het remote testproject af: zij vereist expliciete toestemming voor de database en de gewijzigde supportrechten. De testbasis met de bestaande supportfuncties is daarvoor al in PasKluis Security Test aangelegd; de nieuwe functies zijn daar niet toegepast.

Na expliciete toestemming: voer de migratie eerst in PasKluis Security Test (`ejfktacouxvtapkunmdv`) uit, verifieer met de echte bestaande MFA/device-session-functies en security advisors, en voer vervolgens in het productieproject (`ajldblvvlbvmgejrmhyj`) uit. Publiceer daarna de beheerbestanden en start de iOS-/Android-builds vanaf de bijgewerkte releasebranch. Verifieer kopiëren, een zichtbare wijziging op beide toestellen, intrekken en offline/hervatten met onbruikbare testkaarten. Verifieer de actuele versie/buildnummers via Codemagic voordat de store-release wordt gestart.

De homepage van Jordi is niet gewijzigd.
