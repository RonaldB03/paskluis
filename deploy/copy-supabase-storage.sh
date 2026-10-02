#!/usr/bin/env bash
# Match S3's canonical host to the local migration endpoint, then restore it.
set -Eeuo pipefail
umask 077
[[ $EUID == 0 ]] || { echo 'Run as root.'; exit 1; }
cd /opt/paskluis-supabase
[[ -f .paskluis-import-complete ]] || { echo 'Complete the database import first.'; exit 1; }
PYTHON_SCRIPT=${1:-/tmp/paskluis-storage.py}
[[ -f "$PYTHON_SCRIPT" ]] || { echo 'Storage Python script missing.'; exit 1; }
command -v rclone >/dev/null || { echo 'Install rclone first.'; exit 1; }
mkdir -p migration-storage
OVERRIDE=/opt/paskluis-supabase/migration-storage/local-copy.override.yml
cat >"$OVERRIDE" <<'YAML'
services:
  storage:
    environment:
      STORAGE_PUBLIC_URL: http://127.0.0.1:8800
YAML
restore_public_host() {
  echo 'Restoring Storage canonical host to api.paskluis.com...'
  docker compose -f docker-compose.yml -f docker-compose.paskluis.yml \
    up -d --no-deps --wait --wait-timeout 180 storage
}
trap restore_public_host EXIT
echo 'Temporarily matching Storage signing host to the localhost copy endpoint...'
docker compose -f docker-compose.yml -f docker-compose.paskluis.yml -f "$OVERRIDE" \
  config --quiet
docker compose -f docker-compose.yml -f docker-compose.paskluis.yml -f "$OVERRIDE" \
  up -d --no-deps --wait --wait-timeout 180 storage
python3 "$PYTHON_SCRIPT"
