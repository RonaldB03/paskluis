# PasKluis 1.6.0 — implementatie en vrijgave

Releasekandidaat, 4 oktober 2026. Gebruiker heeft Android- en iOS-builds en directe indiening voor officiële Apple-review geautoriseerd. Android blijft op het bestaande gesloten testkanaal; Apple houdt handmatige vrijgave na goedkeuring. Bestaande wijzigingen voor accountbeheer, aankopen en beheeruitnodigingen zijn behouden. De eerdere publicaties zijn 1.5.2 (iOS 136, Android 97); beide workflows lezen de storestand voor het volgende nummer. Lokale fallback: 1.6.0+137.

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

1. Ondertekende Android- en iOS-builds zijn via Codemagic gemaakt en naar de stores verstuurd. Test ze nog op echte toestellen: offline koude start, foto-upgrade van 1.5.2, cameraweigering, OCR, 300% tekst, biometrie, snelkoppelingen bij vergrendelde app, meldingen bij koude start en saldobesteding.
2. Met twee testaccounts gedeelde saldo-edits, gelijktijdige versieconflicten, intrekken en opnieuw inloggen testen tegen de echte backend. Geen echte saldo’s besteden of productiegegevens wijzigen.
3. Afgerond: Drive-service geïnstalleerd met bestaande aanmelding; eerste echte upload, externe checksum, download en ontsleuteling gecontroleerd. Zie [Google Drive-back-up](GOOGLE-DRIVE-BACKUP.md).
4. Afgerond: de Drive-kopie van 4 oktober logisch hersteld en gecontroleerd in een geïsoleerde PostgreSQL-container. Een mobiele gebruikerstest tegen een volledig herstelde API-/Storage-stack blijft onderdeel van de toestel-/integratietests.
5. Proxy/IP-begrenzing van de openbare winkelzoekfunctie en websiteheaders (CSP/HSTS) op de VPS controleren. Niet lokaal te bewijzen of verantwoord blind te overschrijven.
6. Afgerond: build- en reviewstatus hieronder vastgelegd. Brede openbare vrijgave blijft handmatig; fysieke toesteltests blijven nodig.

Horlogeapps, internationale catalogusuitbreiding, winkelintegraties voor live saldo en huishoudreserveringen blijven vervolgproducten. Ze zijn geen onderdeel van deze kandidaat en zijn niet als werkend gepresenteerd. De Tegoedbewaker is een onderscheidingsrichting, geen bewezen exclusiviteit tegenover SuperCards.

## Store-uitvoering 4 oktober

- Android 1.6.0 (98): ondertekende AAB en APK geslaagd. AAB naar Google Play `alpha` verstuurd en via track-readback bevestigd. Play Console toont de gesloten-testwijziging in beoordeling; beheerd publiceren staat aan.
- AAB SHA-256: `69c4fca1670fb7c16ba393e5cdfec57c03806dd42a6ecc33686f2d04946725f3`.
- Android-build: https://codemagic.io/app/69f36f732d8b59f24897933a/build/6ac28f597394575b200b0a2c
- GitHub-validatie van appcommit `695bcea030f289ffa462e9cd60a1987177aef45c`: geslaagd, run `37221207612`.
- Google Play-productietoegang: 12 testers gedurende 9 van de vereiste 14 dagen; nog niet aanvraagbaar.
- iOS: eerdere 1.5.2 (136) was goedgekeurd maar niet gepubliceerd. Gebruiker gaf expliciet toestemming deze te vervangen. Inzending omgezet naar 1.6.0; build 136 blijft in het account. Eerste automatische releasebuild gestopt vóór upload tijdens toestemmingscontrole. De daaropvolgende TestFlight-run stopte veilig bij de nummercontrole doordat de conceptversie geen gekoppelde build meer had. De controle gebruikt nu de gecombineerde App Store- en TestFlight-historie over alle versies.
- iOS 1.6.0 (137): ondertekende IPA succesvol gebouwd en foutloos geüpload, delivery UUID `c5a504a1-301a-4d64-841a-74841205ae50`. Verwerkt, gekoppeld aan Paskluis Testers en ingediend voor TestFlight-review.
- Officiële App Store-aanvraag ingediend op 4 oktober 2026 20:12 Amsterdam: **Waiting for Review**, bevestigd in App Store Connect. Aanvraag `5bcd789c-9e06-480b-9911-45f4bd6f88e2`. Dit is nog geen goedkeuring of openbare publicatie.
- De automatische reviewstap maakte door de Engelse releasenotitie een lege Engelse storelokalisatie aan en faalde op ontbrekende verplichte velden. Die onbedoelde lege lokalisatie is verwijderd; de bestaande Nederlandse pagina is daarna succesvol handmatig ingediend met build 137. `release_notes.json` bevat voortaan alleen de bestaande Nederlandse storetaal, zodat dit niet opnieuw gebeurt. Deze wijziging raakt de appbinary niet.
- iOS-build: https://codemagic.io/app/69f36f732d8b59f24897933a/build/6ac2943c7394575b200b0b6e
- Definitieve iOS-broncommit: `934788518da45c05df3d0a0d5c880cc00521a490`; GitHub-validatie geslaagd, run `37222646801`. Alleen `codemagic.yaml` verschilt van de Android-broncommit; appcode is identiek.
- De bestaande hoogste Apple-build was 136; het werkelijk geüploade nummer is 137. Publicatie na goedkeuring blijft handmatig.
- Niet-blokkerende native waarschuwingen voor vervolgonderhoud: iOS UIScene-lifecycle, Swift Package Manager-ondersteuning van ML Kit, Android Gradle Plugin en Kotlin-upgrades. Deze grote toolchainmigraties zijn niet tijdens de storebuild uitgevoerd.
