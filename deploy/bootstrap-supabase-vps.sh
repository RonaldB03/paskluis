#!/usr/bin/env bash
# Stage 1 only: isolated, empty self-hosted stack. No production cutover.
set -Eeuo pipefail
umask 077
UPSTREAM_SHA=1168fd8a2180250c894c16b341577a634437fad5
TARGET=/opt/paskluis-supabase
[[ $EUID == 0 ]] || { echo 'Run as root.'; exit 1; }
for tool in curl tar python3 openssl docker; do
  command -v "$tool" >/dev/null || { echo "Missing prerequisite: $tool"; exit 1; }
done
docker compose version
if [[ -e "$TARGET" ]]; then
  echo "Refusing to overwrite $TARGET. Send this message for inspection."
  exit 1
fi
python3 - <<'PY'
import socket
with socket.socket() as s:
    s.bind(('127.0.0.1', 8800))
PY
STAGING=$(mktemp -d /var/tmp/paskluis-supabase.XXXXXX)
echo 'Downloading pinned Supabase distribution...'
curl --fail --location --retry 3 --connect-timeout 20 --max-time 300 \
  "https://codeload.github.com/supabase/supabase/tar.gz/$UPSTREAM_SHA" \
  --output "$STAGING/upstream.tar.gz"
mkdir "$TARGET"
chmod 700 "$TARGET"
tar --extract --gzip --file "$STAGING/upstream.tar.gz" --directory "$TARGET" \
  --strip-components=2 --no-same-owner "supabase-$UPSTREAM_SHA/docker"
cd "$TARGET"
cp .env.example .env
# The upstream generator prints secrets: suppress its output, never paste .env.
sh utils/generate-keys.sh --update-env >/dev/null
python3 - <<'PY'
from pathlib import Path
settings = {
    'COMPOSE_FILE': 'docker-compose.yml:docker-compose.paskluis.yml',
    'SUPABASE_PUBLIC_URL': 'https://api.paskluis.com',
    'API_EXTERNAL_URL': 'https://api.paskluis.com/auth/v1',
    'SITE_URL': 'https://paskluis.com',
    'ADDITIONAL_REDIRECT_URLS': '',
    'DISABLE_SIGNUP': 'true',
    'ENABLE_PHONE_SIGNUP': 'false',
    'ENABLE_PHONE_AUTOCONFIRM': 'false',
    'ENABLE_EMAIL_AUTOCONFIRM': 'false',
    'SMTP_HOST': '', 'SMTP_USER': '', 'SMTP_PASS': '',
    'SMTP_ADMIN_EMAIL': 'info@paskluis.com', 'SMTP_SENDER_NAME': 'PasKluis',
    'POOLER_TENANT_ID': 'paskluis',
    'STUDIO_DEFAULT_ORGANIZATION': 'PasKluis',
    'STUDIO_DEFAULT_PROJECT': 'PasKluis VPS staging',
    'OPENAI_API_KEY': '',
    'API_GW_HTTP_PORT': '8800',
}
p = Path('.env')
lines = p.read_text().splitlines()
for key, value in settings.items():
    matches = [i for i, line in enumerate(lines) if line.startswith(key + '=')]
    if len(matches) != 1:
        raise RuntimeError('Unexpected upstream setting: ' + key)
    lines[matches[0]] = key + '=' + value
p.write_text('\n'.join(lines) + '\n')
p.chmod(0o600)
# Give containers distinct names; preserve realtime's tenant prefix.
p = Path('docker-compose.yml')
p.write_text(p.read_text().replace('container_name: supabase-', 'container_name: paskluis-')
             .replace('container_name: realtime-dev.supabase-realtime',
                      'container_name: realtime-dev.paskluis-realtime'))
PY
cat >docker-compose.paskluis.yml <<'YAML'
name: paskluis-supabase
services:
  api-gw:
    ports: !override
      - "127.0.0.1:8800:8000"
  supavisor:
    profiles: [migration-pending]
    ports: !override []
  functions:
    profiles: [migration-pending]
  auth:
    image: supabase/gotrue:v2.197.0
    environment:
      GOTRUE_MFA_TOTP_ENROLL_ENABLED: "true"
      GOTRUE_MFA_TOTP_VERIFY_ENABLED: "true"
YAML
# Validate the resolved configuration without printing passwords.
docker compose config --format json | python3 -c '
import json, sys
c = json.load(sys.stdin)
for name, service in c["services"].items():
    for port in service.get("ports", []):
        if name != "api-gw" or port.get("host_ip") != "127.0.0.1" or str(port["published"]) != "8800":
            raise SystemExit("Unsafe port mapping: " + name)
print("Configuration validated: gateway on 127.0.0.1:8800 only.")
'
echo 'Starting empty staging stack (image downloads can take a few minutes)...'
docker compose up -d --wait --wait-timeout 300
docker compose ps
docker compose exec -T db psql -U postgres -d postgres -v ON_ERROR_STOP=1 \
  -c 'select version();' -c 'select count(*) as staging_accounts from auth.users;'
printf '%s\n' "$UPSTREAM_SHA" >.paskluis-upstream-version
echo 'Stage 1 complete. Production is unchanged. Send the output, never .env.'
