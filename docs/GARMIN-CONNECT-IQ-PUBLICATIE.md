# PasKluis — Connect IQ publicatievoorbereiding

Status: op 15 oktober 2026 ingediend; Garmin bevestigt **App in behandeling**.
De preview is tot goedkeuring alleen voor het ontwikkelaarsaccount zichtbaar.
Geen openbare telefoonapp bijgewerkt.

Store UUID: `e5582836-4178-442e-bd16-afa95b42e9c8`.
Winkel: https://apps.garmin.com/apps/e5582836-4178-442e-bd16-afa95b42e9c8

Drie echte fēnix 7-simulatorbeelden met fictieve kaarten zijn toegevoegd.
De NL/EN-winkeltekst vermeldt dat de telefoon-testversie momenteel vereist is.
Automatische migratie naar ongeteste modellen staat uit.
De portaalmelding over de handtekening verhinderde indiening niet: het pakket
is lokaal gecontroleerd (RSA 4096, PKCS1v15/SHA256, manifest.sig2 geldig),
waarna Garmin de registratie heeft bevestigd. Goedkeuring is nog niet bevestigd.

## Pakket en identiteit

- Bestand: `build/connect-iq-submission/PasKluis-0.1.0.iq`.
- Versie: 0.1.0, watch-app; Nederlands en Engels.
- Applicatie-ID: `5fdfca8919394cb8b3bbd96184aa208c`.
- Modellen in manifest: fenix6, fenix6pro, fenix6s, fenix6spro, fenix6xpro, fenix7.
- Permissie: Communications. Geen locatie-, activiteiten- of gezondheidsrechten.
- Export met de bestaande ontwikkelaarssleutel. Bewaar die sleutel veilig voor updates;
  voeg hem nooit toe aan het publicatiepakket of Git.
- Store UUID is hierboven geverifieerd. Dit is een afzonderlijke identiteit;
  gebruik niet automatisch de manifest-ID als winkelverwijzing.

## Nederlandse winkeltekst

Naam: PasKluis

Korte omschrijving: Je klantenkaarten, QR-codes en cadeaukaarten aan je pols.

Beschrijving:

Neem je geselecteerde passen mee op je Garmin-horloge. Kies in de PasKluis-app
op je telefoon welke klantenkaarten, losse QR-codes en cadeaukaarten je wilt
meenemen. Ontvangen gedeelde cadeaukaarten kunnen ook worden geselecteerd.
Na synchronisatie kun je de codes zonder telefoonverbinding openen.

Koppel je horloge eerst in Garmin Connect. Installeer PasKluis op je horloge,
open de horloge-app en kies in PasKluis op je telefoon Instellingen → Smartwatch
→ Garmin. Selecteer één horloge en kies je passen. Houd Garmin Connect en de
PasKluis-horloge-app beschikbaar tijdens de synchronisatie.

Gebruik UP/DOWN om te bladeren, START om een categorie of pas te openen en BACK
om terug te gaan. Ook bij een geopende code kun je met UP/DOWN naar de volgende
of vorige pas binnen dezelfde categorie gaan.

Pincodes en saldi worden niet naar het horloge verstuurd. Een cadeaukaartcode
op het horloge kan worden gebruikt om te betalen. De telefoonvergrendeling
beschermt deze extra kopie niet. Wissen, wijzigen en intrekken van gedeelde
kaarten worden pas op het horloge verwerkt na een geslaagde synchronisatie.
Een offline horloge kan de vorige kopie bewaren. Via Instellingen → Pasjes
wissen kun je passen ook op het horloge zelf verwijderen.

Niet elk codeformaat of elke codegrootte past op ieder scherm. Als een code niet
kan worden weergegeven, gebruik je de oorspronkelijke pas op je telefoon.
Het aantal passen wordt begrensd door de beschikbare gegevensruimte, niet door
een vast aantal. Scanbaarheid is mede afhankelijk van de kassascanner.

## English store copy

Name: PasKluis

Short description: Loyalty cards, QR codes and gift cards on your wrist.

Choose cards in the PasKluis phone app and sync them to your Garmin watch.
Browse loyalty cards, QR codes and gift cards, including received shared gift
cards. Once synced, codes are available without a phone connection.

First pair your watch in Garmin Connect. Install and open PasKluis on the
watch, then select Settings → Smartwatch → Garmin in the PasKluis phone app.
Choose one watch and select your cards. Keep Garmin Connect and the PasKluis
watch app available during sync. Use UP/DOWN to browse, START to open and BACK
to return. UP/DOWN also switches cards while a code is open.

PINs and balances are not transferred. Gift card codes on the watch can be
spent. Your phone's app lock does not protect this extra copy. Changes,
deletions and shared-card revocations take effect on the watch after a
successful sync; offline watches may retain their previous copy. You can erase
cards directly on the watch under Settings → Erase cards.

Some formats and code sizes cannot fit every display. Use the phone when a code
cannot be displayed. Capacity is limited by data size, not a fixed card count.
Scanning also depends on the checkout scanner.

## Benodigde winkelbeelden

Gebruik uitsluitend fictieve testcodes, nooit de foto's van echte cadeaukaarten
uit deze chat. Bestaand logo: `garmin/resources/paskluis_logo.png`.
Maak simulatorbeelden van (1) categorieën, (2) lijst met meerdere passen en
winkellogo's, (3) barcode, (4) QR-code, (5) instellingen/pasjes wissen.
Beeldformaten controleren in het actuele Garmin-uploadformulier.
De ingediende beelden staan in `build/connect-iq-submission/screenshot-*.jpg`.

## Installatieknop in de telefoon-testapp

`GarminStore` accepteert uitsluitend een UUID en bouwt zelf een HTTPS-link naar
`https://apps.garmin.com/apps/<Store UUID>`. Geen willekeurige URL of pasgegevens.
Zonder winkel-ID verschijnt uitleg over USB-installatie; er is geen dode knop.
Met `--dart-define=WATCH_BETA=true --dart-define=GARMIN_STORE_ID=<Store UUID>`
verschijnt bij Garmin de knop 'PasKluis in Connect IQ', ook na het koppelen.
Openen van de winkel verandert de koppeling of geselecteerde passen niet.

De Store UUID is in iOS `IQApp.storeUuid` gecorrigeerd; de applicatie-ID voor
berichten is behouden. Controleer openen vanuit zowel iOS als Android en installatie op het
daadwerkelijk gekozen ondersteunde horloge. Niet veronderstellen dat een
winkelverwijzing Garmin automatisch installeert of de gebruiker automatisch koppelt.

## Vervolg na indiening

1. Garmin-goedkeuring afwachten; het portaal noemt maximaal drie dagen.
2. De installatie vanuit de winkel fysiek testen zodra beschikbaar.
3. De telefoon-testbuilds moeten de nieuwe Store UUID nog meenemen; deze
   broncodewijziging maakt de reeds geïnstalleerde telefoonapps niet anders.
4. De bestaande privacy-URL is bereikbaar. De winkelomschrijving beschrijft
   horlogekopieën, cadeaukaartcodes en uitgestelde verwijdering expliciet.
5. Garmin-bèta's zijn volgens het portaal alleen voor de ontwikkelaar en vragen
   later een andere manifest-ID. Op expliciet verzoek van de gebruiker is
   daarom de gewone app ter beoordeling ingediend met behoud van de huidige ID.

Bron: https://developer.garmin.com/connect-iq/submit-an-app/
Garmin vraagt een .iq-export voor alle ondersteunde modellen, winkeltekst en
screenshots en beoordeelt de app vóór openbare beschikbaarheid.
