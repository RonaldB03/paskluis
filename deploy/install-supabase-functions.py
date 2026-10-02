#!/usr/bin/env python3
"""Stage the verified Cloud function sources on the VPS; no jobs or cutover."""
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import secrets
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from urllib.request import Request, urlopen
from urllib.error import HTTPError

ROOT=Path('/opt/paskluis-supabase')
os.umask(0o077)
if os.geteuid()!=0 or len(sys.argv)!=2 or not re.fullmatch('[0-9a-f]{40}',sys.argv[1]):
    raise SystemExit('Run as root with the pinned deployment commit.')
REV=sys.argv[1]
os.chdir(ROOT)
if not (ROOT/'.paskluis-storage-copy-complete').is_file():
    raise SystemExit('Complete Storage migration first.')
WORK=ROOT/'migration-functions'; WORK.mkdir(exist_ok=True,mode=0o700)

def fetch(path,revision=REV):
    url='https://raw.githubusercontent.com/RonaldB03/paskluis/'+revision+'/'+path
    with urlopen(url,timeout=60) as r:
        return r.read()

def compose(*args):
    r=subprocess.run(['docker','compose',*args],capture_output=True,text=True)
    (WORK/'compose-last.log').write_text(r.stdout+r.stderr)
    if r.returncode:
        raise RuntimeError('Functions container step failed; private log remains on VPS.')

def read_env(path):
    return dict(line.split('=',1) for line in path.read_text().splitlines()
                if line and not line.startswith('#') and '=' in line)

def stage():
    manifest=json.loads(fetch('deploy/functions-source-manifest.json'))
    if manifest['source_project']!='ajldblvvlbvmgejrmhyj':
        raise RuntimeError('Unexpected function source project.')
    candidates={}
    for entry in manifest['files']:
        p=PurePosixPath(entry['path'])
        if p.is_absolute() or '..' in p.parts or len(p.parts)!=2 or p.suffix!='.ts':
            raise RuntimeError('Unexpected function source path.')
        content=fetch('supabase/functions/'+str(p),manifest['source_revision'])
        if hashlib.sha256(content).hexdigest()!=entry['sha256']:
            raise RuntimeError('Function source checksum mismatch: '+str(p))
        candidates[str(p)]=content
    if len(candidates)!=11:
        raise RuntimeError('Unexpected function file count.')
    main=fetch('deploy/functions-main.ts')
    # Keep server calls on the internal Docker network; signed attachment URLs
    # returned to clients must use the external API origin.
    name='support-attachments/index.ts'
    source=candidates[name].decode()
    old='url:signed.data.signedUrl'
    if source.count(old)!=1:
        raise RuntimeError('Unexpected attachment source; stop before patching.')
    helper="""
function publicStorageUrl(value:string):string {
 const internal=Deno.env.get('SUPABASE_URL');
 const external=Deno.env.get('SUPABASE_PUBLIC_URL');
 if(!internal||!external||!value.startsWith(internal.replace(/\\/$/,'')+'/storage/v1/'))return value;
 return external.replace(/\\/$/,'')+value.slice(internal.replace(/\\/$/,'').length);
}
"""
    candidates[name]=(helper+source.replace(old,'url:publicStorageUrl(signed.data.signedUrl)')).encode()
    stamp=datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')+'-'+str(os.getpid())
    backup=Path('/var/backups/paskluis-supabase')/('functions-'+stamp)
    backup.mkdir(mode=0o700)
    shutil.copytree(ROOT/'volumes/functions',backup/'functions-before')
    shutil.copy2(ROOT/'.env',backup/'env-before')
    for name,content in {**candidates,'main/index.ts':main}.items():
        p=ROOT/'volumes/functions'/name; p.parent.mkdir(parents=True,exist_ok=True)
        tmp=p.with_suffix('.migration.tmp'); tmp.write_bytes(content); tmp.replace(p)
    print('Verified source files installed:',len(candidates),flush=True)
    envfile=ROOT/'.env.functions'
    if not envfile.exists():
        envfile.write_text('NOTIFICATION_WORKER_SECRET='+secrets.token_hex(32)+'\nSUPPORT_MAILBOX=info@paskluis.com\nSUPPORT_INBOX_EMAIL=info@paskluis.com\n')
    values=read_env(envfile)
    worker=values.get('NOTIFICATION_WORKER_SECRET','')
    if not re.fullmatch('[0-9a-f]{64}',worker):
        raise RuntimeError('Unexpected worker key format; keep existing secrets and stop.')
    envfile.chmod(0o600)
    sql="""CREATE EXTENSION IF NOT EXISTS supabase_vault;
DO $$ DECLARE secret_id uuid; BEGIN
 SELECT id INTO secret_id FROM vault.secrets WHERE name='paskluis_notification_worker_secret';
 IF secret_id IS NULL THEN
  PERFORM vault.create_secret('WORKER','paskluis_notification_worker_secret');
 ELSE
  PERFORM vault.update_secret(secret_id,'WORKER');
 END IF;
END $$;
""".replace('WORKER',worker)
    r=subprocess.run(['docker','compose','exec','-T','db','psql','-X','-U','supabase_admin','-d','postgres',
                      '-v','ON_ERROR_STOP=1','-v','VERBOSITY=sqlstate'],input=sql,capture_output=True,text=True)
    if r.returncode:
        (WORK/'vault-private.log').write_text(r.stderr)
        raise RuntimeError('VPS worker key configuration failed; private log retained.')
    (ROOT/'docker-compose.functions.yml').write_text('''services:
  functions:
    profiles: !override []
    env_file:
      - path: ./.env.functions
        format: raw
''')
    env=ROOT/'.env'; lines=env.read_text().splitlines()
    indexes=[i for i,x in enumerate(lines) if x.startswith('COMPOSE_FILE=')]
    if len(indexes)!=1:
        raise RuntimeError('Unexpected Compose configuration.')
    i=indexes[0]
    if 'docker-compose.functions.yml' not in lines[i].split('=',1)[1].split(':'):
        lines[i]+=':docker-compose.functions.yml'
    env.write_text('\n'.join(lines)+'\n'); env.chmod(0o600)
    compose('config','--quiet')
    print('Downloading and starting the isolated Functions runtime...',flush=True)
    compose('pull','functions')
    compose('up','-d','--wait','--wait-timeout','180','functions')
    print('Functions runtime healthy; new worker key stored locally. No schedules enabled.',flush=True)
    anon=read_env(env)['ANON_KEY']
    slugs=sorted({x.split('/')[0] for x in candidates})
    protected={'clever-endpoint','invite-staff','nearest-brand-stores'}
    def request(slug,authenticated):
        headers={'Content-Type':'application/json'}
        if authenticated: headers.update({'apikey':anon,'Authorization':'Bearer '+anon})
        req=Request('http://127.0.0.1:8800/functions/v1/'+slug,data=b'{}',headers=headers,method='POST')
        try:
            with urlopen(req,timeout=90) as r: return r.status
        except HTTPError as e:
            return e.code
    for slug in slugs:
        if slug in protected and request(slug,False) not in (401,403):
            raise RuntimeError('Missing-token security check failed: '+slug)
        status=request(slug,True)
        allowed={400,401,403,405,409}
        if slug=='nearest-brand-stores': allowed.add(200)
        if status not in allowed:
            raise RuntimeError('Function startup/access check failed: '+slug+' (HTTP '+str(status)+')')
        print('Startup/access check passed:',slug,'HTTP',status,flush=True)
    (ROOT/'.paskluis-functions-staged').write_text(REV+'\n')
    print('All 10 function startup/access checks passed. Production unchanged.')
    required=['APPLE_IAP_KEY_JSON','GOOGLE_PLAY_SERVICE_ACCOUNT_JSON','FIREBASE_SERVICE_ACCOUNT_JSON',
              'GOOGLE_PLACES_API_KEY','SUPPORT_SMTP_JSON']
    print('Still to configure:',', '.join(k for k in required if not values.get(k)))
    print('Auth SMTP/provider settings and authenticated functional/security tests still required before cutover.')

try:
    stage()
except Exception as e:
    print(str(e) if isinstance(e,RuntimeError) else 'Functions staging stopped; keep private logs and secrets on the VPS.',file=sys.stderr)
    sys.exit(1)
