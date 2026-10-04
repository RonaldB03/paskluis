# Herstelproef — uitgevoerd na expliciete toestemming

Resultaat 4 oktober 2026, 19:23 Europe/Amsterdam: logische rollen- en databaserestore geslaagd. 15 accounts, 189 opslagverwijzingen, 190 bestanden, 36 publieke tabellen met RLS en één leesbare Vault-secret. Geen ongeldige indexen. De testcontainer had geen netwerk of productievolumes; cron stond uit. De testcontainer, testdata en ontsleutelde archieven zijn op de VPS en lokaal verwijderd. Versleutelde back-ups en private herstelsleutel zijn behouden. Zie `audit-results/restore-result-20261004.json`.

Doel: bewijzen dat de uit Google Drive teruggehaalde serverback-up logisch te herstellen is, naast de reeds geslaagde checksum-, ontsleutelings- en archiefcontroles.

Bron: `20261004T022214Z.pkb`, SHA-256 `8345bf69b43e9b2551d59eff5eff9e72b331dbe17641fba180cc61e0a11c4263`.

Uitgevoerde handelingen:

1. Ontsleutel de gecontroleerde kopie lokaal. De private RSA-herstelsleutel blijft lokaal.
2. Verstuur het ontsleutelde archief via SSH naar een tijdelijke map met mode 0700 op de eigen VPS `217.154.75.81`. Het archief bevat gevoelige database-, opslag- en configuratiegegevens; dit creëert tijdelijk een extra leesbare kopie op die server.
3. Herstel in een afzonderlijke Docker-container met de reeds aanwezige, gepinde PostgreSQL-image. Gebruik een nieuw testvolume, geen productiemounts, geen gepubliceerde poorten, `--network none` en uitgeschakelde cronjobs. Start geen mail-, push- of aankoopworkers.
4. Controleer rollen, schema, aantallen, constraints, opslagverwijzingen en ontsleutelbaarheid van bewaarde gegevens. Leg alleen aantallen, status en foutcategorieën vast; geen gebruikersgegevens of secrets in het verslag.
5. Stop de testcontainer. Verwijder uitsluitend de voor deze proef aangemaakte container, volumes en ontsleutelde tijdelijke bestanden na controle van hun exacte identiteit. Behoud de versleutelde back-up en het verificatieverslag.

De automatische goedkeuringscontrole vroeg aanvankelijk om expliciete toestemming voor stap 2. De gebruiker heeft die vervolgens verleend met “ja dat mag”. Daarna is de proef uitgevoerd en opgeruimd. De actieve dagelijkse Drive-back-up bleef werken. De proef omvatte databaseherstel en opslagreferenties, geen volledige app-/API-gebruikstest.
