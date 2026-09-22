# PasKluis 1.5.0 — overdracht voor live testen

Status 22 september 2026: appkandidaten voor iOS en Android geslaagd. Vernieuwd beheer, database en serverfuncties zijn gepubliceerd. Nog geen vrijgave voor de officiële externe test of openbare lancering: SMTP, storekoppelingen, privacygegevens en toesteltests moeten worden afgerond.

## In deze update

- Ontvangen kaarten horen lokaal bij de ontvanger. Uitloggen/accountwissel wist ontvangen kaarten en herinneringen; eigen kaarten blijven bestaan.
- Actieve sessie ook in databasebeleid en deel-RPC's afgedwongen. Een overgenomen oude sessie krijgt geen nieuwe toegang.
- Interne supportnotities naar een aparte, afgeschermde tabel.
- Automatische ontvangstbevestiging per nieuw gesprek, in NL/EN; doeltermijn 12 uur begint bij de eerste onbeantwoorde klantreactie. Een automatisch bericht telt niet als persoonlijk antwoord.
- Supportcategorieën, minimale appcontext, gastgesprekken ook na inloggen, medewerkers toewijzen, standaardantwoorden, zoekfilters, achterstallige gesprekken en bekende storingen. Screenshotbijlagen met een voorbeeld vóór verzenden en privéopslag; tijdelijke links voor bevoegde lezers.
- Databasewachtrij voor deel- en supportmeldingen, aparte push- en mailstatus, herhaalpogingen, generieke melding zonder kaartcode/PIN/gesprekstekst. Worker en automatische herhaalpogingen zijn actief. De aparte support-SMTP moet nog worden geconfigureerd en echte push-/mailbezorging moet nog worden getest.
- Native aankoop-/herstelcode en serververificatie voor het eenmalige product `paskluis_plus`; verkoop staat standaard uit. Toegang wordt uit alle geverifieerde aankopen afgeleid, zodat terugbetalingen op twee platforms geen oude Plus-toegang achterlaten. Een aparte servercontrole verwerkt Apple-terugbetalingen en Google-voided purchases. Die is gepubliceerd maar blijft uit totdat de storesleutels zijn ingesteld en de keten getest is.
- Account verwijderen via app en voorbereide openbare webpagina. Extra wachtwoordcontrole, geen verwijdering van medewerkersaccounts zonder eerst hun rol te wijzigen.
- Beheerde winkelherkenning, unieke barcodeprefixen, geen willekeurige gok bij meerdere matches.
- Eerlijke uitleg van locatieverwerking en lokale opslag. GPS-metingen ouder dan twee minuten of met meer dan 100 m onnauwkeurigheid worden niet als actuele afstand gebruikt.
- Atomair Places-budget, meerdere filiaalresultaten per cachegebied; dichtstbijzijnde opnieuw berekend bij veranderde locatie.
- Appvergrendeling en privacyscherm om de volledige Navigator.
- Onderhoudsmelding en updateadvies op Home; beheerbare Engelse hulp-/privacytekst.
- Analyzerfouten blokkeren nu de build. Extra regressietests en onafhankelijke validatieworkflow.

## Wat werkelijk gecontroleerd is

- Beide definitieve appkandidaten op `f6ee355` geslaagd: [iOS Candidate Build #1](https://codemagic.io/app/69f36f732d8b59f24897933a/build/6ab26e8f9dae708f39d82606) en [Android Candidate Build #1](https://codemagic.io/app/69f36f732d8b59f24897933a/build/6ab26e90952c592617281d6d). Flutteranalyse en alle 23 Fluttertests geslaagd. Latere commits wijzigen alleen beheer, backend, tests en documentatie.
- Elf tests van de echte serverhandlers met gesimuleerde aanbieders geslaagd: onafhankelijke push/mailkanalen, herhaalpogingen, ingetrokken deelrechten, geverifieerde terugbetalingen, paginering, accountcontrole en storingsgedrag. Dit bewijst geen echte mailbox-, push- of storebezorging.
- Dart-syntaxis en 692 NL/EN-berichten gecontroleerd; JavaScript en Edge-bronnen zonder syntaxisfouten.
- Alle migraties 020–026 met SQL-regressies in een rollback-transactie beproefd, daarna atomair gepubliceerd. Sessieovername, oude sessie geweigerd, interne notities onleesbaar voor klanten, één automatische ontvangstbevestiging en een niet-herstartende antwoordtermijn: geslaagd. Twee storeaankopen achtereen terugbetalen laat geen oude Plus-toegang achter; onafhankelijke medewerkerstoegang blijft behouden.
- Migratie 027 en de aanvullende planning eerst in een rollback-transactie gecontroleerd, daarna gepubliceerd. Alleen de server kan storecontrolewerk claimen en twee gelijktijdige workers kunnen hetzelfde werk niet claimen.
- Gepubliceerd: dispatch-notifications, support-attachments, delete-account, verify-purchase, reconcile-purchases en updates aan send-shared-card-notification en nearest-brand-stores. Drie onderhouds-/meldingsjobs actief. De vierde job voor storecontrole is voorbereid maar wordt door een uitgeschakelde instelling tegengehouden.
- Live smokecontrole: meldingsworker antwoordt HTTP 200 met lege wachtrij; onbevoegde account-/aankoop-/deelverzoeken worden geweigerd. De locatiefunctie accepteert de publieke app-sleutel en valideert de invoer. Geen echte klantberichten verstuurd tijdens deze controles.
- Vernieuwd beheer online; publieke [hulppagina](https://ronaldb03.github.io/paskluis/support.html) en [verwijderpagina](https://ronaldb03.github.io/paskluis/delete-account.html) laden correct. Ingelogd beheer is nog niet visueel end-to-end getest.
- Tussenversie `e166ae4` is eerder verspreid (iOS #64 / Android #62). De definitieve kandidaat is nog niet via de stores verspreid; de vrijgavestatus wordt hieronder bijgehouden.
- Camera, biometrie, betalingen, mailboxbezorging, screenshots en push op twee echte telefoons zijn nog niet end-to-end getest.

## Wat nog nodig is voor vrijgave

1. **Supportmail:** configureer in Supabase Edge Secrets `SUPPORT_SMTP_JSON` met `{host,port,user,password,from}` voor PasKluis. De bestaande Auth-SMTP is geen automatisch gedeelde Edge-secret. Standaard ontvangt `info@paskluis.nl` medewerkersmeldingen; `SUPPORT_INBOX_EMAIL` kan dit wijzigen. Voer wachtwoorden en sleutels uitsluitend in de beveiligde beheeromgeving in.
2. **Storeaankopen:** configureer `APPLE_IAP_KEY_JSON` (`{privateKey,keyId,issuerId}`) en `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` met de benodigde PasKluis-rechten. Richt in beide stores het eenmalige, niet-verbruikbare product `paskluis_plus` in op € 1,99. `ALLOW_SANDBOX_PURCHASES=true` alleen bewust voor storetesters. `store_purchase_enabled` blijft uit totdat kopen, annuleren, herstellen en accountbinding zijn gecontroleerd.
3. **Terugbetalingen:** `reconcile-purchases` gebruikt dezelfde bestaande workersecret. Apple-productieaankopen worden dagelijks gecontroleerd in kleine batches; Google wordt elke zes uur gepagineerd over zijn beschikbare 30-dagenvenster gecontroleerd. Alleen een geverifieerde terugbetaling wijzigt toegang; providerfouten behouden bestaande toegang. Controleer `purchase_reconciliation_state.last_success_at/last_error` en backlog. Activeer `store_reconciliation_enabled` pas na echte storeproeven. Een storing langer dan Googles 30-dagenvenster vereist handmatig onderzoek; Apple-sandboxtests gebruiken de aankoop-/herstelverificatie.
4. **Privacy en storegegevens:** bevestig juridische exploitant/contactgegevens, bewaartermijnen, doelgroepen/regio’s en classificatie. `admin/privacy.html` is een concept en is bewust nog niet gepubliceerd. Vul daarna App Privacy / Data Safety en de openbare privacy-URL in.
5. **Toesteltests:** voer onderstaande checklist uit op iPhone en Android, als gast en met twee aparte accounts. Supportbijlagen zijn privé en kort geldig, maximaal 5 MB en 6 per gesprek per dag; toegang door een ander account en verwijderen moeten expliciet meegetest worden.
6. **Gastgesprek herstellen:** bij verlies van de lokale toegangssleutel ontbreekt nog zelfstandig herstel via e-mail. Voor de eerste test blijft contact via `info@paskluis.nl` de uitwijkmogelijkheid. Rechtstreeks per e-mail antwoorden met automatische terugkoppeling naar het appgesprek is bewust uitgesteld.
7. **Externe testers:** pas na aftekenen van de blokkades de officiële test openen. Interne TestFlight-/Playdistributie is geen openbare lancering. Geen testeruitnodigingen zonder concrete lijst en akkoord.

## Uitrol en herstel

De actieve Supabase-projectkoppeling is `ajldblvvlbvmgejrmhyj`. De uitgevoerde bestanden staan in `supabase/migrations/020*` t/m `027*`; bestaande bestanden niet opnieuw blind uitvoeren. Operaties: `enable_notification_worker.sql` en `enable_purchase_reconciliation.sql`. Workersecret staat zowel in Edge Secrets als in Vault onder `paskluis_notification_worker_secret`; de waarde staat nergens in Git. Firebase/Places-instellingen zijn behouden.

Bij problemen: zet nieuwe storefuncties uit via de twee instellingen; pauzeer uitsluitend de bijbehorende cronjob. Migreer gegevens niet terug door tabellen te verwijderen. Migratie 020 verplaatste interne notities naar een aparte tabel: herstel niet alleen het oude beheer zonder passend databaseschema. Bewaar gebruikers, rollen, kaarten, logo’s en supportgegevens. Gebruik een gerichte voorwaartse herstelmigratie.

## Toesteltest (beide platforms, NL en EN)

| Test | Verwacht | Resultaat |
|---|---|---|
| Bijwerken, vliegtuigstand, herstart | Eigen kaarten blijven beschikbaar | Nog testen |
| Registratie en wachtwoord vergeten | Juiste mail, juiste appflow, Nederlands/Engels | Nog testen |
| Account A → B, uitloggen, tweede toestel | Ontvangen kaarten/PIN's en meldingen van A verdwijnen; eigen kaarten blijven | Nog testen |
| QR-scan en foto met uitsluitend streepjescode | Geen omzetting naar QR | Nog testen |
| Klantenkaartimport, onbekende of dubbelzinnige winkel | Juiste match of handmatige winkelkeuze | Nog testen |
| Delen Plus → gratis / Plus → Plus | Alleen kijken / samen bewerken; wijzigingsconflict afgehandeld | Nog testen |
| Deelpush voorgrond/achtergrond/afgesloten | Eén bruikbare melding, geen geheime code op vergrendelscherm | Nog testen |
| Vervaldatum en verwijderen/intrekken | Juiste lokale herinnering, oude herinnering geannuleerd | Nog testen |
| Support gast/gebruiker/na login | Één ontvangstbevestiging, gesprek vindbaar, eigen rechten | Nog testen |
| Support antwoord, mail, push, storingen | Correct gesprek opent; geen interne notities in klantdata | Nog testen |
| Screenshotbijlage, ander account/gasttoken, verwijderen | Alleen bevoegde lezer krijgt tijdelijke link; bestand wordt mee verwijderd | Nog testen |
| Appslot op kaart-/gespreksscherm | Geen omzeiling via navigatie of melding | Nog testen |
| Plus kopen/annuleren/herstellen/verkeerd account | Alleen geverifieerde aankoop geeft toegang | Nog testen |
| Terugbetaling | Plus op server ingetrokken zonder afhankelijkheid van appherstel | Code/isolatietests geslaagd; storeproef nog nodig |
| Account verwijderen app en web | Werkelijk verwijderd; ontvangen toegang vervalt; lokale keuze klopt | Nog testen |
| Locatie, meerdere filialen, geen toestemming | Plausibele hemelsbrede afstanden; geen cadeaukaarten in de buurt | Nog testen |
| Groot lettertype, klein scherm, Android-navigatie | Geen afgesneden bediening of nummers | Nog testen |

## Storeteksten — concept

Naam: PasKluis

Korte beschrijving: Je klantenkaarten, QR-codes en cadeaukaarten overzichtelijk bij elkaar.

Beschrijving: Bewaar je eigen klantenkaarten en QR-codes op je telefoon en laat ze eenvoudig scannen. Voeg kaarten toe met je camera, via een foto of screenshot, of handmatig. Bewaar gratis één eigen cadeaukaart, houd zelf het saldo bij en stel een vervaldatum in. Kies Nederlands of Engels, markeer favorieten en zet optioneel winkels in de buurt aan. PasKluis is voor iedereen reclamevrij. Met PasKluis Plus bewaar je onbeperkt cadeaukaarten en deel je klanten- en cadeaukaarten. Als de ontvanger ook Plus heeft, kunnen jullie samen bewerken. Plus is een eenmalige aankoop; de store toont de actuele prijs. Een account is geen automatische back-up van alle lokale kaarten.

Beta-instructie: Test toevoegen/importeren, QR-herkenning, delen tussen iPhone en Android, accountwissels, meldingen, support, appvergrendeling en NL/EN. Gebruik onbruikbare testcodes. Meld toestel, appversie, stappen, verwacht resultaat en werkelijk resultaat via Klantenservice. Vermeld geen wachtwoorden of geldige kaartcodes.

Reviewinformatie: De basis werkt zonder account. Account/Plus/delen vragen een account. Richt afzonderlijke beoordelingsaccounts in met testrechten en zonder persoonlijke kaarten. Deel de inloggegevens alleen in de beveiligde reviewvelden van de stores. Leg de één-apparaatregel uit. Maak geen uitzonderingen die serverrechten omzeilen.

## Externe test en lancering

Android: voltooi eerst de appinrichting en gesloten testtrack. Voor dit persoonlijke account zijn minimaal **12 testers die 14 aaneengesloten dagen aangemeld blijven** nodig. Daarna productietoegang aanvragen; dit is geen automatische toelating. Interne test/APK-distributie telt hiervoor niet. Bron: https://support.google.com/googleplay/android-developer/answer/14151465?hl=en

Apple: eerste geschikte externe TestFlight-build plus testinformatie naar TestFlight App Review. Openbare App Store-publicatie krijgt later een afzonderlijke beoordeling. Bron: https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers/

Nog nodig van de eigenaar: tester-e-mailadressen (niets uitnodigen zonder akkoord op de concrete lijst), juridische exploitant/contactgegevens, keuze doelgroepen/regio's en storeclassificatie. Geen betaalde publieke lancering vóór werkende aankoopverificatie, automatische terugbetalingsverwerking en afgetekende toesteltests.
