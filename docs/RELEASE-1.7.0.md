# PasKluis 1.7.0

Op 4 oktober 2026 heeft de eigenaar opdracht gegeven voor definitieve builds, TestFlight, Google Play gesloten Alpha en officiële Apple-review.

## Inhoud

De vertrouwde toevoeg- en back-upflow blijft behouden. Beveiligingsverbeteringen, versleutelde afbeeldingen, privacyfiltering voor gebruikslocaties, robuustere gedeelde updates en gecorrigeerde privacy-/voorwaardenteksten zijn opgenomen. De Tegoedbewaker is verwijderd.

## Bron en controle

- Broncommit: d2597f39b914422cf4f878c1e747b2f98e9f58af.
- Versie: 1.7.0. Buildnummers worden uit de actuele storehistorie bepaald: iOS 139 (vorige 138), Android 100 (vorige 99).
- GitHub-validatie 37227505365: success. Buildworkflows voeren zelf ook analyse en Flutter-tests uit.
- iOS-build: https://codemagic.io/app/69f36f732d8b59f24897933a/build/6ac2a593424bd1c3fe82a96d
- Android-build: https://codemagic.io/app/69f36f732d8b59f24897933a/build/6ac2a594ea015d969853d44e

## Storevoorbereiding

Apple: naam, klantenservicegegevens en overige technische diagnostiek toegevoegd aan de gepubliceerde privacyverklaring; appfunctionaliteit, gekoppeld aan identiteit, geen tracking. Versie en reviewinstructies aangepast naar 1.7.0, verouderde verwijzingen naar batchimport, Tegoedbewaker en snelkoppelingen verwijderd. Drie iPhone-screenshots visueel gecontroleerd. Demo-QR-bijlage en bestaande reviewtoegang behouden. Handmatige vrijgave blijft geselecteerd.

Google Play: bestaande gegevenscategorieën en doelen gecontroleerd. Bij apparaat-ID's onjuiste advertentie-/marketingdoeleinden verwijderd en accountbeheer toegevoegd. De eigenaar gaf afzonderlijk toestemming om deze correctie voor Google-review in te dienen; verzonden en in voorbereidende controles.

De actuele uitvoeringsstatus wordt vastgelegd in release-170-build-state.json in de workspace-hoofdmap. Dit document op zichzelf bevestigt nog geen afgeronde upload of reviewinzending.

## Apple-resultaat

iOS 1.7.0 (139) is succesvol geüpload en verwerkt, gekoppeld aan Test Ro en Paskluis Testers. Externe TestFlight-status: Waiting for Review. Officiële App Store-review ingediend op 4 oktober 2026 om 21:32 Europe/Amsterdam; status Waiting for Review, submission 19d2c80b-2535-4526-95f3-271882fac0d0. Handmatige vrijgave blijft ingesteld.

## Android-resultaat

Android 1.7.0 (100), ondertekende AAB en APK, succesvol gebouwd. AAB geüpload naar alpha; API-readback bevestigt naam 1.7.0, versiecode 100 en trackstatus completed. AAB SHA-256: 10f3aa2c248096bdf079aa5e04f5de300f471ddf03012b549729e5b578738dad. Play Console toont 1.7.0 onder gesloten Alpha in de beoordelingswachtrij, samen met de privacycorrectie. Beheerd publiceren staat aan; daadwerkelijke beschikbaarheid voor testers vereist goedkeuring en vrijgave. De oudere 1.5.3 stond nog apart klaar voor publicatie en is niet gepubliceerd.

Deze status bevestigt builds, uploads en inzending, niet goedkeuring door Apple of Google. Er is geen publieke productierelease vrijgegeven.
