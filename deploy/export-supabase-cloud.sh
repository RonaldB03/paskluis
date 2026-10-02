#!/usr/bin/env bash
# Read-only database snapshot; files stay on the VPS and are not imported yet.
set -Eeuo pipefail
umask 077
[[ $EUID == 0 ]] || { echo 'Run as root.'; exit 1; }
TARGET=/opt/paskluis-supabase
[[ -f "$TARGET/.paskluis-upstream-version" ]] || { echo 'Staging bootstrap has not completed.'; exit 1; }
for tool in curl tar python3 sha256sum docker; do
  command -v "$tool" >/dev/null || { echo "Missing prerequisite: $tool"; exit 1; }
done
TOOLS="$TARGET/tools/supabase-2.119.0"
mkdir -p "$TOOLS"
if [[ ! -f "$TOOLS/cli.tar.gz" ]]; then
  curl --fail --location --retry 3 --connect-timeout 20 --max-time 180 \
    https://github.com/supabase/cli/releases/download/v2.119.0/supabase_2.119.0_linux_amd64.tar.gz \
    --output "$TOOLS/cli.tar.gz"
fi
printf '%s  %s\n' bf1c3ae93be98533eb8a3105dbf4564bd0b2d9dc24690d8a920f980ef975c1b4 "$TOOLS/cli.tar.gz" | sha256sum --check
tar -xzf "$TOOLS/cli.tar.gz" -C "$TOOLS" supabase
CLI="$TOOLS/supabase"
"$CLI" --version
"$CLI" db dump --help >"$TOOLS/dump-help.txt"
for flag in --db-url --role-only --data-only --use-copy; do
  grep -q -- "$flag" "$TOOLS/dump-help.txt" || { echo "Unsupported CLI option: $flag"; exit 1; }
done
BACKUP="/var/backups/paskluis-supabase/cloud-$(date -u +%Y%m%dT%H%M%SZ)-$$"
mkdir -p "$BACKUP"
chmod 700 /var/backups/paskluis-supabase "$BACKUP"
echo 'Paste the Supabase production Session pooler URI WITH its database password.'
echo 'Input is hidden. Do not paste this URI or password into chat.'
IFS= read -r -s -p 'Database URI: ' PASKLUIS_SOURCE_DB_URL
printf '\n'
export PASKLUIS_SOURCE_DB_URL
trap 'unset PASKLUIS_SOURCE_DB_URL' EXIT
python3 - <<'PY'
import os
from urllib.parse import urlsplit, unquote
try:
    u = urlsplit(os.environ['PASKLUIS_SOURCE_DB_URL'])
    project = 'ajldblvvlbvmgejrmhyj'
    direct = u.hostname == 'db.' + project + '.supabase.co' and u.username == 'postgres'
    pooler = (u.hostname or '').endswith('.pooler.supabase.com') and unquote(u.username or '') == 'postgres.' + project and u.port == 5432
    password = unquote(u.password or '')
    assert u.scheme in ('postgres', 'postgresql') and (direct or pooler)
    assert password and 'YOUR-PASSWORD' not in password
    assert u.path == '/postgres'
except Exception:
    raise SystemExit('Invalid production database URI. Use the Session pooler on port 5432 and replace the password placeholder.')
print('Production project validated. Export is read-only.')
PY
cd "$TARGET"
dump_part() {
  local part="$1"; shift
  echo "Exporting $part..."
  if ! "$CLI" db dump --db-url "$PASKLUIS_SOURCE_DB_URL" --file "$BACKUP/$part.sql" "$@" >"$BACKUP/$part.log" 2>&1; then
    echo "Export failed: $part. Stop here and report this message."
    echo 'Logs remain private on the VPS; do not paste them or SQL files into chat.'
    exit 1
  fi
  [[ -s "$BACKUP/$part.sql" ]] || { echo "Empty export: $part"; exit 1; }
}
dump_part roles --role-only
dump_part schema
dump_part data --data-only --use-copy
unset PASKLUIS_SOURCE_DB_URL
python3 - "$BACKUP" <<'PY'
import json, re, sys
from pathlib import Path
p = Path(sys.argv[1])
counts = {}
table = None
for line in (p/'data.sql').read_text().splitlines():
    if line.startswith('COPY '):
        m = re.match(r'COPY (\S+) ', line)
        table = m.group(1).replace('"', '') if m else None
        if table:
            counts[table] = 0
    elif line == r'\.':
        table = None
    elif table:
        counts[table] += 1
if counts.get('auth.users', 0) == 0:
    raise SystemExit('Export check failed: auth.users is absent or empty. Do not import.')
summary = {'source_project': 'ajldblvvlbvmgejrmhyj', 'cli_version': '2.119.0',
           'table_counts': counts, 'stage': 'database-export-only'}
(p/'manifest.json').write_text(json.dumps(summary, indent=2) + '\n')
print('Accounts in export:', counts['auth.users'])
print('Storage metadata rows:', counts.get('storage.objects', 0))
print('COPY tables:', len(counts))
PY
(cd "$BACKUP" && sha256sum roles.sql schema.sql data.sql manifest.json >SHA256SUMS)
echo "Database snapshot completed: $BACKUP"
echo 'No import or cutover performed. Storage bytes and Edge Function settings still need separate migration.'
