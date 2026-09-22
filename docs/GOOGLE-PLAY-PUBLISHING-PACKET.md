# PasKluis — Google Play invulpakket

Bijgewerkt op 22 september 2026. Dit document is bedoeld om na afronding van de
Google Play-accountverificatie de appinrichting zonder nieuw uitzoekwerk af te
ronden. Controleer de definitieve consolelabels bij het invullen; Google kan de
volgorde en benaming van vragen wijzigen.

## Huidige blokkade

- Organisatieaccount: PasKluis / Aschman & Vet VOF.
- Website `https://paskluis.com/` is in Search Console geverifieerd en aan het
  Play-ontwikkelaarsaccount gekoppeld.
- Identiteitsdocumenten zijn ingediend en worden door Google gecontroleerd.
- Telefoonverificatie komt pas beschikbaar nadat de eerdere controles zijn
  afgerond.
- Google blokkeert het maken van de eerste app totdat alle accountverificaties
  zijn afgerond.

## App aanmaken

| Veld | Waarde |
|---|---|
| Appnaam | PasKluis |
| Standaardtaal | Nederlands (Nederland) — `nl-NL` |
| App of game | App |
| Gratis of betaald | Gratis |
| Applicatie-ID | `nl.paskluis.app` |
| Categorie | Tools / Hulpprogramma's |
| Advertenties | Nee |
| In-app aankoop | Ja, eenmalig niet-verbruikbaar product |
| Product-ID | `paskluis_plus` |
| Richtprijs | € 1,99 eenmalig |

PasKluis moet als gratis app worden aangemaakt. PasKluis Plus wordt afzonderlijk
als eenmalig, niet-verbruikbaar in-app product ingericht. Zet de verkoop pas aan
na een geslaagde aankoop-, herstel- en terugbetalingstest met een licentietester.

## Nederlandse winkelvermelding

**Naam**

PasKluis

**Korte beschrijving**

Je klantenkaarten, QR-codes en cadeaukaarten overzichtelijk bij elkaar.

**Volledige beschrijving**

Bewaar je klantenkaarten, QR-codes en cadeaukaarten veilig en overzichtelijk op
je telefoon. Laat codes eenvoudig scannen en voeg kaarten toe met je camera, via
een foto of screenshot, of handmatig.

Bewaar gratis één cadeaukaart, houd zelf het saldo bij en stel een vervaldatum
in. Markeer je belangrijkste kaarten als favoriet en laat optioneel de juiste
klantenkaart zien wanneer je bij een winkel in de buurt bent. Je locatie wordt
alleen gebruikt wanneer je deze functie zelf inschakelt.

PasKluis is voor iedereen reclamevrij. Met PasKluis Plus bewaar je onbeperkt
cadeaukaarten en kun je klanten- en cadeaukaarten veilig delen. Wanneer beide
gebruikers Plus hebben, kunnen zij een gedeelde kaart samen bijwerken. Plus is
een eenmalige aankoop; de actuele prijs staat altijd in de appstore.

Je eigen kaarten worden standaard lokaal op je toestel opgeslagen. Een account
is daarom geen automatische cloudback-up van al je lokale kaarten.

## Engelse winkelvermelding

**Name**

PasKluis

**Short description**

Keep loyalty cards, QR codes and gift cards together in one clear wallet.

**Full description**

Keep your loyalty cards, QR codes and gift cards safe and organized on your
phone. Present codes for easy scanning and add cards with your camera, from a
photo or screenshot, or manually.

Store one gift card for free, track its balance and add an expiry date. Mark
important cards as favorites and optionally show the right loyalty card when
you are near a store. Your location is used only when you enable this feature.

PasKluis is ad-free for everyone. PasKluis Plus lets you store unlimited gift
cards and securely share loyalty and gift cards. When both users have Plus,
they can update a shared card together. Plus is a one-time purchase; the current
price is always shown by the app store.

Your own cards are stored locally on your device by default. An account is not
an automatic cloud backup of all locally stored cards.

## Beleidsvragen

| Onderdeel | Antwoord / toelichting |
|---|---|
| Advertenties | Nee. PasKluis bevat geen advertenties en geen advertentie-SDK. |
| App-toegang | De basis werkt zonder account. Account, delen en Plus vragen inloggen. Geef Google aparte reviewgegevens in het beveiligde reviewveld; nooit in de openbare beschrijving. |
| Doelgroep | Aanbevolen: 13 jaar en ouder; de app is niet specifiek op kinderen gericht. Bevestig dit als zakelijke keuze voordat de verklaring definitief wordt ingediend. |
| Financiële functies | Geen bank-, krediet-, beleggings- of cryptofunctie. Alleen een normale eenmalige digitale in-app aankoop via Google Play. |
| Gezondheidsfuncties | Nee. |
| Nieuws | Nee. |
| Overheidsapp | Nee. |
| Account verwijderen | Ja, in de app en via de openbare webpagina. |
| Privacybeleid | Openbare privacyverklaring aanwezig. |
| Inhoudsclassificatie | Utility/wallet-functionaliteit, geen geweld, seks, gokken of drugs. Antwoord wel eerlijk dat gebruikers zelf kaartnamen en supportberichten kunnen invoeren. |

## Data Safety — voorbereid antwoordmodel

De uiteindelijke verklaring moet exact overeenkomen met de versie die wordt
ingediend. PasKluis verkoopt geen gegevens en gebruikt geen gegevens voor
advertenties. Gegevens die uitsluitend op het toestel blijven, gelden niet als
door de ontwikkelaar verzameld. Data die via Supabase of een andere provider van
het toestel af gaat, moet wel worden aangegeven, ook als verwerking tijdelijk is.

| Gegevenstype | Verzameld | Verplicht | Doel |
|---|---:|---:|---|
| E-mailadres | Ja bij account of support | Nee voor basisgebruik | Accountbeheer, authenticatie, klantenservice |
| Naam | Optioneel | Nee | Profiel en klantenservice |
| Gebruikers-ID | Ja bij account | Nee voor basisgebruik | Accountbeheer, beveiliging en delen |
| Precieze locatie | Alleen na inschakelen | Nee | Winkels in de buurt en appfunctionaliteit |
| Aankoopgeschiedenis / transactiereferentie | Alleen bij Plus | Nee | Aankoopverificatie, herstel en fraudepreventie |
| Klantenserviceberichten | Alleen bij gebruik klantenservice | Nee | Klantenservice |
| Door gebruiker gegenereerde gedeelde kaartgegevens | Alleen bij delen | Nee | Appfunctionaliteit |
| Foto/screenshot | Alleen wanneer bewust aan support toegevoegd | Nee | Klantenservice |
| Apparaat- of andere ID's | Bij account/push | Nee voor basisgebruik | Beveiliging, één-apparaatregel en meldingen |
| Appversie en platform | Bij support | Nee | Klantenservice en probleemoplossing |

Aanvullende antwoorden:

- Gegevens worden tijdens transport versleuteld via HTTPS/TLS.
- Gebruikers kunnen verwijdering van hun account en gekoppelde persoonsgegevens
  aanvragen.
- Verzameling is grotendeels optioneel; de basiswallet werkt zonder account.
- Kaartgegevens die alleen lokaal blijven, worden niet door PasKluis verzameld.
- Deel geen geldige kaartcodes, pincodes of wachtwoorden in reviews of
  testinstructies.
- Controleer bij het definitief invullen of Google de gebruikte verwerkers onder
  de actuele definitie als 'delen' laat gelden. Supabase, Firebase, Google Places
  en Google Play worden uitsluitend gebruikt om PasKluis namens de ontwikkelaar
  te leveren, niet voor advertenties.

## Machtigingen en prominente uitleg

| Android-machtiging | Waarom |
|---|---|
| Camera | Streepjescodes en QR-codes scannen en kaarten fotograferen |
| Locatie tijdens gebruik | Optioneel winkels in de buurt vinden |
| Meldingen | Gedeelde kaarten, supportantwoorden en lokale herinneringen |
| Biometrie | Optionele appvergrendeling |
| Opstarten na herstart | Lokale geplande herinneringen herstellen |

Vraag locatie pas wanneer de gebruiker de buurtfunctie activeert. De uitleg moet
vermelden dat een zoeklocatie via de backend naar Google Places gaat, dat geen
persoonlijke verplaatsingsgeschiedenis wordt opgebouwd en dat de functie kan
worden uitgeschakeld.

## Openbare URL's

- Website: `https://paskluis.com/`
- Privacy: `https://ronaldb03.github.io/paskluis/privacy.html`
- Account verwijderen: `https://ronaldb03.github.io/paskluis/delete-account.html`
- Hulp: `https://ronaldb03.github.io/paskluis/support.html`
- Support: `info@paskluis.com`

Controleer vóór indienen dat alle URL's zonder inloggen via een privévenster
laden en dat de website-URL uiteindelijk op het eigen PasKluis-domein naar deze
pagina's verwijst.

## Benodigde winkelassets

- App-pictogram: 512 × 512 pixels, PNG/JPG, maximaal 1 MB.
- Feature graphic: 1024 × 500 pixels, PNG/JPG, maximaal 15 MB.
- Minimaal twee duidelijke telefoonscreenshots; aanbevolen zijn Home,
  klantenkaarten, QR-codes, cadeaukaarten, locatie-instelling en klantenservice.
- Screenshots mogen geen echte kaartcodes, pincodes, e-mailadressen of namen van
  testers tonen.
- Maak Nederlandse en Engelse screenshots wanneer de Engelse winkelvermelding
  wordt gepubliceerd.

Het bestaande ontwikkelaarspictogram is geschikt. De bestaande brede
ontwikkelaarsheader is niet automatisch dezelfde asset als de vereiste
1024 × 500 feature graphic; maak daarvoor een afzonderlijke export.

## Test en review

**Bèta-instructie**

Test toevoegen/importeren, QR-herkenning, delen tussen iPhone en Android,
accountwissels, meldingen, support, appvergrendeling en Nederlands/Engels. Gebruik
uitsluitend onbruikbare testcodes. Vermeld bij een melding het toestel, de
appversie, de stappen, het verwachte resultaat en het werkelijke resultaat.

**Reviewinformatie**

De basis werkt zonder account. Account, Plus en delen vragen een account. Richt
afzonderlijke beoordelingsaccounts in met testrechten en zonder persoonlijke
kaarten. Deel inloggegevens alleen in de beveiligde reviewvelden. Leg uit dat
één apparaat tegelijk online actief kan zijn en dat inloggen op een tweede
apparaat de bestaande sessie beëindigt.

**Gesloten test**

- Maak na accountgoedkeuring eerst een interne release om installatie en
  aankoopconfiguratie te controleren.
- Start daarna een gesloten test met minimaal 12 testers die 14 aaneengesloten
  dagen aangemeld blijven als Google dit voor het account vereist.
- Interne testers tellen niet automatisch mee voor de productietoegangseis.
- Vraag pas productietoegang aan wanneer de toestelchecklist is afgetekend.

## Volgorde zodra Google het account vrijgeeft

1. Telefoonnummer verifiëren.
2. App `PasKluis` aanmaken met applicatie-ID `nl.paskluis.app`.
3. App Signing accepteren en de Android App Bundle uploaden.
4. Winkelvermelding, screenshots en feature graphic invullen.
5. Privacybeleid, Data Safety, accountverwijdering en app-toegang invullen.
6. Doelgroep, inhoudsclassificatie, advertenties en financiële verklaringen
   afronden.
7. Betaalprofiel koppelen en `paskluis_plus` als niet-verbruikbaar product
   configureren.
8. Licentietesters instellen; kopen, annuleren, herstellen en terugbetaling
   testen voordat de koopknop publiek wordt aangezet.
9. Gesloten test starten en testerstatus bewaken.
10. Na de vereiste testperiode productietoegang aanvragen.

## Bronnen

- Google Play Help — eerste app maken: https://support.google.com/googleplay/android-developer/answer/9859152
- Google Play Help — Data Safety: https://support.google.com/googleplay/android-developer/answer/10787469
- Google Play Help — gesloten test/productietoegang: https://support.google.com/googleplay/android-developer/answer/14151465
- Google Play Help — accountverwijdering: https://support.google.com/googleplay/android-developer/answer/13327111
- Google Play Help — app-toegang voor review: https://support.google.com/googleplay/android-developer/answer/15748846
