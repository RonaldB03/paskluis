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
