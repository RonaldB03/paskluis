# PasKluis 1.5.0 — overdracht voor live testen

Status 22 september 2026: code voor de testkandidaat staat klaar; nog geen vrijgave voor externe testers of openbare lancering. Serveruitrol is geblokkeerd door een verlopen Supabase-beheersessie.

## In deze update

- Ontvangen kaarten horen lokaal bij de ontvanger. Uitloggen/accountwissel wist ontvangen kaarten en herinneringen; eigen kaarten blijven bestaan.
- Actieve sessie ook in databasebeleid en deel-RPC's afgedwongen. Een overgenomen oude sessie krijgt geen nieuwe toegang.
- Interne supportnotities naar een aparte, afgeschermde tabel.
- Automatische ontvangstbevestiging per nieuw gesprek, in NL/EN; doeltermijn 12 uur begint bij de eerste onbeantwoorde klantreactie. Een automatisch bericht telt niet als persoonlijk antwoord.
- Supportcategorieën, minimale appcontext, gastgesprekken ook na inloggen, medewerkers toewijzen, standaardantwoorden, zoekfilters, achterstallige gesprekken en bekende storingen. Screenshotbijlagen met een voorbeeld vóór verzenden en privéopslag; tijdelijke links voor bevoegde lezers.
- Databasewachtrij voor deel- en supportmeldingen, aparte push- en mailstatus, herhaalpogingen, generieke melding zonder kaartcode/PIN/gesprekstekst. Worker en SMTP moeten nog geconfigureerd en samen getest worden.
- Native aankoop-/herstelcode en serververificatie voor het eenmalige product `paskluis_plus`; verkoop staat standaard uit. Toegang wordt uit alle geverifieerde aankopen afgeleid, zodat terugbetalingen op twee platforms geen oude Plus-toegang achterlaten. Automatisch ophalen van store-terugbetalingen is nog een afzonderlijk open punt.
- Account verwijderen via app en voorbereide openbare webpagina. Extra wachtwoordcontrole, geen verwijdering van medewerkersaccounts zonder eerst hun rol te wijzigen.
- Beheerde winkelherkenning, unieke barcodeprefixen, geen willekeurige gok bij meerdere matches.
- Eerlijke uitleg van locatieverwerking en lokale opslag. GPS-metingen ouder dan twee minuten of met meer dan 100 m onnauwkeurigheid worden niet als actuele afstand gebruikt.
- Atomair Places-budget, meerdere filiaalresultaten per cachegebied; dichtstbijzijnde opnieuw berekend bij veranderde locatie.
- Appvergrendeling en privacyscherm om de volledige Navigator.
- Onderhoudsmelding en updateadvies op Home; beheerbare Engelse hulp-/privacytekst.
- Analyzerfouten blokkeren nu de build. Extra regressietests en onafhankelijke validatieworkflow.

## Wat werkelijk gecontroleerd is

- JavaScript en alle zeven Edge Function-bronbestanden: syntaxiscontrole geslaagd.
- Vier tests van de echte meldingshandler met gesimuleerde aanbieders geslaagd: pushstoring blokkeert e-mail niet, mailstoring verstuurt push niet opnieuw, ingetrokken deelrechten geven geen oude melding, onbevoegde verzoeken kunnen geen werk starten. Dit is geen bewijs van daadwerkelijke mail- of pushbezorging.
- Dart-bronnen: syntaxiscontrole en NL/EN-sleutelcontrole geslaagd (692 berichten); dit vervangt geen Flutter-analyse.
- Eerste databaseproef (020–024 in een teruggedraaide transactie): sessieovername, oude sessie geweigerd, interne notities onleesbaar voor klant, één ontvangstbevestiging, termijn wordt niet opnieuw gestart. Latere aanvullingen aan 021 en migraties 025–026 zijn nog niet live uitgevoerd.
- Appkandidaat `f6ee355`: [iOS Candidate Build #1](https://codemagic.io/app/69f36f732d8b59f24897933a/build/6ab26e8f9dae708f39d82606) geslaagd, inclusief analyse en alle 23 Fluttertests. [Android Candidate Build #1](https://codemagic.io/app/69f36f732d8b59f24897933a/build/6ab26e90952c592617281d6d) is gestart op dezelfde appbron. De status wordt vóór overdracht bijgewerkt. Latere wijzigingen betreffen beheer, servercode, tests en documentatie.
- Tussenversie `e166ae4` is eerder via de bestaande releaseworkflows verspreid (iOS #64 / Android #62). Die tussenversie is geen vrijgave voor de officiële test: de nieuwe servermigraties ontbreken nog. De definitieve kandidaat wordt niet automatisch verspreid.
- Supabase sessie verloopt opnieuw. Migraties, nieuwe Edge Functions en vernieuwd beheer zijn nog niet live geactiveerd.
- Camera, biometrie, betalingen, mailboxbezorging en push op twee echte telefoons zijn nog niet getest.

## Uitrolvolgorde

1. Herstel de Supabase-beheersessie. Gebruik de beveiligde aanmeldroute; geen wachtwoorden of sleutels in chat of Git.
2. Voer de bijgewerkte migraties 020–026 met de regressies eerst in een geïsoleerde testomgeving uit. Leg een herstelpunt vast. `supabase/tests/release_security.sql` draait in een rollback-transactie. Versie 020 verplaatst en verwijdert de oude notitiekolom; oud beheer moet daarmee gecoördineerd worden vervangen.
3. Configureer alleen voor PasKluis:
   - `SUPPORT_SMTP_JSON`: `{host,port,user,password,from}` van het gekozen mailaccount; bestaande Auth-SMTP is geen automatisch gedeelde Edge-secret.
   - `SUPPORT_INBOX_EMAIL`: `info@paskluis.nl`.
   - `NOTIFICATION_WORKER_SECRET`: willekeurige geheime waarde van minimaal 32 tekens, identiek in Vault onder `paskluis_notification_worker_secret`.
   - Bestaande `FIREBASE_SERVICE_ACCOUNT_JSON` en `GOOGLE_PLACES_API_KEY` behouden.
   - `APPLE_IAP_KEY_JSON`: `{privateKey,keyId,issuerId}`, met het juiste recht op PasKluis.
   - `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`: afzonderlijke serviceaccount met uitsluitend benodigde Play-rechten voor PasKluis.
   - `ALLOW_SANDBOX_PURCHASES=true` uitsluitend waar bewust met storetesters getest wordt.
4. Deploy migraties en alle gewijzigde functies gezamenlijk; activeer daarna `supabase/operations/enable_notification_worker.sql`. De worker valideert zijn eigen secret; gebruikerfuncties valideren JWT via Auth. Controleer eigen Supabase CLI projectkoppeling vóór deploy.
5. Werk de beheerbranch `codex/admin-control-center` bij met `admin/`; publiceer app.js, index.html en styles.css samen. Bewaar bestaande gebruikers/rollen/logo's.
6. Configureer de twee storeproducten als eenmalig, niet-verbruikbaar `paskluis_plus`, europrijs € 1,99, geen abonnement. Zet `store_purchase_enabled` pas aan nadat beide aankoopflows, herstel en accountbinding zijn gecontroleerd.
7. **Nog uit te bouwen vóór betaalde lancering:** automatische terugbetalings-/intrekkingsverwerking via store-events of periodieke servercontrole. De huidige verificatie verwerkt een terugbetaling bij opnieuw verifiëren, maar ontvangt nog geen automatische store-events.
8. **Screenshotbijlagen zijn voorbereid** met voorbeeld vóór verzending, privéopslag, kort geldige links, maximaal 5 MB en 6 bijlagen per gesprek per dag. Toegangsrechten en verwijderen moeten nog end-to-end worden getest. **Nog open:** herstel van een kwijtgeraakt gastgesprek via e-mail. Rechtstreeks per e-mail antwoorden met terugkoppeling naar het gesprek is bewust geen onderdeel van de eerste versie.
9. Controleer en publiceer openbare support-, privacy- en verwijderpagina's. Bevestig verantwoordelijke bedrijfsnaam/contactgegevens, providerbewaartermijnen en de definitieve privacytekst. De voorbereide pagina's beschrijven 1.5.0 en mogen niet voortijdig als huidige werking worden gepresenteerd.
10. Wacht op groene builds van exact de uiteindelijke commit; voer de toesteltests hieronder uit. Automatische pushes starten nu kandidaatbuilds zonder distributie. De bestaande `ios-release` en `android-test` workflows blijven beschikbaar voor vrijgave nadat de backend gereed is.

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
| Terugbetaling | Plus op server ingetrokken zonder afhankelijkheid van appherstel | Implementatie open |
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
