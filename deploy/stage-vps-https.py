#!/usr/bin/env python3
"""Prepare HTTPS and inspect isolated PasKluis staging. No public API/cutover."""
import http.client
import json
import os
from pathlib import Path
import shutil
import socket
import ssl
import subprocess
import sys
from datetime import datetime, timezone

ROOT = Path('/opt/paskluis-supabase')
DOMAIN = 'api.paskluis.com'
IP = '217.154.75.81'
SITE = Path('/etc/nginx/sites-available/api.paskluis.com')
LINK = Path('/etc/nginx/sites-enabled/api.paskluis.com')
WEBROOT = Path('/var/www/paskluis-acme')
MARKER = '# PasKluis isolated staging HTTPS v1\n'
STAMP = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')
WORK = ROOT / 'migration-checks'

def run(args, *, data=None, cwd=None, label='command'):
    result = subprocess.run(args, input=data, text=True, capture_output=True, cwd=cwd)
    (WORK / (label + '.log')).write_text(result.stdout + result.stderr)
    if result.returncode:
        raise RuntimeError(label + ' failed; private log retained on VPS.')
    return result.stdout

def sql(query):
    return run(['docker', 'compose', 'exec', '-T', 'db', 'psql', '-X', '-U',
                'supabase_admin', '-d', 'postgres', '-At', '-v', 'ON_ERROR_STOP=1',
                '-v', 'VERBOSITY=sqlstate'], data=query, cwd=ROOT, label='database-check').strip()

def env_of(name):
    result = json.loads(run(['docker', 'inspect', name], label='container-private'))[0]
    return dict(x.split('=', 1) for x in result['Config']['Env'])

def inspect():
    states = json.loads(run(['docker', 'inspect', *[
        'paskluis-' + s for s in ['db', 'auth', 'rest', 'storage', 'envoy', 'studio',
                                  'imgproxy', 'meta', 'edge-functions']
    ], 'realtime-dev.paskluis-realtime'], label='health-private'))
    for state in states:
        health = state['State'].get('Health', {}).get('Status', '')
        if not state['State']['Running'] or health not in ('healthy', ''):
            raise RuntimeError('Unhealthy service: ' + state['Name'])
        print('Service OK:', state['Name'].lstrip('/'), flush=True)
    funcs = env_of('paskluis-edge-functions')
    required = ['APPLE_IAP_KEY_JSON', 'GOOGLE_PLAY_SERVICE_ACCOUNT_JSON',
                'FIREBASE_SERVICE_ACCOUNT_JSON', 'GOOGLE_PLACES_API_KEY', 'SUPPORT_SMTP_JSON']
    for key in required:
        if not funcs.get(key):
            raise RuntimeError('Missing function setting: ' + key)
        if key.endswith('_JSON'):
            json.loads(funcs[key])
    print('All five external settings present; JSON formats valid.', flush=True)
    auth = env_of('paskluis-auth')
    for key in ['GOTRUE_API_EXTERNAL_URL', 'API_EXTERNAL_URL', 'GOTRUE_SITE_URL',
                'GOTRUE_URI_ALLOW_LIST', 'GOTRUE_DISABLE_SIGNUP',
                'GOTRUE_MFA_TOTP_ENROLL_ENABLED', 'GOTRUE_MFA_TOTP_VERIFY_ENABLED']:
        if key in auth:
            print('Auth setting:', key, '=', auth[key], flush=True)
    for key in ['GOTRUE_SMTP_HOST', 'GOTRUE_SMTP_USER', 'GOTRUE_SMTP_PASS']:
        if not auth.get(key):
            raise RuntimeError('Missing Auth SMTP setting: ' + key)
    print('Accounts / physical-file registrations:', sql(
        "select (select count(*) from auth.users)||' / '||(select count(*) from storage.objects);"))
    exposed = sql("select coalesce(string_agg(c.relname,','),'none') from pg_class c "
                  "join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' "
                  "and c.relkind in ('r','p') and not c.relrowsecurity "
                  "and (has_table_privilege('anon',c.oid,'SELECT,INSERT,UPDATE,DELETE') "
                  "or has_table_privilege('authenticated',c.oid,'SELECT,INSERT,UPDATE,DELETE'));")
    print('Public tables with API grants but no RLS:', exposed, flush=True)
    if exposed != 'none':
        raise RuntimeError('Review exposed table protection before continuing.')
    print('Storage buckets:', sql("select string_agg(id||': '||case when public then 'public' else 'private' end,', ' order by id) from storage.buckets;"))
    print('Cron extension:', sql("select count(*) from pg_extension where extname='pg_cron';"))
    if sql("select count(*) from pg_extension where extname='pg_cron';") == '1':
        active = sql('select count(*) from cron.job where active;')
        print('Active scheduled tasks:', active, flush=True)
        if active != '0':
            raise RuntimeError('Unexpected active schedules in staging.')
    print('Readonly staging inspection passed.', flush=True)

def install_nginx(text):
    previous = SITE.read_text() if SITE.exists() else None
    if previous is not None and not previous.startswith(MARKER):
        raise RuntimeError('Existing API nginx configuration needs manual review.')
    if LINK.exists() and (not LINK.is_symlink() or LINK.resolve() != SITE):
        raise RuntimeError('Unexpected enabled API site.')
    created_link = not LINK.exists()
    SITE.write_text(text)
    SITE.chmod(0o644)
    if created_link:
        LINK.symlink_to(SITE)
    try:
        run(['nginx', '-t'], label='nginx-test')
        run(['systemctl', 'reload', 'nginx'], label='nginx-reload')
    except Exception:
        if created_link:
            LINK.unlink()
        if previous is None:
            SITE.unlink()
        else:
            SITE.write_text(previous)
        raise

def https():
    run(['nginx', '-t'], label='nginx-precheck')
    for site in Path('/etc/nginx/sites-enabled').iterdir():
        if site.name != LINK.name and DOMAIN in site.read_text():
            raise RuntimeError('API domain already occurs in ' + site.name)
    accounts = list(Path('/etc/letsencrypt/accounts/acme-v02.api.letsencrypt.org/directory').glob('*/regr.json'))
    if len(accounts) != 1:
        raise RuntimeError('Expected one existing Lets Encrypt account; inspect before requesting a certificate.')
    backup = Path('/var/backups/paskluis-supabase') / ('https-' + STAMP)
    backup.mkdir(mode=0o700)
    shutil.copytree('/etc/nginx', backup / 'nginx', symlinks=True)
    WEBROOT.mkdir(exist_ok=True, mode=0o755)
    http = '''server {
    listen 80;
    listen [::]:80;
    server_name api.paskluis.com;
    location ^~ /.well-known/acme-challenge/ { root /var/www/paskluis-acme; }
    location / { return 404; }
}
'''
    cert = Path('/etc/letsencrypt/live/api.paskluis.com/fullchain.pem')
    if not cert.exists():
        install_nginx(MARKER + http)
    addresses = {row[4][0] for row in socket.getaddrinfo(DOMAIN, 443, type=socket.SOCK_STREAM)}
    print('API DNS:', ', '.join(sorted(addresses)), flush=True)
    if IP not in addresses or any(x not in {IP, '2a01:239:39a:ed00::1'} for x in addresses):
        raise RuntimeError('DNS is not ready; HTTP challenge site is prepared. Retry after DNS propagation.')
    print('Requesting HTTPS certificate using existing ACME account...', flush=True)
    run(['certbot', 'certonly', '--webroot', '-w', str(WEBROOT), '--cert-name', DOMAIN,
         '-d', DOMAIN, '--non-interactive', '--keep-until-expiring', '--account',
         accounts[0].parent.name, '--deploy-hook', 'systemctl reload nginx'], label='certbot-private')
    http = http.replace('location / { return 404; }', 'location / { return 308 https://api.paskluis.com$request_uri; }')
    tls = '''
map $http_upgrade $paskluis_connection_upgrade { default upgrade; '' close; }
server {
    listen 443 ssl;
    listen [::]:443 ssl;
    server_name api.paskluis.com;
    ssl_certificate /etc/letsencrypt/live/api.paskluis.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.paskluis.com/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    server_tokens off;
    client_max_body_size 25m;
    location = /health { default_type text/plain; return 200 'PasKluis staging HTTPS ready\\n'; }
    # Keep API reachable only from the VPS during migration testing.
    location ~ ^/(auth|rest|storage|functions|realtime)/v1/ {
        allow 127.0.0.1;
        allow ::1;
        deny all;
        proxy_pass http://127.0.0.1:8800;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-For $remote_addr;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $paskluis_connection_upgrade;
        proxy_read_timeout 3600s;
        proxy_buffering off;
    }
    # Studio, metadata and unlisted routes are not published.
    location / { return 404; }
}
'''
    install_nginx(MARKER + http + tls)
    for path, expected in [('/health', {'200'}), ('/auth/v1/user', {'401', '403'}), ('/', {'404'})]:
        code = run(['curl', '-sS', '--max-time', '15', '--resolve', DOMAIN + ':443:127.0.0.1',
                    '-o', '/dev/null', '-w', '%{http_code}', 'https://' + DOMAIN + path], label='https-check').strip()
        if code not in expected:
            raise RuntimeError('Unexpected HTTPS response for ' + path + ': ' + code)
        print('HTTPS verified:', path, 'HTTP', code, flush=True)
    print(run(['openssl', 'x509', '-in', str(cert), '-noout', '-dates'], label='certificate-dates').strip())
    print('Certbot renewal timer:', run(['systemctl', 'is-active', 'certbot.timer'], label='renewal-timer').strip())
    (ROOT / '.paskluis-https-staged').write_text(STAMP + '\n')
    print('HTTPS ready. API restricted to local VPS tests. Cloud production unchanged.', flush=True)

if __name__ == '__main__':
    os.umask(0o077)
    if os.geteuid() != 0 or not (ROOT / '.paskluis-mail-configured').is_file():
        raise SystemExit('Run on the configured PasKluis staging VPS as root.')
    WORK.mkdir(mode=0o700, exist_ok=True)
    try:
        inspect()
        if '--https' in sys.argv:
            https()
    except Exception as error:
        print(str(error) if isinstance(error, RuntimeError) else
              'Staging check stopped; inspect private log locally. No secret values printed.', flush=True)
        sys.exit(1)
