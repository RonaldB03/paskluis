# Externe serverback-up naar Google Drive

Status 4 oktober 2026: de dagelijkse koppeling is geïnstalleerd en actief op de VPS. De bestaande aangemelde `gdrive`-verbinding kon de juiste privémap bereiken. Alleen deze remote is gekopieerd naar een aparte configuratie voor de back-upservice. De eerste upload is geverifieerd op 4 oktober om 19:10 Europe/Amsterdam.

## Uitgevoerde eindcontrole

- `paskluis-offsite.timer`: enabled en active. Volgende geplande uitvoering volgens systemd: 4 oktober 23:04:21 CEST.
- Nieuwe kopie: `20261004T022214Z.pkb`, 10.607.700 bytes. De bron is de dagelijkse back-up van 4 oktober.
- Uploadcontrole: externe MD5 komt overeen met de lokale bytes. Daarna zijn het gedateerde manifest en `latest.json` gepubliceerd.
- Dezelfde kopie is opnieuw uit Google Drive gedownload. SHA-256: `8345bf69b43e9b2551d59eff5eff9e72b331dbe17641fba180cc61e0a11c4263`, gelijk aan het bronmanifest.
- De download is lokaal gecontroleerd met de aparte herstelsleutel: geauthenticeerde ontsleuteling, volledig archief, databaseheader en 190 opslagbestanden slagen.
- Configuratiemap mode 0700; rclone-configuratie mode 0600. Tien productiecontainers blijven healthy; geen herstart of wijziging van productiegegevens.
- Na expliciete toestemming is ook de logische databaseherstelproef geslaagd, op 4 oktober om 19:23 CEST: rollen en complete dump hersteld met foutcontrole, 15 accounts, 189 opslagverwijzingen, 190 opslagbestanden, 36 publieke tabellen met RLS, geen ongeldige indexen en de Vault-secret ontsleutelbaar. Container had geen netwerk, gepubliceerde poorten of productievolumes; cron stond uit. Testcontainer en alle tijdelijke ontsleutelde bestanden zijn daarna verwijderd. Bewijs: `audit-results/restore-result-20261004.json`.

De onderstaande eerste handmatige kopie blijft eveneens behouden:

- Map: https://drive.google.com/drive/folders/1K7mPH9sEAsTLTalN92QPZkrSoh6w7Off
- Kopie: `paskluis-server-20261002T204126Z.pkb`, 10.092.663 bytes.
- Drive-bestands-ID: `1QuFuCMQVkFmjh0atkD52iiztmJqNQmFm`.
- SHA-256 van het lokale bronbestand: `576b575016ef2595aa0a5ebdd14bdc13bed3d187838f4e32740cc585f93f9f36`.
- De lokale kopie is opnieuw succesvol ontsleuteld en gecontroleerd: databaseheader, archief en 190 opslagbestanden. De connector bevestigt de upload, grootte en privémap. Een download uit Drive met checksumvergelijking blijft onderdeel van de herstelproef.
- De private herstelsleutel is niet geüpload. Deze blijft buiten Git en buiten de VPS.

## Eenmalige aanmelding

Gebruik een eigen Google OAuth-client voor rclone. De actuele rclone-documentatie raadt die aan omdat de gedeelde client wordt uitgefaseerd. Maak op de VPS de rclone-remote `paskluis-drive` in `/etc/paskluis-drive/rclone.conf`. Gebruik het Google-account van de bovenstaande map. Stel `root_folder_id` op dat map-ID in. Voor deze al bestaande map is scope `drive` nodig; `drive.file` ziet alleen bestanden/mappen die rclone zelf heeft aangemaakt. De mapinstelling beperkt de gebruikte bestemming, niet de OAuth-rechten van het token. Een apart Google-account kan die rechten organisatorisch beperken.

Voer de interactieve aanmelding zelf uit; geef geen tokens of privésleutels in chat. Voor een server zonder browser beschrijft rclone een aanmelding via een andere computer. Bewaar de configuratie als root, mode 0600, in een directory met mode 0700. Bronnen: [Drive-configuratie](https://rclone.org/drive/) en [server zonder browser](https://rclone.org/remote_setup/).

## Installatie na aanmelding

Installeer rclone via de beheerde pakketbron. Voer vanuit de gecontroleerde repositorykopie op de VPS uit:

```sh
install -d -m 700 /etc/paskluis-drive /var/lib/paskluis-offsite
install -d -m 755 /opt/paskluis-supabase/tools/offsite
install -m 755 ops/drive_backup.py /opt/paskluis-supabase/tools/offsite/drive_backup.py
install -m 644 ops/paskluis-offsite.service /etc/systemd/system/paskluis-offsite.service
install -m 644 ops/paskluis-offsite.timer /etc/systemd/system/paskluis-offsite.timer
python3 /opt/paskluis-supabase/tools/offsite/drive_backup.py --check-local
systemctl daemon-reload
systemctl start paskluis-offsite.service
systemctl status paskluis-offsite.service
cat /var/lib/paskluis-offsite/status.json
```

Schakel de timer pas in nadat deze eerste upload én Drive-checksum geslaagd zijn:

```sh
systemctl enable --now paskluis-offsite.timer
systemctl list-timers paskluis-offsite.timer
```

De timer draait om 05:00, 11:00, 17:00 en 23:00 Europe/Amsterdam, met maximaal tien minuten spreiding. Hij herhaalt zo een mislukte overdracht. De bestaande versleutelde dagelijkse serverback-up van 04:15 blijft de bron. Een bron ouder dan dertig uur wordt geweigerd. Alleen `.pkb` plus een kleine manifestbeschrijving worden verzonden. Het script vergelijkt de lokale SHA-256 met het bestaande manifest en de externe MD5 met de lokale bytes. MD5 is hier transportcontrole; de herstelverificatie gebruikt SHA-256 en geauthenticeerde AES-GCM-ontsleuteling.

Er is geen `sync`, geen verwijderactie en geen upload van de private sleutel. Externe kopieën worden voorlopig bewaard; bepaal na de eerste herstelproef een expliciete bewaartermijn en bewaak Drive-capaciteit. Vier lokale unit-tests controleren onder andere dat een verkeerde externe checksum de publicatie van `latest.json` verhindert. Deze tests vervangen geen echte OAuth-/VPS-proef.

## Herstelprocedure en uitgevoerde proef

De logische databaseproef is uitgevoerd met `ops/restore_drill.py`. Belangrijke herstelvoorwaarde: initialiseer de lege cluster met `supabase_admin` als bootstraprol. PostgreSQL registreert roltoekenningen door superusers onder de bootstraprol; een anders genoemde tijdelijke beheerder kan de oorspronkelijke `GRANTED BY supabase_admin` niet correct terugzetten. De proef is na vaststelling hiervan opnieuw vanaf een lege cluster uitgevoerd. Bron: [PostgreSQL GRANT](https://www.postgresql.org/docs/17/sql-grant.html).

Deze proef bewijst databaseherstel en aanwezigheid van opslagreferenties. Een volledige mobiele gebruikerstest tegen een herstelde API-/Storage-stack is niet uitgevoerd.

Download een verse `.pkb` en het bijbehorende manifest naar een afgeschermde herstelomgeving. Vergelijk SHA-256, voer geauthenticeerde ontsleuteling uit met de apart bewaarde herstelsleutel en pak uit in een nieuwe directory. Gebruik hiervoor de bestaande `hardening-backup-verify.py` in de workspace; zet de gedownloade bestanden in een aparte `private-backups`-directory met een bijpassend `latest.json`.

Herstel de database logisch in een aparte Supabase/PostgreSQL-omgeving met dezelfde extensies en pgsodium-sleutel. Zet cronjobs en netwerkuitgaand verkeer uit; koppel geen productiedomeinen, push-, e-mail- of aankoopworkers. Controleer aantallen, accountrelaties, opslagverwijzingen en het openen van synthetische kaarten en foto’s. Leg begin/eindtijd, fouten, aantallen en controlequeries vast. Vernietig de geïsoleerde herstelomgeving pas nadat het bewijs is vastgelegd. Een succesvolle checksum of `PGDMP`-header alleen is nadrukkelijk geen geslaagde logische herstelproef.
