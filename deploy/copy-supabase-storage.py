#!/usr/bin/env python3
"""Read-only Cloud S3 source; copy into localhost VPS Storage and retain owners."""
import csv
import getpass
import io
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path('/opt/paskluis-supabase')
os.umask(0o077)
os.chdir(ROOT)
if os.geteuid() != 0 or not (ROOT/'.paskluis-import-complete').is_file():
    raise SystemExit('Run as root after the database import.')
WORK = ROOT/'migration-storage'
WORK.mkdir(exist_ok=True, mode=0o700)

def db(sql):
    r = subprocess.run(['docker','compose','exec','-T','db','psql','-X','-U','supabase_admin','-d','postgres',
                        '-At','-v','ON_ERROR_STOP=1','-v','VERBOSITY=sqlstate'], input=sql, text=True, capture_output=True)
    if r.returncode:
        (WORK/'database-error.log').write_text(r.stderr)
        raise RuntimeError('Storage database step failed; private log retained on VPS.')
    return r.stdout

def run(args, label):
    with (WORK/(label+'.log')).open('w') as err:
        r = subprocess.run(['rclone','--config',str(WORK/'rclone.conf'),*args], text=True, stdout=subprocess.PIPE, stderr=err)
    if r.returncode:
        raise RuntimeError('Storage step failed: '+label+'. Private log retained on VPS; do not share it.')
    return r.stdout

def restore_owners(rows):
    buffer = io.StringIO()
    csv.writer(buffer, lineterminator='\n').writerow([json.dumps(rows, separators=(',',':'))])
    sql = '''BEGIN;
CREATE TEMP TABLE migration_storage_owners (payload jsonb) ON COMMIT DROP;
COPY migration_storage_owners (payload) FROM stdin WITH (FORMAT csv);
''' + buffer.getvalue() + '''\\.
DO $$ BEGIN
 IF EXISTS (
   SELECT 1 FROM migration_storage_owners m, jsonb_array_elements(m.payload) x
   LEFT JOIN storage.objects o ON o.bucket_id=x->>'bucket_id' AND o.name=x->>'name'
   WHERE o.id IS DISTINCT FROM (x->>'id')::uuid
 ) THEN RAISE EXCEPTION 'Storage object identity changed'; END IF;
END $$;
UPDATE storage.objects o SET owner=(x->>'owner')::uuid, owner_id=x->>'owner_id',
 created_at=(x->>'created_at')::timestamptz, user_metadata=NULLIF(x->'user_metadata','null'::jsonb)
FROM migration_storage_owners m, jsonb_array_elements(m.payload) x
WHERE o.bucket_id=x->>'bucket_id' AND o.name=x->>'name';
COMMIT;
'''
    db(sql)

def main():
    if not (WORK/'objects-before.json').exists():
        original = db("select coalesce(jsonb_agg(to_jsonb(o) order by bucket_id,name),'[]'::jsonb) from storage.objects o;")
        (WORK/'objects-before.json').write_text(original)
    rows = json.loads((WORK/'objects-before.json').read_text())
    buckets = json.loads(db("select coalesce(jsonb_agg(id order by id),'[]'::jsonb) from storage.buckets;"))
    if set(buckets) != {'brand-logos','support-attachments','card-backups','public-content'}:
        raise RuntimeError('Unexpected bucket configuration; stop for inspection.')
    env = {}
    for line in (ROOT/'.env').read_text().splitlines():
        if line and not line.startswith('#') and '=' in line:
            k,v = line.split('=',1); env[k] = v.strip().strip('"')
    config = WORK/'rclone.conf'
    if not config.exists():
        print('Enter the temporary Cloud S3 credentials here; input stays hidden.')
        key = getpass.getpass('S3 Access Key ID: ')
        secret = getpass.getpass('S3 Secret access key: ')
        if not key or not secret or any(c in key+secret for c in '\r\n'):
            raise RuntimeError('Invalid S3 credential input.')
        config.write_text('[platform]\ntype=s3\nprovider=Other\naccess_key_id='+key+'\nsecret_access_key='+secret+
            '\nendpoint=https://ajldblvvlbvmgejrmhyj.supabase.co/storage/v1/s3\nregion=eu-west-1\nforce_path_style=true\n'+
            '\n[vps]\ntype=s3\nprovider=Other\naccess_key_id='+env['S3_PROTOCOL_ACCESS_KEY_ID']+
            '\nsecret_access_key='+env['S3_PROTOCOL_ACCESS_KEY_SECRET']+
            '\nendpoint=http://127.0.0.1:8800/storage/v1/s3\nregion='+env['REGION']+'\nforce_path_style=true\n')
        config.chmod(0o600)
    # Confirm the live source matches the snapshot; never silently import new
    # private objects without their corresponding owners and application rows.
    for bucket in buckets:
        source = json.loads(run(['lsjson','platform:'+bucket,'--recursive','--files-only'],bucket+'-source-list'))
        wanted = {r['name'] for r in rows if r['bucket_id']==bucket}
        if {r['Path'] for r in source} != wanted:
            raise RuntimeError('Cloud file list changed since snapshot: '+bucket+'. Stop for a consistent snapshot.')
    touched = False
    try:
        for bucket in buckets:
            print('Copying bucket:',bucket, flush=True)
            touched = True
            # Imported metadata alone can make rclone skip missing physical
            # bytes. Force upload, then verify by downloading both sides.
            run(['copy','platform:'+bucket,'vps:'+bucket,'--ignore-times','--metadata',
                 '--transfers','4','--checkers','4','--retries','2'],bucket+'-copy')
    finally:
        if touched:
            restore_owners(rows)
    for bucket in buckets:
        run(['check','platform:'+bucket,'vps:'+bucket,'--download','--checkers','4'],bucket+'-verify')
        print('Byte verification passed:',bucket, flush=True)
    actual = json.loads(db("select coalesce(jsonb_agg(to_jsonb(o) order by bucket_id,name),'[]'::jsonb) from storage.objects o;"))
    indexed = {(r['bucket_id'],r['name']):r for r in actual}
    if len(indexed) != len(rows):
        raise RuntimeError('Object count mismatch; stop before cutover.')
    for old in rows:
        new = indexed[(old['bucket_id'],old['name'])]
        if any(new[k] != old[k] for k in ('id','owner','owner_id','created_at','user_metadata')):
            raise RuntimeError('Storage ownership/metadata verification failed.')
    (ROOT/'.paskluis-storage-copy-complete').write_text(str(len(rows))+'\n')
    print('Copied and verified physical files:',len(rows))
    print('Object identities, owners and user metadata preserved. Production unchanged.')
    print('S3 credentials remain in a root-only VPS file for the final migration check; do not share it.')

if __name__ == '__main__':
    try:
        main()
    except Exception as e:
        # Do not print exception payloads from network/database libraries.
        if isinstance(e, RuntimeError):
            print(str(e), file=sys.stderr)
        else:
            print('Storage migration stopped. Report the last completed step; keep private logs on VPS.', file=sys.stderr)
        sys.exit(1)
