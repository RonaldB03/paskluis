#!/usr/bin/env bash
# Import only into the isolated VPS staging stack, never into Cloud.
set -Eeuo pipefail
umask 077
[[ $EUID == 0 ]] || { echo 'Run as root.'; exit 1; }
TARGET=/opt/paskluis-supabase
BACKUP=${1:?Supply the completed cloud snapshot directory}
[[ "$BACKUP" == /var/backups/paskluis-supabase/cloud-* ]] || exit 1
[[ -f "$TARGET/.paskluis-upstream-version" && -f "$BACKUP/manifest.json" ]] || exit 1
[[ ! -e "$TARGET/.paskluis-import-complete" ]] || { echo 'Import already completed; refusing to repeat.'; exit 1; }
cd "$BACKUP"
sha256sum --check SHA256SUMS
cd "$TARGET"
db() { docker compose exec -T db psql -X -U postgres -d postgres -v ON_ERROR_STOP=1 "$@"; }
[[ $(db -At -c 'select count(*) from auth.users;') == 0 ]] || { echo 'Destination has accounts; refusing to overwrite.'; exit 1; }
[[ $(db -At -c "select count(*) from information_schema.tables where table_schema='public' and table_type='BASE TABLE';") == 0 ]] || { echo 'Destination has app tables; refusing to overwrite.'; exit 1; }
WORK="$BACKUP/staging-import"
mkdir -p "$WORK"
db -At -c "select coalesce(jsonb_agg(jsonb_build_object('schema',table_schema,'table',table_name,'column',column_name)), '[]'::jsonb) from information_schema.columns where table_schema in ('auth','storage','vault');" >"$WORK/catalog.json"
python3 - "$BACKUP" "$WORK" <<'PY'
import json, re, sys
from pathlib import Path
backup, work = map(Path, sys.argv[1:])
manifest = json.loads((backup/'manifest.json').read_text())
assert manifest['source_project'] == 'ajldblvvlbvmgejrmhyj'
catalog = {}
for c in json.loads((work/'catalog.json').read_text()):
    catalog.setdefault(c['schema']+'.'+c['table'], set()).add(c['column'])
lines = (backup/'data.sql').read_text().splitlines(keepends=True)
result, skipped, i = [], [], 0
while i < len(lines):
    line = lines[i]
    if not line.startswith('COPY '):
        result.append(line); i += 1; continue
    m = re.fullmatch(r'COPY (\S+) \((.+)\) FROM stdin;\n?', line)
    if not m:
        raise SystemExit('Unsupported COPY statement. Stop before importing.')
    table = m.group(1).replace('"', '')
    columns = [c.strip().strip('"') for c in m.group(2).split(',')]
    end = i+1
    while end < len(lines) and lines[end].rstrip('\n') != r'\.':
        end += 1
    if end == len(lines):
        raise SystemExit('Incomplete COPY block: ' + table)
    count = end-i-1
    if count != manifest['table_counts'].get(table):
        raise SystemExit('Snapshot row count mismatch: ' + table)
    # Cloud Vault ciphertext cannot be decrypted with the new VPS key.
    # Only the notification worker key exists; regenerate it before cutover.
    if table == 'vault.secrets':
        skipped.append(table + ' (worker key must be regenerated)')
    elif table.startswith(('auth.', 'storage.')) and (table not in catalog or not set(columns) <= catalog[table]):
        if count:
            raise SystemExit('Nonempty incompatible table: ' + table + '. Stop; no import performed.')
        skipped.append(table + ' (empty and incompatible)')
    else:
        result.extend(lines[i:end+1])
    i = end+1
(work/'data.prepared.sql').write_text(''.join(result))
for item in skipped:
    print('Deferred:', item)
print('COPY compatibility and snapshot integrity checks passed.')
PY
RESTART_NEEDED=true
restart_staging() {
  if [[ ${RESTART_NEEDED:-false} == true ]]; then
    docker compose up -d --wait --wait-timeout 300
  fi
}
trap restart_staging EXIT
echo 'Stopping staging API services during import...'
docker compose stop auth rest realtime storage api-gw
# Stop-on-error transaction avoids a partly restored database. Snapshot includes
# staging internals for an additional recovery route if needed later.
db -At -c 'select version();' >"$WORK/destination-version.txt"
docker compose exec -T db pg_dump -U supabase_admin -d postgres >"$WORK/destination-before.sql" 2>"$WORK/destination-before.log"
docker compose exec -T db pg_dumpall -U supabase_admin --roles-only >"$WORK/roles-before.sql" 2>"$WORK/roles-before.log"
{
  cat "$BACKUP/roles.sql"
  cat "$BACKUP/schema.sql"
  printf '\nSET session_replication_role = replica;\n'
  cat "$WORK/data.prepared.sql"
  # Explicitly leave all imported schedules inactive, even if the dump includes
  # extension data. VPS must never invoke the Cloud workers.
  cat <<'SQL'
DO $$ BEGIN
  IF to_regclass('cron.job') IS NOT NULL THEN
    EXECUTE 'UPDATE cron.job SET active=false';
  END IF;
END $$;
RESET session_replication_role;
SQL
} >"$WORK/restore.sql"
if ! db --single-transaction -v VERBOSITY=sqlstate -f /dev/stdin <"$WORK/restore.sql" >"$WORK/restore.log" 2>&1; then
  echo 'Import failed; transaction rolled back. Do not share the SQL files or full logs.'
  # Only SQLSTATE codes are shared, never row contents or account information.
  python3 - "$WORK/restore.log" <<'PY'
import re, sys
from pathlib import Path
for code in sorted(set(re.findall(r'(?:ERROR|FATAL):\s+([0-9A-Z]{5})\b', Path(sys.argv[1]).read_text()))):
    print('SQLSTATE:', code)
PY
  exit 1
fi
python3 - "$BACKUP" <<'PY'
import json, subprocess, sys
from pathlib import Path
counts = json.loads((Path(sys.argv[1])/'manifest.json').read_text())['table_counts']
checks = {k:v for k,v in counts.items() if k.startswith('public.') or k in ('auth.users','auth.identities','auth.mfa_factors','storage.objects','storage.buckets')}
parts = []
for table, expected in checks.items():
    schema, name = table.split('.')
    parts.append("select '"+table+"', count(*) from \""+schema+"\".\""+name+"\"")
r = subprocess.run(['docker','compose','exec','-T','db','psql','-X','-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1','-At','-F','|','-c',' union all '.join(parts)], capture_output=True, text=True)
if r.returncode:
    raise SystemExit('Post-import count query failed; stop before cutover.')
actual = dict(line.split('|') for line in r.stdout.splitlines())
for table, expected in checks.items():
    if int(actual.get(table, -1)) != expected:
        raise SystemExit('Post-import row count mismatch: '+table)
print('Verified tables:', len(checks))
print('Imported accounts:', actual['auth.users'])
print('Imported storage metadata:', actual['storage.objects'])
PY
docker compose up -d --wait --wait-timeout 300
RESTART_NEEDED=false
printf '%s\n' "$BACKUP" >.paskluis-import-complete
docker compose ps
echo 'Database imported into staging. No production cutover.'
echo 'Next: copy physical Storage objects, configure functions/email, regenerate worker key, and run security tests.'
