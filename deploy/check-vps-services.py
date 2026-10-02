#!/usr/bin/env python3
"""Test migrated services without sending mail/push or modifying real accounts."""
import hashlib
import json
import os
from pathlib import Path
import smtplib
import ssl
import subprocess
import sys
from urllib.request import Request, urlopen
from urllib.error import HTTPError
from urllib.parse import quote

ROOT = Path('/opt/paskluis-supabase')
WORK = ROOT / 'migration-checks'
BASE = 'http://127.0.0.1:8800'

def command(args, data=None):
    result = subprocess.run(args, input=data, text=True, capture_output=True, cwd=ROOT)
    if result.returncode:
        (WORK / 'services-private.log').write_text(result.stdout + result.stderr)
        raise RuntimeError('Service check command failed; private log retained.')
    return result.stdout

def sql(query):
    return command(['docker', 'compose', 'exec', '-T', 'db', 'psql', '-X', '-U',
                    'supabase_admin', '-d', 'postgres', '-At', '-v', 'ON_ERROR_STOP=1',
                    '-v', 'VERBOSITY=sqlstate'], query).strip()

def request(path, *, key=None, body=None, method=None):
    headers = {'Content-Type': 'application/json'}
    if key:
        headers.update({'apikey': key, 'Authorization': 'Bearer ' + key})
    req = Request(BASE + path, headers=headers,
                  data=json.dumps(body).encode() if body is not None else None, method=method)
    try:
        with urlopen(req, timeout=90) as response:
            return response.status, response.read()
    except HTTPError as error:
        return error.code, error.read()

def main():
    if os.geteuid() != 0 or not (ROOT / '.paskluis-mail-configured').is_file():
        raise RuntimeError('Run only on configured VPS staging.')
    WORK.mkdir(exist_ok=True, mode=0o700)
    values = dict(line.split('=', 1) for line in (ROOT / '.env').read_text().splitlines()
                  if line and not line.startswith('#') and '=' in line)
    anon, service = values['ANON_KEY'], values['SERVICE_ROLE_KEY']
    funcs = json.loads(command(['docker', 'inspect', 'paskluis-edge-functions']))[0]
    env = dict(item.split('=', 1) for item in funcs['Config']['Env'])
    for slug in ['card-backups', 'clever-endpoint', 'delete-account', 'dispatch-notifications',
                 'invite-staff', 'nearest-brand-stores', 'reconcile-purchases',
                 'send-shared-card-notification', 'support-attachments', 'verify-purchase']:
        status, _ = request('/functions/v1/' + slug, key=anon, body={})
        if status not in {400, 401, 403}:
            raise RuntimeError('Unexpected empty-request response: ' + slug + ' ' + str(status))
        print('Function access OK:', slug, status, flush=True)
    for table in ['profiles', 'entitlements', 'support_threads', 'support_messages',
                  'support_private_notes', 'store_purchases', 'notification_outbox',
                  'push_device_tokens', 'support_sessions']:
        status, body = request('/rest/v1/' + table + '?select=*&limit=1', key=anon)
        if status not in {401, 403} and not (status == 200 and json.loads(body) == []):
            raise RuntimeError('Anonymous data protection check failed: ' + table)
    print('Nine private data tables reject anonymous reads.', flush=True)
    status, body = request('/rest/v1/brands?select=id&limit=1', key=anon)
    if status != 200 or not json.loads(body):
        raise RuntimeError('Public brand catalog not accessible.')
    print('Public brand catalog accessible.', flush=True)
    for bucket in ['brand-logos', 'card-backups', 'support-attachments']:
        path = sql("select name from storage.objects where bucket_id='" + bucket + "' order by name limit 1;")
        if not path:
            print('Storage sample skipped (empty bucket):', bucket, flush=True)
            continue
        encoded = quote(bucket + '/' + path, safe='/')
        if bucket == 'brand-logos':
            status, body = request('/storage/v1/object/public/' + encoded)
            if status != 200 or not body:
                raise RuntimeError('Public logo download failed.')
        else:
            status, _ = request('/storage/v1/object/' + encoded, key=anon)
            if status not in {400, 401, 403, 404}:
                raise RuntimeError('Private storage file exposed: ' + bucket)
            status, body = request('/storage/v1/object/' + encoded, key=service)
            if status != 200 or not body:
                raise RuntimeError('Authorized private download failed: ' + bucket)
        print('Storage access OK:', bucket, flush=True)
    smtp = json.loads(env['SUPPORT_SMTP_JSON'])
    with smtplib.SMTP_SSL(smtp['host'], int(smtp['port']), timeout=20,
                         context=ssl.create_default_context()) as connection:
        connection.login(smtp['user'], smtp['password'])
    print('SMTP TLS/login verified from loaded container settings; no mail sent.', flush=True)
    revision = '08a82c357fc25f5b7b2ea3e65f0b14b9897c309d'
    with urlopen('https://raw.githubusercontent.com/RonaldB03/paskluis/' + revision +
                 '/supabase/tests/live_support_settings_security.sql', timeout=30) as response:
        security_test = response.read()
    if hashlib.sha256(security_test).hexdigest() != '3b0e747e13527f762b880d4bcf7395b909d0e6c149408a430787500fe558d60f':
        raise RuntimeError('SQL test checksum mismatch.')
    before = sql('select count(*) from auth.users;')
    output = sql(security_test.decode())
    if 'PASS: real MFA' not in output or not output.endswith('ROLLBACK'):
        raise RuntimeError('Transactional support security test incomplete.')
    if before != sql('select count(*) from auth.users;'):
        raise RuntimeError('Account count changed during test.')
    print('Support SQL security PASS: MFA, privacy filtering, ownership, revisions and revocation.', flush=True)
    print('Synthetic test users and changes rolled back; account count unchanged.', flush=True)
    print('Checks completed. Actual device login, email delivery, push and purchases still require end-to-end tests.', flush=True)

if __name__ == '__main__':
    os.umask(0o077)
    try:
        main()
    except Exception as error:
        print(str(error) if isinstance(error, RuntimeError) else
              'Service checks stopped; no private values printed.', flush=True)
        sys.exit(1)
