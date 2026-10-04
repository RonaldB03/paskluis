# PasKluis 1.6.0+44 — implementatie en vrijgave

Lokale releasekandidaat, 4 oktober 2026. Niet gepubliceerd naar App Store, Play Store of VPS. Bestaande wijzigingen voor accountbeheer, aankopen en beheeruitnodigingen zijn behouden.

## Geïmplementeerd

| Onderdeel | Concreet gedrag |
|---|---|
| Foto’s | AES-256-GCM met sleutel in veilige toestelopslag. Bestaande foto’s migreren na controle; referenties worden eerst opgeslagen. Een herstart ruimt achtergebleven oude foto’s op. Gedeelde bestandsreferenties worden pas bij de laatste verwijdering gewist. |
| Back-upprivacy | Nieuwe back-ups bevatten geen opgeslagen gebruikscoördinaten. Herstel negeert deze velden ook in oudere back-ups. Bestaande serverversies worden niet stilzwijgend aangepast. |
| Delen | Ontvangen updates bewaren lokale favorieten, archivering en mappen. Lokale voorkeuren vereisen geen online kaartwijziging. Mislukte gedeelde edits geven een melding; tijdelijk falen kan opnieuw geprobeerd worden, een versieconflict vraagt opnieuw laden. |
| OCR | Alleen expliciet gelabelde vervaldata worden voorgesteld. Onmogelijke kalenderdatums en ongelabelde aankoopdatums worden geweigerd; maand/jaar eindigt op de laatste dag van die maand. |
| Toevoegen | Direct scannen vanaf de toevoegpagina, daarna type en inhoud controleren. Meerdere screenshots kunnen geselecteerd en afzonderlijk beoordeeld worden; bestaande en dubbele codes worden niet standaard aangevinkt. |
| Tegoedbewaker | Groepeert cadeaukaarten en klantenkaarten per merk, sorteert op vervaldatum, toont geregistreerd saldo en bijwerkdatum. Onbekende en verlopen saldi worden uitgelegd. De bestaande bestedingsflow blijft bereikbaar. Geen live-saldobelofte. |
| Snelkoppelingen | Maximaal drie lokale favorieten via lang indrukken van het appicoon. Generieke labels voorkomen dat namen, codes of PIN’s op het startscherm verschijnen. Verwijderde/gearchiveerde kaarten worden niet geopend. Navigatie loopt door de bestaande appvergrendeling. |
| Back-upoverzicht | Rustige melding op Home bij fout of oude/onbekende back-up. In het beheerscherm: controle van kaartenaantal, unieke foto’s en geschatte omvang vóór upload. Server controleert de totale ruimte van bewaarde versies. |
| Meldingen | Lokale cadeaukaartmeldingen openen de juiste kaart, ook na koude start. Herinneringen worden op 09:00 lokale kalenderdatum berekend. |
| Toegankelijkheid | Extra duidelijk verlaagt grote systeemtekst niet meer en behoudt niet-lineaire systeemschaling. Nieuwe schermen getest op smalle weergave met 300% tekst. |
| Opstarten | Ontbrekende Firebase-/notificatieondersteuning mag de lokale kluis niet blokkeren. Versienummer komt uit de geïnstalleerde app. |
| Ontwikkelen | Flutter 3.47.6 en CI-Node 24.15.0 vastgezet; controles op codex-branches, hoofdbranches en pull requests. LF-regels voorkomen Windows-fouten; de hash van de voorwaarden blijft exact gelijk aan de bestaande acceptatieversie. |
| Serverherstel | Google Drive-service en timer geïnstalleerd en actief. Upload, externe checksum, download en lokale ontsleuteling geslaagd. Ook rollen en complete database logisch hersteld in een container zonder netwerk; 189 opslagverwijzingen en 190 bestanden gecontroleerd. Testomgeving daarna verwijderd. |

## Verificatie

- 105 Flutter-tests geslaagd, inclusief foto-encryptie, beschadigde ciphertext, herhaalde/onderbroken migratie, behouden fotoreferenties, datumherkenning, gedeelde voorkeuren, privacyfilters en nieuwe schermen.
- 61 Node-tests geslaagd (backend-/beheerregressies en winkelzoekfunctie), ook zonder Windows-normalisatiehook.
- Vier Python-tests voor de Drive-overdracht geslaagd, waaronder het tegenhouden van een manifest na checksumfout.
- `flutter analyze --no-fatal-infos` geslaagd: geen fouten of waarschuwingen. Er resteren stijl-/deprecatiemeldingen; de hele bestaande app is niet cosmetisch herschreven.
- Lokale serverkopie `20261002T204126Z.pkb` opnieuw gecontroleerd: SHA-256, AES-GCM-authenticatie, archief, databaseheader en 190 opslagbestanden.
- De gebruiksvoorwaarden zijn inhoudelijk niet veranderd; de LF-bytes komen weer overeen met de bestaande vastgelegde SHA-256.

Dit bewijst de genoemde automatische controles. Het is geen bewijs van werking van camera, biometrie, native snelkoppelingen, push, storebetalingen of kassascanners op fysieke toestellen.

## Nog uit te voeren vóór brede vrijgave

1. Ondertekende Android- en iOS-build maken en testen op echte toestellen. Controleer offline koude start, foto-upgrade van 1.5.2, cameraweigering, OCR, 300% tekst, biometrie, snelkoppelingen bij vergrendelde app, meldingen bij koude start en saldobesteding. Deze omgeving heeft geen Android-SDK of Xcode.
2. Met twee testaccounts gedeelde saldo-edits, gelijktijdige versieconflicten, intrekken en opnieuw inloggen testen tegen de echte backend. Geen echte saldo’s besteden of productiegegevens wijzigen.
3. Afgerond: Drive-service geïnstalleerd met bestaande aanmelding; eerste echte upload, externe checksum, download en ontsleuteling gecontroleerd. Zie [Google Drive-back-up](GOOGLE-DRIVE-BACKUP.md).
4. Afgerond: de Drive-kopie van 4 oktober logisch hersteld en gecontroleerd in een geïsoleerde PostgreSQL-container. Een mobiele gebruikerstest tegen een volledig herstelde API-/Storage-stack blijft onderdeel van de toestel-/integratietests.
5. Proxy/IP-begrenzing van de openbare winkelzoekfunctie en websiteheaders (CSP/HSTS) op de VPS controleren. Niet lokaal te bewijzen of verantwoord blind te overschrijven.
6. Na bovenstaande controles expliciet de releasekanalen vrijgeven. Er is vanuit deze wijziging geen publicatie gestart.

Horlogeapps, internationale catalogusuitbreiding, winkelintegraties voor live saldo en huishoudreserveringen blijven vervolgproducten. Ze zijn geen onderdeel van deze kandidaat en zijn niet als werkend gepresenteerd. De Tegoedbewaker is een onderscheidingsrichting, geen bewezen exclusiviteit tegenover SuperCards.
