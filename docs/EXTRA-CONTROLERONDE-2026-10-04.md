# Extra controleronde — 4 oktober 2026

Controle van broncommit ba76110, voorafgaand aan verdere wijzigingen of nieuwe builds.

## Geslaagd

- Volledige Flutter-suite: 104 tests geslaagd. Bewijs: audit-results/final-control-tests.log.
- Server- en beheerregressies: 57 tests geslaagd. Bewijs: audit-results/final-control-server-tests.log.
- Back-upservice: 6 unit-tests geslaagd, inclusief corrupte/stale bron, checksumfout en beperkte retentieselectie.
- Toevoegscherm en back-upscherm inhoudelijk identiek aan referentie fb5da82 (1.5.2). Geen Tegoedbewaker-referenties in actieve appcode.
- Tien productiecontainers healthy, lokale en externe back-uptimer active; schijf 31% gebruikt, 337 GB vrij.
- Offsite-status ok, 14 dagen, laatste gecontroleerde kopie 20261004T022214Z.pkb. Er waren bij laatste uitvoering geen verlopen bestanden; echte toekomstige verwijdering is nog niet waargenomen.
- Nul publieke databasetabellen zonder RLS. Dit controleert inschakeling, niet afzonderlijk de juistheid van iedere policy.
- Notificatie-, locatiecache-, bezorglog-, aankoopreconciliatie- en supportretentietaken actief.
- Voorwaardenversie 2026-10-04 en hash komen overeen met de geregistreerde productierij.
- Publieke privacyverklaringen op paskluis.com en GitHub Pages antwoorden HTTP 200, noemen veertien dagen en bevatten geen oude bedrijfsnaam/KvK. Accountverwijderlink antwoordt HTTP 200.
- Google Play publicatieoverzicht na verversen: gesloten Alpha 1.5.3 wordt beoordeeld; beheerd publiceren aan. De aanvankelijk zichtbare 1.6.0 was verouderde tabinhoud.
- Google Play Data Safety: naam, e-mail en gebruikers-ID zijn geselecteerd; versleuteld transport en verwijderlinks ingevuld. Volledige doel-/deelclassificatie per categorie nog niet afgerond.

## Resterend vóór definitieve vrijgave

1. Apple App Privacy noemt zeven gegevenstypen en mist Naam, hoewel accountregistratie een naam verzendt. Correctie nodig.
2. De doeleinden, deelstatus en bewaaraanspraken in beide storeverklaringen verder per gegevenstype toetsen, inclusief support en cloudback-up.
3. De privacycorrecties van ba76110 zitten nog niet in iOS 138 / Android 99; nieuwe testbuilds nodig nadat resterende correcties gereed zijn.
4. Grondslagen en daadwerkelijke verwerkers-/doorgifteafspraken blijven onbevestigd; geen volledige juridische goedkeuring.
5. Losse migratie-/herstelbestanden buiten de dagelijkse back-upmappen apart inventariseren.
6. Fysieke iPhone-/Android-tests: upgrade met bestaande afbeeldingen, camera, biometrie, push en aankoop/herstel. Automatische tests bewijzen deze toestelinteracties niet.

Tijdens deze ronde zijn geen productiedata of storedeclaraties gewijzigd en geen nieuwe builds of reviews gestart. Alleen dit controleverslag is toegevoegd.
