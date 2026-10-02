#!/usr/bin/env bash
# Align empty staging Auth with Cloud's expires_at schema; no production changes.
set -Eeuo pipefail
umask 077
[[ $EUID == 0 ]] || exit 1
cd /opt/paskluis-supabase
[[ -f .paskluis-upstream-version && ! -f .paskluis-import-complete ]] || exit 1
[[ $(docker compose exec -T db psql -X -U postgres -d postgres -At -c 'select count(*) from auth.users;') == 0 ]] || { echo 'Staging contains accounts; stop for inspection.'; exit 1; }
SNAPSHOT="/var/backups/paskluis-supabase/auth-align-$(date -u +%Y%m%dT%H%M%SZ)-$$"
mkdir -p "$SNAPSHOT"
docker compose exec -T db pg_dump -U supabase_admin -d postgres >"$SNAPSHOT/database-before.sql" 2>"$SNAPSHOT/backup.log"
cp docker-compose.paskluis.yml "$SNAPSHOT/compose-before.yml"
python3 - <<'PY'
from pathlib import Path
p = Path('docker-compose.paskluis.yml')
s = p.read_text()
marker = '  auth:\n    environment:\n'
replacement = '  auth:\n    image: supabase/gotrue:v2.197.0\n    environment:\n'
if replacement not in s:
    if s.count(marker) != 1:
        raise SystemExit('Unexpected Auth override; stop for inspection.')
    p.write_text(s.replace(marker, replacement))
PY
docker compose config --quiet
docker compose pull auth
docker compose up -d --wait --wait-timeout 180 auth
docker compose exec -T db psql -X -U postgres -d postgres -v ON_ERROR_STOP=1 \
  -c "select column_name,data_type from information_schema.columns where table_schema='auth' and table_name='one_time_tokens' order by ordinal_position;"
[[ $(docker compose exec -T db psql -X -U postgres -d postgres -At -c "select count(*) from information_schema.columns where table_schema='auth' and table_name='one_time_tokens' and column_name='expires_at' and data_type='timestamp with time zone';") == 1 ]] || { echo 'Expected expiry column is still missing; stop.'; exit 1; }
echo 'Staging Auth aligned to v2.197.0; expires_at verified. Production unchanged.'
