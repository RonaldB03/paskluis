# Android 1.9.0 — voorbereiding 8 oktober 2026

## Release

Dezelfde cadeaukaart-, QR-deel- en verwijderfuncties als iOS 1.9.0. Android krijgt een eigen Google Play Services-geofenceontvanger met optionele achtergrondlocatie. Geen doorlopende locatiepolling en geen foregroundservice. Maximaal twintig opgeslagen winkels, circa 100 meter, maximaal eenmaal per winkel per 24 uur, automatisch verlopen na maximaal zeven dagen of de vervaldatum. Een melding opent het cadeaukaartenoverzicht. Meldingen hebben een afgeschermde weergave op het vergrendelscherm; saldo kan apart uit.

De functie vraagt eerst uitleg en toestemming, vervolgens meldingsrechten en locatie tijdens gebruik, daarna afzonderlijk achtergrondlocatie via telefooninstellingen (Android 11+) of toestemmingsdialoog (Android 10). Exacte locatie en Google Play Services zijn nodig. Bij geweigerde toestemming blijven kaarten bruikbaar. Geen kaartcode, pincode of accountgegevens worden naar de native monitor gestuurd. Na een herstart worden alleen opgeslagen, nog geldige winkels geregistreerd.

## Google-status

Op 8 oktober toont het dashboard: 12 testers, 13 opeenvolgende dagen. Productietoegang is nog niet beschikbaar. Testers moeten aangemeld blijven. Na 14 dagen kan de aanvraag voor productietoegang worden beoordeeld; dit is geen automatische toestemming voor publicatie.

## Achtergrondlocatieverklaring — tekst voor Google

Hoofddoel: klantenkaarten, QR-codes en cadeaukaarten bewaren en gebruiken. De optionele functie Cadeaukaart bij een winkel herinnert gebruikers aan een nog beschikbare cadeaukaart wanneer zij een bijbehorende winkel naderen, ook wanneer PasKluis gesloten is. Zonder achtergrondlocatie kan die aankomst niet worden gedetecteerd wanneer de gebruiker de app niet opent. De gebruiker schakelt dit apart in, ziet eerst een prominente uitleg en kan weigeren of later uitschakelen. Android bewaakt maximaal twintig opgeslagen winkelgebieden en verstuurt lokale meldingen. Geen aankomstgeschiedenis wordt naar de PasKluis-server gestuurd. Saldi zijn handmatig bijgehouden.

Google kan deze toepassing afzonderlijk beoordelen; goedkeuring is niet gegarandeerd. Vereist vóór indienen: echte demonstratievideo en actuele privacyverklaring/locatieverklaring. De bestaande appdata-verklaring moet op basis van de werkelijke verwerkingen worden gecontroleerd.

## Video door Ronald

Gebruik een eigen cadeaukaart zonder echte waarde of gevoelige code en een Android-toestel met Google Play Services. Zet de winkelmeldingen eerst uit.

1. Open Instellingen > Scherm en meldingen > Cadeaukaart bij een winkel.
2. Toon de volledige uitleg over locatie bij gesloten app en tik Inschakelen.
3. Toon meldings- en locatietoestemming. Kies exacte locatie, daarna Altijd toestaan in de app-instellingen en keer terug.
4. Open de app nabij een bijbehorende winkel om de winkels te verversen. Ga terug naar het startscherm van Android. Laat de echte winkelmelding zien en tik erop: het cadeaukaartenoverzicht opent.

Android kan de melding enkele minuten later tonen; 100 meter is geen exacte garantie. Voor een herhaalde proef geldt de 24-uursgrens. Maak geen fictieve melding. De beveiligde app kan schermopname blokkeren: film zo nodig het toestel met een tweede telefoon. Publiceer de opname zonder persoonsgegevens op een voor Google bereikbare videolink. Google adviseert een korte demonstratie van circa 30 seconden; knip wachttijd weg zonder de toestemmingsstappen of werking te verhullen.

## Voor productie

Test op toestel: delen QR/klantenkaart, verwijderen gedeelde cadeaukaart, Android-aankoop en herstellen, weigeren/uitschakelen meldingen, terugkeer uit toestemmingsinstellingen, echte winkelmelding, openen vanuit melding en geen herhaalde melding binnen 24 uur. Noteer echte feedback en uitgevoerde aanpassingen. Vul de productievragen uitsluitend met die werkelijke resultaten in.

Bronnen: https://support.google.com/googleplay/android-developer/answer/14151465 en https://support.google.com/googleplay/android-developer/answer/9799150

## Testers — door Ronald bevestigd

Geworven onder eigen bekenden, die enthousiast waren over het idee en vrijwillig wilden helpen testen. Welke functies daadwerkelijk zijn getest en concrete feedback zijn nog niet aangeleverd. Ronald kan de Android-test en demonstratievideo uitvoeren. Geen inhoudelijke testervaringen namens testers invullen zonder bevestiging.

## Uitvoering

Codemagic-build 6ac76079de4f6899ca0d249e (Android Test Build, bron 77a213b) is gestart. Flutter-codecontrole en tests zijn geslaagd. Het gekozen versionCode is 103 (bestaande hoogste code: 102). Native compileerresultaat en upload zijn nog niet bevestigd. Privacy- en verwijderlinks zijn op paskluis.com gezet en ter beoordeling ingediend. De eerdere goedgekeurde release 1.8.0 is niet gepubliceerd door deze handeling. De privacywebpagina's NL/EN zijn bijgewerkt voor Android-winkelmeldingen.

Ronald bevestigt daarnaast dat de testers alle toen beschikbare functies hebben getest. Verschillende gebruikers kregen gerichte opdrachten, waaronder kaarten met elkaar delen. Hun testervaringen hebben tot opeenvolgende updates geleid. Specifieke feedbackcitaten of aantallen problemen zijn niet aangeleverd. De nieuwe Android-achtergrondmeldingen vallen niet onder deze al afgeronde testbevestiging.

Voorstel werving: 'Ik heb testers geworven onder mijn eigen bekenden. Zij waren enthousiast over het idee achter PasKluis en wilden vrijwillig helpen testen.'
Voorstel betrokkenheid: 'Ik heb verschillende testers gerichte testopdrachten gegeven, waaronder het onderling delen van kaarten. Volgens mijn terugkoppeling hebben zij alle toen beschikbare functies getest. De ervaringen tijdens deze tests hebben geleid tot meerdere updates.'



Plus gecontroleerd in Google Play: paskluis_plus / plus-lifetime actief, Nederland beschikbaar, eenmalig EUR 1,99.
