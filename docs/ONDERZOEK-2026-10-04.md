**PasKluis technisch en productonderzoek**

Onderzoeksdatum: 4 oktober 2026. Mijn oordeel: PasKluis heeft een serieuze technische basis en een kansrijke combinatie van kaarten, cadeaukaartbeheer en hulp in de app. Ik zou de app op basis van dit onderzoek nog niet als volledig gecontroleerd of probleemloos presenteren. De grootste verbeteringen liggen nu bij betrouwbare gegevensverwerking, duidelijke privacyuitleg, herstelbaarheid en eenvoud bij de kassa.

Dit onderzoek betreft de lokale werkmap op branch codex/vps-production-cutover, commit 834b8d3, inclusief de reeds aanwezige ongecommitte wijzigingen. De projectversie is 1.5.2+43. Dit is geen bewijs dat precies deze broncode in de momenteel verspreide iOS- en Android-builds zit. Bestaande appcode is tijdens dit onderzoek niet gewijzigd.

**Wat daadwerkelijk is gecontroleerd**

| Onderdeel | Resultaat | Bewijskracht |
|---|---|---|
| Website en Auth-healthcheck | Beide HTTP 200 | Momentopname van bereikbaarheid |
| Openbare appinstellingen | Bereikbaar; aankopen aan, onderhoud uit, gratis limiet één cadeaukaart, minimumversies 1.0.0 | Live gecontroleerd met alleen GET-verzoeken |
| Winkelcatalogus | 153 actieve records ontvangen | Live openbare catalogus; geen maat voor herkenningskwaliteit |
| Zes geselecteerde privétabellen | Anonieme aanvragen leverden nul records | Positief, maar geen volledige controle tussen twee ingelogde accounts |
| Interne supportnotities | HTTP 400 op de geselecteerde query | Niet interpreteren als geslaagde autorisatiecontrole |
| Node-tests in ongewijzigde Windows-checkout | 32 geslaagd, 29 mislukt, totaal 61 | De fouten zaten in het verwerken van CRLF-regeleinden |
| Dezelfde tests met uitsluitend normalisatie bij het lezen van TypeScript | 61 geslaagd, nul mislukt | Geen appcode aangepast; testomgeving wijkt op dit ene punt af |
| Flutter-analyse en volledige Flutter-tests | Niet uitvoerbaar met de aanwezige SDK | Dart 3.11.5 kan de huidige afhankelijkheden niet oplossen |
| Gerichte Dart-reproducties | Locatievelden in back-up, OCR-datums en versiecontrole gereproduceerd | Exact geëxtraheerde pure functies; geen volledige Flutter-uitvoering |
| Echte toestellen en kassa | Niet getest | Camera, biometrie, storeaankopen, batterij, notificaties en scansnelheid blijven open |

De Node-tests bevatten onder meer aankoopverificatie, terugbetalingsverwerking, notificatieworkers, back-upprotocol, MFA en adminfunctionaliteit. Een deel gebruikt mocks. De lokale SQL-test voor supportinstellingen gebruikt PGlite met vereenvoudigde Auth/MFA-functies. Dit vervangt geen volledige test van productierechten. De losse SQL-regressies zijn niet integraal tegen een geïsoleerde kopie van het volledige productieschema gedraaid.

Bewijs: [oorspronkelijke testuitvoer](C:/Users/Gebruiker/Documents/ChatGPT/PasKluis/app-fix/audit-results/node-tests-original.txt), [tests met genormaliseerde regeleinden](C:/Users/Gebruiker/Documents/ChatGPT/PasKluis/app-fix/audit-results/node-tests-lf.txt), [gerichte Dart-reproducties](C:/Users/Gebruiker/Documents/ChatGPT/PasKluis/app-fix/audit-results/extracted-checks.txt) en [publieke controles](C:/Users/Gebruiker/Documents/ChatGPT/PasKluis/app-fix/audit-results/public-checks.json).

**Wat al goed is**

Kaartrecords worden met een willekeurige sleutel versleuteld in Hive opgeslagen; de sleutel staat in beveiligde toestelopslag. De code bewaart de herkende barcodesoort, zodat niet uitsluitend op basis van het aantal cijfers wordt gegokt. Scanner- en schermhelderheidslogica hebben afzonderlijke tests. Er is aandacht voor toestelwissels, accountwissels en het verwijderen van ontvangen kaarten bij uitloggen.

Het appslot omsluit de complete Navigator, zodat een geopend detailscherm niet simpelweg buiten het slot valt. Android zet FLAG_SECURE. De backend controleert voor gevoelige onderdelen actieve sessies; beheerdersrechten vereisen in de onderzochte migraties MFA. Aankopen worden bij Apple of Google gecontroleerd en aan een account gekoppeld. Dit zijn goede ontwerpkeuzes, geen volledige veiligheidsgarantie.

Back-ups zijn expliciet optioneel, versleuteld met AES-GCM, hebben versiegeschiedenis en beschermen tegen het direct overschrijven van een bestaande cloudgeschiedenis op een nieuwe installatie. De actuele back-upinterface benoemt terecht dat PasKluis de sleutels beheert en dat dit geen end-to-endversleuteling is. Ontvangen gedeelde kaarten worden niet als eigen kaarten geback-upt.

**Concrete verbeterpunten in volgorde van belang**

1. **De privacyuitleg spreekt zichzelf tegen. Hoge prioriteit, bevestigd in de code.** Het privacyscherm beschrijft cloudback-up, maar toont verderop nog de tekst “PasKluis biedt nog geen cloudback-up”. De README zegt daarnaast dat kaartgegevens niet naar een externe server worden verstuurd, terwijl delen en optionele back-up bestaan. Gebruikers moeten één consistente uitleg krijgen over lokale kaarten, gedeelde kaarten, cloudback-up en serverherstel. De huidige back-upuitleg is inhoudelijk nuttig; trek de overige teksten daarmee gelijk. Bronnen: [privacytekst](C:/Users/Gebruiker/Documents/ChatGPT/PasKluis/app-fix/lib/l10n/app_nl.arb:1013), [privacyscherm](C:/Users/Gebruiker/Documents/ChatGPT/PasKluis/app-fix/lib/features/settings/privacy_screen.dart:87) en [README](C:/Users/Gebruiker/Documents/ChatGPT/PasKluis/app-fix/README.md).

2. **Opgeslagen gebruikslocaties gaan mee in een ingeschakelde back-up. Hoge prioriteit, gereproduceerd.** De lokale kaart bewaart lastUsedLatitude, lastUsedLongitude en locationRecordedAt. De back-upfilter verwijdert die velden niet. Dit is een laatste gebruikslocatie per kaart, geen bewezen volledige bewegingshistorie. De privacyinterface plaatst deze locaties onder wat op de telefoon blijft. Verwijder die velden uit back-ups of maak hiervoor een expliciete, goed uitgelegde keuze. Omdat de server de herstelsleutels beheert, is “versleuteld” niet hetzelfde als “onleesbaar voor de aanbieder”. Bronnen: [locatieopslag](C:/Users/Gebruiker/Documents/ChatGPT/PasKluis/app-fix/lib/data/services/location_service.dart:91) en [back-upfilter](C:/Users/Gebruiker/Documents/ChatGPT/PasKluis/app-fix/lib/data/services/backup_codec.dart:20).

3. **Een gearchiveerde ontvangen cadeaukaart kan weer actief worden. Middelhoge prioriteit, bevestigd door de codepaden.** Bij synchronisatie wordt isArchived op false gezet. Alleen de bestaande favorietstatus wordt expliciet meegenomen. De cadeaukaartinterface kan kaarten archiveren nadat het saldo is opgebruikt. Bij de volgende geslaagde synchronisatie kan een ontvangen kaart daardoor terugkomen en kunnen herinneringen opnieuw worden ingepland. Bewaar persoonlijke organisatievelden onafhankelijk van de gedeelde inhoud. Bronnen: [synchronisatie](C:/Users/Gebruiker/Documents/ChatGPT/PasKluis/app-fix/lib/data/services/card_share_service.dart:198) en [archiveren](C:/Users/Gebruiker/Documents/ChatGPT/PasKluis/app-fix/lib/features/gift_cards/gift_card_view_screen.dart:597). Nog op twee testaccounts reproduceren in de volledige app.

4. **Een lokale favorietactie kan afhankelijk worden van internet. Middelhoge prioriteit, bevestigd door de codepaden.** Favoriet maken gebruikt bij cadeaukaarten dezelfde opslaanroute als inhoudelijke wijzigingen. Voor een eigen gedeelde kaart of een bewerkbare ontvangen kaart wacht die route eerst op updateSharedCard. Zonder verbinding kan daardoor ook een persoonlijke favorietactie falen. Splits lokale voorkeuren af van gedeelde gegevens, en geef inhoudelijke offline wijzigingen een duidelijke wachtrij of foutmelding. Bron: [opslaan en favorieten](C:/Users/Gebruiker/Documents/ChatGPT/PasKluis/app-fix/lib/features/gift_cards/gift_card_view_screen.dart:139).

5. **OCR kan een verkeerde vervaldatum voorstellen. Middelhoge prioriteit, gereproduceerd.** “Aankoopdatum 04-10-2026” wordt als vervaldatum 4 oktober 2026 geïnterpreteerd. “Geldig tot 31-02-2027” wordt 3 maart 2027. De eerste datumregex maakt het label optioneel; DateTime normaliseert vervolgens ongeldige kalenderdatums. De gebruiker heeft een controlescherm, dus dit is geen bewijs van onzichtbare automatische opslag. Toch is het een fout voorstel dat onjuiste herinneringen kan veroorzaken. Vereis een vervallabel of toon een onzekere suggestie, en controleer of jaar, maand en dag na conversie gelijk blijven. Bron: [datumherkenning](C:/Users/Gebruiker/Documents/ChatGPT/PasKluis/app-fix/lib/data/services/smart_card_import_service.dart:162).

6. **De updatecontrole gebruikt een verouderd versienummer. Middelhoge prioriteit, gereproduceerd.** SettingsService bevat 1.5.0 terwijl het project 1.5.2 is. Wanneer minimum_ios_version of minimum_android_version naar 1.5.2 gaat, kan een actuele app een foutieve melding krijgen. De live minimumversies stonden tijdens deze controle nog op 1.0.0: dit probleem veroorzaakt op dit moment dus niet automatisch die melding. Gebruik de daadwerkelijk geïnstalleerde pakketversie. Bron: [versiecontrole](C:/Users/Gebruiker/Documents/ChatGPT/PasKluis/app-fix/lib/data/services/settings_service.dart:219).

7. **Extra duidelijk kan grote systeemtekst juist verkleinen. Middelhoge prioriteit, bevestigd in de berekening.** De factor wordt begrensd tot 1,6. Bij een systeeminstelling van 200% of 300% wordt daarmee respectievelijk 160% toegepast. Dat werkt tegen de bedoeling van toegankelijkheid. Respecteer de systeeminstelling en test de volledige navigatie met grote tekst, VoiceOver en TalkBack. Bron: [tekstschaling](C:/Users/Gebruiker/Documents/ChatGPT/PasKluis/app-fix/lib/main.dart:297).

8. **Het bouwproces is onvoldoende reproduceerbaar. Hoge prioriteit voor verdere releases.** De aanwezige Dart-versie is 3.11.5, maar google_mlkit_text_recognition 0.17.1 vereist minimaal Dart 3.12; het lockbestand noemt eveneens Dart >=3.12 en Flutter >=3.44. De README beschrijft nog Dart 3.11 of hoger. CI gebruikt een verschuivende stable-versie. Bovendien staat de huidige branch niet in de pushfilter van release-validation en ontbreekt daar een pull_request-trigger. De analyse laat waarschuwingen niet falen. Leg één passende Flutter-versie vast, corrigeer de minimumvereisten en laat wijzigingen op de actieve ontwikkeltakken automatisch valideren. Dit betekent niet dat de bestaande storebuild bewezen kapot is. Bronnen: [lockbestand](C:/Users/Gebruiker/Documents/ChatGPT/PasKluis/app-fix/pubspec.lock), [CI](C:/Users/Gebruiker/Documents/ChatGPT/PasKluis/app-fix/.github/workflows/release-validation.yml:4) en [buildconfiguratie](C:/Users/Gebruiker/Documents/ChatGPT/PasKluis/app-fix/codemagic.yaml:11).

9. **De tests zijn gevoelig voor Windows-regeleinden. Middelhoge prioriteit, experimenteel aangetoond.** Diverse testbestanden verwijderen imports met een regex die alleen LF accepteert. In deze CRLF-checkout blijven imports staan, waardoor het uitvoeren van de getransformeerde code faalt. Na normalisatie slagen alle 61 tests. Los dit structureel op in het testharnas of met consistente bronregeleinden. De gebruikte Node 24.14.1 ligt bovendien iets onder de opgegeven minimumversie van jsdom 30.1.1; de tests slaagden, maar zet ook Node vast op een ondersteunde versie. De npm-installatie meldde nul bekende kwetsbaarheden voor deze 39 adminpakketten; dat zegt niets over de volledige mobiele afhankelijkheden.

10. **Herstel na verlies van de server is nog onvoldoende aangetoond. Hoge operationele prioriteit, gebaseerd op het bestaande onderhoudsverslag.** Het verslag van 2 oktober vermeldt dagelijkse versleutelde serverback-ups en een gecontroleerde lokale kopie, maar nog geen automatische externe dagelijkse opslag en geen volledige logische hersteloefening. Dit is tijdens deze audit niet opnieuw op de VPS geïnspecteerd. Controleer de actuele situatie en richt een onafhankelijke bestemming plus een hersteltest in. Een back-up op dezelfde server beschermt onvoldoende tegen verlies van die server. Bron: [onderhoudsverslag](C:/Users/Gebruiker/Documents/ChatGPT/PasKluis/PRODUCTIE-OMZETTING.md:38).

**Belangrijke ontwerpkeuzes om expliciet te maken**

Eigen afbeeldingen worden gekopieerd naar de appmap, zonder dezelfde applicatieversleuteling als de Hive-records. De privacyschermtekst noemt hiervoor al toestelbeveiliging; het is dus geen bewezen ongedocumenteerd lek. Voor een product met de naam Kluis zou ik ook kaartfoto’s versleutelen, zeker wanneer ze een barcode of krascode kunnen bevatten. Bron: [afbeeldingsopslag](C:/Users/Gebruiker/Documents/ChatGPT/PasKluis/app-fix/lib/data/services/media_storage_service.dart:31).

Gedeelde kaartinhoud, inclusief eventuele pincode, wordt naar de backend gestuurd. De gebruiker krijgt daarvoor een bevestiging. Intrekken van toegang verwijdert geen eerder overgeschreven nummer of foto en kan een offline toestel pas na synchronisatie bereiken. Leg de grenzen van intrekken uit. Er is geen basis om te claimen dat een ingetrokken, reeds gekopieerde cadeaukaart daardoor bij de winkel onbruikbaar wordt.

Eén actieve accountsessie per toestelbeleid is een bewuste beperking. Dat vereenvoudigt een deel van de beveiliging, maar beperkt gebruik op telefoon én tablet. Back-up/herstel is ook iets anders dan continue synchronisatie tussen eigen apparaten. Maak de belofte in de interface precies.

De back-upgrens is 10 MB voor maximaal drie versies samen. Afbeeldingen worden tot 1600 pixels teruggebracht en als PNG opgeslagen. Dat kan bij foto’s relatief veel ruimte kosten. Toon vooraf welke afbeeldingen de ruimte innemen, en voorkom dat één ontbrekende foto ongemerkt langdurig alle nieuwe back-ups blokkeert.

Firebase wordt vóór runApp geïnitialiseerd zonder omvattende foutafhandeling. Lokale notificaties worden eveneens tijdens de verplichte opstartketen geïnitialiseerd. Dit is een te testen storingsrisico: een fout in een optionele dienst moet het openen van lokale kaarten niet verhinderen. Er is geen opstartcrash op een echt toestel gereproduceerd.

De openbare winkelzoekfunctie heeft budgetcontrole, caching en begrensde gelijktijdigheid. Uit de functie zelf volgt geen afzonderlijke limiet per gebruiker of IP. Controleer of de proxy dat afdwingt, zodat één partij het gezamenlijke dagbudget niet kan opmaken. Tijdens deze audit zijn geen betaalde Places-opvragingen of belastingsproeven uitgevoerd.

De hoofdpagina gaf geen HSTS- of CSP-header terug. Dit is een aanvullende websiteverbetering, geen bewijs van een kwetsbaarheid in de mobiele app. Beoordeel de headers apart voor website, beheerportaal en API.

**Mijn mening over de gebruikerservaring**

De code biedt veel bruikbare functies: zoeken, favorieten, categorieën, cadeaukaartsaldo, saldohistorie, vervalherinneringen, schermhelderheid, screenshotimport en ondersteuning. De uitdaging is om de hoofdtaak eenvoudig te houden: een gebruiker wil bij de kassa onmiddellijk de juiste code zien.

De huidige toevoegroute laat eerst een kaarttype kiezen en daarna de invoermethode. Mijn voorstel is één primaire actie “Scan kaart”, met automatische herkenning en een korte controle achteraf. Houd handmatige invoer direct bereikbaar. Batchimport bestaat voor QR-afbeeldingen, maar een duidelijke migratieroute voor een volledige verzameling klantenkaarten is in de onderzochte flow niet aangetroffen.

Maak de startweergave voorspelbaar. Dynamisch gesorteerde kaarten mogen niet verspringen terwijl iemand erop tikt. Meet op echte, ook oudere toestellen de tijd van openen tot scanbare code. Streef als productdoel naar een lokale kaart die binnen één seconde bruikbaar is; dit is een voorgesteld doel, geen gemeten prestatie.

Voeg eerst een goede widget of directe snelkoppeling toe. In deze broncode zijn geen Apple Watch/Wear OS-app of native homescreenwidgets aangetroffen. PDF417, Aztec en Data Matrix ontbreken in de onderzochte scanformaten. Beloof daarom geen universele ticketondersteuning zolang die formaten en dynamische codes niet worden ondersteund en getest.

Een zichtbare status “laatst succesvol geback-upt” met een rustige melding bij langdurig falen geeft meer vertrouwen dan alleen een instelling die aanstaat. Houd account, Plus en ondersteuning achter de hoofdtaak; haal hun functies naar voren wanneer de gebruiker ze nodig heeft. Een volledige visuele beoordeling van schermen, contrast en animaties blijft afhankelijk van een werkende toestelbuild.

**Vergelijking met andere apps**

| Aspect | PasKluis in deze audit | Concurrentie en betekenis |
|---|---|---|
| Snelle klantenkaartportemonnee | Offline opslag, scannen, zoeken en favorieten aanwezig in code | SuperCards profileert zich expliciet op snelheid, gratis gebruik en geen advertenties; snelheid is een basisverwachting |
| Import | Screenshot/OCR en meerdere QR-afbeeldingen | SuperCards documenteert overstappen via screenshots; dit is geen exclusieve feature |
| Catalogus | 153 actieve publieke records | SuperCards claimt 4000+ sjablonen; omvang zegt niet alles, maar internationale dekking vraagt werk |
| Widgets en horloges | Niet aangetroffen | SuperCards documenteert widgets, Apple Watch en Wear OS; Catima documenteert Wear OS |
| Privacy en herstel | Lokale versleuteling, optionele eigen backend, door PasKluis beheerde back-upsleutels | Catima documenteert volledig offline gebruik en export/import met optionele wachtwoordbescherming |
| Slimme aanbevelingen | Nabijgelegen winkels en opgeslagen gebruikslocaties | SuperCards documenteert aanbevelingen op basis van lokaal verwerkte gebruikspatronen en locatie; alleen locatie is geen unieke positionering |
| Samen cadeaukaarten beheren | Rechten, versies, saldo en historie aanwezig | Kansrijke focus voor PasKluis; deze audit bewijst niet dat andere apps dit nergens aanbieden |
| Gratis alternatief | Eén actieve eigen cadeaukaart gratis volgens live instelling | Gratis alternatieven verhogen de noodzaak om de meerwaarde van Plus concreet te tonen |

De concurrentiegegevens komen uit hun eigen officiële documentatie; de apps zijn niet op hetzelfde toestel naast elkaar gemeten. Marketingclaims over snelheid, veiligheid en gebruikersaantallen zijn geen onafhankelijke benchmarks. Gebruikte bronnen: [SuperCards](https://supercardsapp.com/nl), [SuperCards functies](https://help.supercardsapp.com/nl/article.html?category=getting-started&id=3), [SuperCards slimme aanbevelingen](https://help.supercardsapp.com/nl/article.html?category=managing-cards&id=14), [Catima FAQ](https://catima.app/faq/) en [Catima wijzigingen](https://catima.app/changelog/).

Google Wallet ondersteunt ook klanten- en cadeaukaarten. Daarmee concurreert PasKluis bovendien met een algemene portemonnee die gebruikers mogelijk al hebben. Een aantrekkelijkere vormgeving alleen zal niet voor iedereen een extra app rechtvaardigen. Bron: [Google Wallet Help](https://support.google.com/wallet/answer/12059603?hl=en).

Mijn productadvies is daarom: kies voor mensen die cadeaukaarten vergeten, onduidelijk saldo hebben of kaarten met hun huishouden beheren. Bied hun een aantoonbaar betere oplossing. Ik zou geen algemene claim maken dat PasKluis nu beter is dan SuperCards. Voor alleen snel een klantenkaart tonen heeft SuperCards volgens zijn documentatie een breder pakket. Voor persoonlijk cadeaukaartbeheer kan PasKluis een overtuigende eigen plek ontwikkelen.

**Voorstel voor een onderscheidende feature**

Mijn voorkeur is **PasKluis Tegoedbewaker**: één samenhangende ervaring die voorkomt dat bruikbaar tegoed wordt vergeten.

Bij een winkel ziet iemand naast de klantenkaart: “Je hebt hier nog ongeveer € 23,50 cadeaukaarttegoed. Laatst bijgewerkt op 28 september. Vervalt over 12 dagen.” Eén actie opent eerst de klantenkaart en daarna de relevante cadeaukaart. Na gebruik kan de gebruiker met één bevestiging het uitgegeven bedrag vastleggen. De datum en betrouwbaarheid van het saldo blijven zichtbaar.

Bouw dit eerst voor eigen kaarten: combinatie per winkel, vervalprioriteit, handmatig bevestigd saldo, rustige herinneringen en een overzicht van werkelijk geregistreerd gebruik. Gebruik de bestaande gegevens; vraag geen extra persoonsgegevens die hiervoor niet nodig zijn.

Een volgende stap is een huishoudfunctie waarbij iemand kan aangeven “ik gebruik deze kaart nu”. Zo’n reservering is een afspraak in PasKluis, geen blokkade bij de winkel. Laat wijzigingen en conflicten duidelijk zien. Hiervoor moet de synchronisatie eerst betrouwbaar zijn en moet het toestelbeleid passend worden gemaakt.

Automatisch saldo ophalen vereist per winkel een legitieme integratie. Zonder die koppeling mag PasKluis niet suggereren dat een saldo live of gegarandeerd juist is. Ook een telling van “gered geld” mag niet gelijk zijn aan al het geïmporteerde tegoed: tel hoogstens door de gebruiker bevestigd gebruik en benoem de definitie.

Deze combinatie lijkt een goede onderscheidingsrichting. Dat is een producthypothese, geen bewezen exclusiviteit of claim dat niemand dit al aanbiedt. Test haar met gebruikers tegenover de simpele vraag: helpt dit aantoonbaar om tegoed te gebruiken dat zij anders vergeten?

**Praktische volgorde**

| Moment | Werk | Wanneer geslaagd |
|---|---|---|
| Voor een volgende brede release | Privacytekst, back-uplocaties, gedeelde archivering, lokale favorieten, OCR-datums, versiebron, tekstschaling | Gerichte regressies slagen en gedrag is op toestel bevestigd |
| Voor betrouwbare verdere ontwikkeling | Flutter en Node vastzetten, Windows-tests repareren, CI op actieve branches/PR’s | Eén schone checkout levert herhaalbare analyse en tests |
| Voor meer productiegebruik | Externe back-up, complete hersteloefening, zichtbare back-upfouten | Synthetisch account en afbeeldingen aantoonbaar teruggezet in aparte omgeving |
| Eerstvolgende productverbetering | Kortere scanroute, widget/snelkoppeling, heldere saldodatum | Gebruikersonderzoek toont minder handelingen en geen nieuwe verwarring |
| Daarna | Tegoedbewaker, vervolgens eventueel huishoudgebruik | Meetbaar gebruik, terugkeer en lagere foutlast |
| Pas daarna | Brede internationale catalogus en horlogeapps | Gebruikersvraag en onderhoudscapaciteit rechtvaardigen uitbreiding |

De zichtbare prijscommunicatie is € 1,99 eenmalig. Dat is toegankelijk, maar de server, back-ups, locatieaanvragen en menselijke ondersteuning blijven kosten veroorzaken. Maak daarom eerst inzichtelijk wat een actieve gebruiker structureel aan opslag, verkeer, Places-opvragingen en support vraagt. Een onbeperkte levenslange belofte verdient duidelijke productgrenzen. Dit is een productafweging, geen berekende winstprognose.

**Resterende toesteltest voor een volledige uitspraak over werking**

- iPhone én Android: koude start in vliegtuigstand, backend onbereikbaar en notificatietoestemming geweigerd.
- Barcodes: alle ondersteunde typen, voorloopnullen, lange codes, gedraaide foto's en echte kassascanners.
- Camera/import: weigeren en later toestaan, app tijdelijk verlaten, weinig geheugen, beschadigd beeld en annuleren.
- Toegankelijkheid: kleine schermen, 200% en 300% tekst, VoiceOver/TalkBack, landschap en contrast.
- Appslot: verkeerde biometrie, annuleren, toestelcode, terugkomen uit achtergrond en open dialoogvensters.
- Accounts: e-mailbevestiging, verlopen herstelcode, offline uitloggen, wisselen tussen twee accounts en overname op een tweede toestel.
- Delen: twee gebruikers tegelijk bewerken, offline ontvangen toestel, intrekken, archiveren en verlopen Plus.
- Aankopen: Apple/Google sandbox, annuleren, pending, verificatie-uitval, herstellen, terugbetaling en verkeerde accountkoppeling.
- Back-up: quota vol, ontbrekende foto, onderbroken upload, nieuwe installatie, iOS naar Android en andersom, accountwissel en conflicten.
- Meldingen: vervaldata, toestelherstart, app afgesloten, zomer/wintertijd en tikken op een melding.
- Herstel server: metadata, sleutels en opslag als één consistente kopie terugzetten; controleer zonder echte klantenberichten te versturen.
- Prestaties: verzamelingen van 100 en 500 kaarten, opstarttijd, scrollen, geheugengebruik en netwerkverkeer.

Tot die controles zijn afgerond is de juiste conclusie: de onderzochte logica heeft meerdere sterke beschermingen en de uitvoerbare backendtests slagen, maar niet alle appfuncties zijn in hun echte gebruiksomgeving bewezen.

