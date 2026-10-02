#!/usr/bin/env python3
"""Restore the Cloud user-profile trigger omitted from the schema export."""
import json
import os
from pathlib import Path
import subprocess
import sys
from datetime import datetime, timezone

ROOT = Path('/opt/paskluis-supabase')
WORK = ROOT / 'migration-checks'

def sql(query):
    r = subprocess.run(['docker', 'compose', 'exec', '-T', 'db', 'psql', '-X', '-U',
                        'supabase_admin', '-d', 'postgres', '-At', '-v', 'ON_ERROR_STOP=1',
                        '-v', 'VERBOSITY=sqlstate'], input=query, text=True, capture_output=True, cwd=ROOT)
    if r.returncode:
        (WORK / 'auth-profile-repair-private.log').write_text(r.stdout + r.stderr)
        raise RuntimeError('Profile trigger repair failed; transaction rolled back; private log retained.')
    return r.stdout.strip()

def main():
    if os.geteuid() != 0 or not (ROOT / '.paskluis-import-complete').exists():
        raise RuntimeError('Run on the imported staging VPS only.')
    WORK.mkdir(exist_ok=True, mode=0o700)
    actual = sql("select md5(replace(pg_get_functiondef('public.handle_new_user()'::regprocedure),chr(13),''));")
    if actual != 'a4e2ada1c885dc0c2f649506d096625c':
        raise RuntimeError('Existing user-profile function differs from verified Cloud definition.')
    rows = sql("select count(*) from pg_trigger where tgrelid='auth.users'::regclass and not tgisinternal;")
    if rows != '0':
        raise RuntimeError('Auth triggers already exist; inspect before changing them.')
    stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    backup = Path('/var/backups/paskluis-supabase') / ('profile-trigger-' + stamp)
    backup.mkdir(mode=0o700)
    with (backup / 'auth-schema-before.sql').open('w') as out:
        r = subprocess.run(['docker', 'compose', 'exec', '-T', 'db', 'pg_dump', '-U',
                            'supabase_admin', '-d', 'postgres', '--schema-only', '--schema=auth'],
                           cwd=ROOT, stdout=out, stderr=subprocess.PIPE, text=True)
    if r.returncode:
        raise RuntimeError('Auth schema backup failed; nothing changed.')
    sql('''begin;
set local lock_timeout='5s';
create trigger on_auth_user_created after insert on auth.users
for each row execute function public.handle_new_user();
commit;
''')
    # Tests exercise the real trigger, then roll back every synthetic row.
    sql('''begin;
insert into auth.users(id,email,raw_user_meta_data)
values ('ee440000-0000-4000-8000-000000000099','vps-profile-test@example.invalid','{}');
do $$begin
 if not exists (select 1 from public.profiles where id='ee440000-0000-4000-8000-000000000099'
 and role='user' and email='vps-profile-test@example.invalid') then
 raise exception 'PROFILE_CREATION_FAILED'; end if;
end$$;
rollback;
''')
    if sql("select count(*) from auth.users where id='ee440000-0000-4000-8000-000000000099';") != '0':
        raise RuntimeError('Synthetic account rollback check failed.')
    print('Cloud profile trigger restored and automatic profile creation verified.', flush=True)
    print('Synthetic account rolled back. Existing accounts unchanged.', flush=True)

if __name__ == '__main__':
    os.umask(0o077)
    try:
        main()
    except Exception as error:
        print(str(error) if isinstance(error, RuntimeError) else
              'Profile repair stopped; no private data printed.', flush=True)
        sys.exit(1)
