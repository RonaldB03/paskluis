# PasKluis 1.9.0

Deze update bundelt alle door Ronald gevraagde cadeaukaartverbeteringen. Apple-review en automatische publicatie na goedkeuring zijn door Ronald toegestaan. De definitieve App Store-indiening is nog niet uitgevoerd.

## Wijzigingen

- Delen via lang indrukken van eigen cadeaukaarten, op Home en in het cadeaukaartenoverzicht. De bestaande account-, Plus- en pincodewaarschuwingen blijven gelden.
- Vervaldatum onder Kaart gebruikt; een verlopen datum wordt gemarkeerd. Geen datum wordt verzonnen als die ontbreekt.
- Barcodecontrole-uitleg bij toevoegen; meerdere fysieke codes blijven door de gebruiker te controleren.
- Cadeaukaarten van nabije winkels bovenaan en een optionele afstandsaanduiding. Locatie moet aanstaan.
- iPhone: optionele lokale winkelmeldingen rond 100 meter, maximaal eenmaal per fysieke winkel per 24 uur. Alleen kaarten met positief saldo die niet verlopen of gearchiveerd zijn.
- Afzonderlijke instellingen voor vervaldatumherinneringen, winkelmeldingen en het tonen van het saldo in winkelmeldingen.

## Grenzen van winkelmeldingen

Alleen iOS heeft de nieuwe native achtergrondmonitor. Android heeft in deze broncode wel de overige cadeaukaartverbeteringen, maar geen achtergrondwinkelmeldingen. De monitor bewaakt maximaal twintig opgeslagen winkels uit de laatst opgehaalde omgeving, met één dichtstbijzijnd filiaal per merk. Het is geen landelijke automatische ontdekking tijdens verplaatsingen. De app moet regelmatig geopend worden om locaties en kaartgegevens bij te werken. Na zeven dagen zonder verversen wordt niet meer gemeld. De 100-metergrens en bezorgtijd zijn afhankelijk van iOS en de locatiekwaliteit.

Locatie op Altijd en meldingsrechten zijn nodig; winkelmeldingen staan standaard uit. Geen doorlopende GPS-tracking of uploads bij een regio-event. Achtergrondopstart is expliciet uitgesloten van nieuwe locatieopvragen. Winkelcoördinaten, meldingstekst en termijnen worden lokaal bewaard; kaartcodes en pincodes gaan niet naar de native monitor. Uitschakelen wist de regio-instellingen. Het laatst gemelde tijdstip voorkomt herhaling.

## Validatie

- Volledige Flutter-suite: 113 tests geslaagd vóór de laatste opstartguard en aanvullende schermtest.
- Aanvullende schermtest: vervaldatum onder de gebruiksknop op 360 px met 130% tekst, zonder overflow, geslaagd.
- Endpoint: 4 tests geslaagd, waaronder cache, begrensde paralleliteit, budgetweigering en gedeeltelijke fouten.
- Flutter-analyse: geen fouten of waarschuwingen; bestaande informatieve lintmeldingen aanwezig. CI herhaalt analyse en alle tests.
- Live VPS-endpoint getest met een synthetisch openbaar testpunt: winkelcoördinaten aanwezig.
- Nederlandse en Engelse publieke privacyteksten via HTTPS gecontroleerd.
- Native iOS-compilatie en upload: nog te bevestigen in Codemagic.
- Echte aankomst bij een winkel, toestemmingsdialoog op iPhone, gesloten app en 24-uurs herhaling: nog niet op een fysiek toestel getest. Niet als geslaagd rapporteren.

## Apple-reviewnotities (voor invoer)

This update adds optional gift-card store reminders using iOS region monitoring. The feature is off by default. Enable it in Settings > Screen and notifications > Gift card near a store. Notification permission and Always location permission are required. Location and store lookup occur while using the app; store entry reminders are generated locally. Up to 20 saved nearby stores are monitored; the set is refreshed when the app is used and expires after seven days without refresh. The radius is approximately 100 metres, with a maximum of one notification per store per 24 hours. The balance is manually maintained and can be hidden in notifications. No barcode or PIN is passed to the native monitor. Turning the feature off stops monitoring.

The existing approved non-consumable product paskluis_plus is unchanged. Plus can be purchased and restored without a PasKluis account. Sharing requires a free PasKluis account and linking the existing purchase, without paying again.

## Serverpublicatie

De winkelfunctie retourneert aanvullend latitude en longitude; de bestaande responsvelden blijven behouden. Gerichte publicatie en privacy-aanvulling uitgevoerd op 7 oktober 2026. Herstelkopie op de VPS: /var/backups/paskluis-gift-reminders-20261007T082435Z. Geen andere serverfuncties opnieuw uitgerold.

De actuele buildstatus staat in ../release-190-build-state.json buiten de repo. Controleer de werkelijke buildnummers in Apple; pubspec 143 is alleen de lokale basis. Codemagic bepaalt het volgende nummer over alle bestaande Apple-versies.
