# PasKluis 1.5.3 — vertrouwde flow met beveiligingsupdates

Op 4 oktober 2026 vroeg de gebruiker de officiële Apple-aanvraag voor 1.6.0 in te trekken en de gebruikersflow van 1.5.2 te herstellen met behoud van beveiligingsupdates. Referentie voor de oude app: commit `fb5da82` (1.5.2, inclusief accountherstel en Plus-status).

## Hersteld

- Startscherm met de bestaande secties en klantenservicekaart, zonder Tegoedbewaker of nieuw back-upblok.
- Toevoegen begint weer met klantenkaart, QR-code of cadeaukaart. Daarna volgt de bestaande winkel-/scan-/invoerroute of import van één screenshot. Geen extra typebevestiging of batchimport.
- Het oorspronkelijke back-upscherm, zonder de nieuwe inspectieknop.
- Geen nieuwe favorietensnelkoppelingen op het appicoon. Eventueel door 1.6.0 aangemaakte snelkoppelingen worden bij opstarten opgeruimd; de plugin blijft uitsluitend voor deze migratie aanwezig.

## Behouden

- AES-256-GCM voor eigen afbeeldingen, veilige sleutels, onderbreekbare migratie en weergave van reeds versleutelde afbeeldingen. Een volledige broncode-downgrade zou die afbeeldingen niet kunnen lezen.
- Back-ups zonder gebruikscoördinaten; hetzelfde privacyfilter bij herstel van oude back-ups.
- Account-/MFA-herstel en betrouwbare Plus-status uit 1.5.2.
- Gedeelde updates behouden lokale favorieten en archivering; fouten, opnieuw proberen en versieconflicten worden correct afgehandeld.
- Strengere herkenning van vervaldata, meldingsnavigatie en lokale kalenderberekening.
- Offline opstarten bij ontbrekende Firebase-/meldingsondersteuning, juiste appversie en behoud van grote systeemtekst.
- Serverbeveiliging, versleutelde Google Drive-back-ups en de bestaande herstelcontroles.

Opgeslagen kaarten, foto’s, saldi en extra metadata worden niet verwijderd. Het verwijderen van de Tegoedbewaker verwijdert uitsluitend de extra functie en schermen.

## Versies en uitrol

De correctie heet 1.5.3. Buildnummers blijven oplopen boven de al geüploade iOS 137 en Android 98; de workflows lezen de actuele storehistorie. Deze uitvoering maakt testbuilds. De officiële Apple-review wordt niet automatisch opnieuw gestart.

Fysieke toesteltests blijven nodig voor de upgrade met bestaande foto's, camerascans, biometrie en storeaankopen.

## Verificatie op 4 oktober

- Apple-aanvraag `5bcd789c-9e06-480b-9911-45f4bd6f88e2` voor 1.6.0 (137) ingetrokken; App Store Connect bevestigt **Removed** en de versie toont **Developer Rejected**.
- 104 Flutter-tests geslaagd, inclusief drie regressies voor de oude toevoegflow: type kiezen, terugkeren naar typekeuze en de juiste handmatige route openen.
- Flutter-analyse geslaagd zonder fouten of waarschuwingen; 207 bestaande informatieve stijl-/deprecatiemeldingen.
- GitHub-validatie van broncommit `2ed4c5ab82cebb1e48c9b91349367b854819ac1d` geslaagd: run `37224495204`.
- De toevoeg- en back-upschermen zijn inhoudelijk gelijk aan 1.5.2; account-, accountherstel- en aankoopcode zijn eveneens gelijk aan die referentie (afgezien van regeleinden).
- iOS-testbuild: https://codemagic.io/app/69f36f732d8b59f24897933a/build/6ac29aa47394575b200b0d0e
- iOS **1.5.3 (138)** succesvol gebouwd, geüpload en verwerkt; gekoppeld aan Paskluis Testers. Externe TestFlight-review: **WAITING_FOR_REVIEW**. Upload/build-id `4ef35c3d-73f2-4992-8e18-48fc06a39236`. Er is geen officiële App Store-aanvraag gestart.
- Ook de nog wachtende externe TestFlight-review van 1.6.0 (137) ingetrokken; die build staat weer op **Ready to Submit**.
- Android-testbuild: https://codemagic.io/app/69f36f732d8b59f24897933a/build/6ac29ad97394575b200b0d1b
- Android **1.5.3 (99)**: ondertekende APK en AAB succesvol gebouwd; AAB naar gesloten testkanaal `alpha` geüpload. Track-readback bevestigt versie 1.5.3, code 99, status `completed`. Storebeoordeling/beheerd publiceren kan beschikbaarheid voor testers nog vertragen.
- Android-AAB SHA-256: `65f151c850bfa5bcf53fcce814a894ea5807b4ad861f0843701459ce2d548d3b`.
