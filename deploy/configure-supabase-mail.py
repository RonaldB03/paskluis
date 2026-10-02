#!/usr/bin/env python3
"""Configure staging Auth/support SMTP after a TLS login check; send no mail."""
import getpass
import json
import os
from pathlib import Path
import shutil
import smtplib
import ssl
import subprocess
import sys
import warnings
from datetime import datetime, timezone

ROOT = Path('/opt/paskluis-supabase')
HOST, PORT, MAILBOX = 'smtp.strato.com', 465, 'info@paskluis.com'

def write_private(path, text):
    temporary = path.with_name(path.name + '.mail.tmp')
    temporary.write_text(text)
    temporary.chmod(0o600)
    temporary.replace(path)

def configure():
    if os.geteuid() != 0:
        raise RuntimeError('Run as root on the VPS.')
    if not (ROOT / '.paskluis-functions-staged').is_file():
        raise RuntimeError('Complete Functions staging first.')
    # No fallback to visible stdin if this is accidentally run without a terminal.
    with warnings.catch_warnings():
        warnings.simplefilter('error', getpass.GetPassWarning)
        with open('/dev/tty', 'w') as terminal:
            password = getpass.getpass('Mailbox password for info@paskluis.com (hidden): ', stream=terminal)
    if not password or '\n' in password or '\r' in password:
        raise RuntimeError('Invalid password input; configuration unchanged.')
    print('Checking TLS connection and mailbox login; no mail will be sent...', flush=True)
    with smtplib.SMTP_SSL(HOST, PORT, timeout=20, context=ssl.create_default_context()) as smtp:
        smtp.login(MAILBOX, password)
    print('TLS and SMTP login passed.', flush=True)
    paths = [ROOT / '.env', ROOT / '.env.functions', ROOT / 'docker-compose.mail.json']
    env, functions, override = paths
    env_lines = env.read_text().splitlines()
    indexes = [i for i, line in enumerate(env_lines) if line.startswith('COMPOSE_FILE=')]
    if len(indexes) != 1:
        raise RuntimeError('Unexpected Compose configuration; nothing changed.')
    stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ') + '-' + str(os.getpid())
    backup = Path('/var/backups/paskluis-supabase') / ('mail-' + stamp)
    backup.mkdir(mode=0o700)
    for path in paths:
        if path.exists():
            shutil.copy2(path, backup / path.name)
    smtp_config = {'host': HOST, 'port': PORT, 'user': MAILBOX, 'from': MAILBOX, 'password': password}
    settings = {'SUPPORT_SMTP_JSON': json.dumps(smtp_config, separators=(',', ':')),
                'SUPPORT_MAILBOX': MAILBOX, 'SUPPORT_INBOX_EMAIL': MAILBOX}
    lines = [line for line in functions.read_text().splitlines()
             if line.split('=', 1)[0] not in settings]
    lines.extend(key + '=' + value for key, value in settings.items())
    write_private(functions, '\n'.join(lines) + '\n')
    auth_settings = {'GOTRUE_SMTP_HOST': HOST, 'GOTRUE_SMTP_PORT': str(PORT),
                     'GOTRUE_SMTP_USER': MAILBOX, 'GOTRUE_SMTP_PASS': password,
                     'GOTRUE_SMTP_ADMIN_EMAIL': MAILBOX, 'GOTRUE_SMTP_SENDER_NAME': 'PasKluis'}
    # JSON is valid YAML; doubled dollars prevent Compose variable interpolation.
    escaped = {key: value.replace('$', '$$') for key, value in auth_settings.items()}
    write_private(override, json.dumps({'services': {'auth': {'environment': escaped}}}, indent=2) + '\n')
    i = indexes[0]
    if override.name not in env_lines[i].split('=', 1)[1].split(':'):
        env_lines[i] += ':' + override.name
    write_private(env, '\n'.join(env_lines) + '\n')
    def compose(*args):
        result = subprocess.run(['docker', 'compose', *args], cwd=ROOT, capture_output=True, text=True)
        (backup / 'compose-private.log').write_text(result.stdout + result.stderr)
        if result.returncode:
            raise RuntimeError('Mail container configuration failed; private logs and backup remain on VPS.')
    compose('config', '--quiet')
    print('Loading SMTP configuration in staging Auth and Functions...', flush=True)
    compose('up', '-d', '--no-deps', '--force-recreate', '--wait', '--wait-timeout', '180', 'auth', 'functions')
    for name in ['paskluis-auth', 'paskluis-edge-functions']:
        result = subprocess.run(['docker', 'inspect', name], capture_output=True, text=True, check=True)
        container = json.loads(result.stdout)[0]
        values = dict(item.split('=', 1) for item in container['Config']['Env'])
        if name == 'paskluis-auth':
            if any(values.get(key) != value for key, value in auth_settings.items()):
                raise RuntimeError('Auth SMTP environment verification failed; no cutover.')
        elif json.loads(values.get('SUPPORT_SMTP_JSON', '{}')) != smtp_config:
            raise RuntimeError('Support SMTP environment verification failed; no cutover.')
    (ROOT / '.paskluis-mail-configured').write_text(stamp + '\n')
    print('Auth and support SMTP configured; container environment verified.')
    print('No mail sent, no schedules enabled, production unchanged.')
    print('Mail delivery, templates and redirect URLs still need testing before cutover.')

if __name__ == '__main__':
    os.umask(0o077)
    try:
        configure()
    except smtplib.SMTPAuthenticationError as error:
        print('SMTP login rejected (code ' + str(error.smtp_code) + '); configuration unchanged.', file=sys.stderr)
        sys.exit(1)
    except Exception as error:
        print(str(error) if isinstance(error, RuntimeError) else
              'Mail setup stopped; no secret values printed. Keep private files on VPS.', file=sys.stderr)
        sys.exit(1)
