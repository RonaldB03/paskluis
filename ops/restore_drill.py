#!/usr/bin/env python3
"""Explicitly authorized, network-isolated logical restore of the Drive copy."""
import argparse
import datetime
import json
import os
import re
from pathlib import Path
import shutil
import subprocess
import tarfile
import time

ROOT = Path('/tmp/paskluis-restore-01a1078b')
STAGING = Path('/tmp/paskluis-offsite-01a1078b')
NAME = 'paskluis-restore-01a1078b'
IMAGE = 'supabase/postgres:17.11.0.003@sha256:7374d196da7e301512cc5329e18040e0f7bb856287b323777cdadecccbc6c7e4'
LABEL = 'paskluis.restore-drill=01a1078b'
os.umask(0o077)


def run(args, **kwargs):
    return subprocess.run(args, check=True, capture_output=True, **kwargs)


def sql(query):
    return run(['docker', 'exec', NAME, 'psql', '-h', '/tmp', '-U', 'supabase_admin',
                '-d', 'postgres', '-v', 'ON_ERROR_STOP=1', '-Atc', query]).stdout.decode().strip()


def prepare():
    if ROOT.exists():
        raise RuntimeError('Existing drill directory; inspect before reuse')
    ROOT.mkdir(mode=0o700)
    with tarfile.open(STAGING / 'restore.tar.gz', 'r:gz') as archive:
        archive.extractall(ROOT / 'input', filter='data')
    for file in ['database.dump', 'roles.sql']:
        path = ROOT / 'input' / file
        os.chown(path, 0, 101)
        path.chmod(0o440)
    config = ROOT / 'input/configuration/postgresql-custom'
    for path in [config, *config.rglob('*')]:
        if path.is_symlink():
            raise RuntimeError('Unexpected config symlink')
        os.chown(path, 100, 101)
    (ROOT / 'data').mkdir(mode=0o700)
    os.chown(ROOT / 'data', 100, 101)
    command = ('initdb -D /restore-data -U supabase_admin --auth-local=trust --auth-host=reject > /tmp/init.log 2>&1 && '
               'exec postgres -D /restore-data -c listen_addresses= -c unix_socket_directories=/tmp '
               '-c shared_preload_libraries=pg_stat_statements,pgaudit,plpgsql,plpgsql_check,pg_cron,pg_net,pgsodium,auto_explain,pg_tle,plan_filter,supabase_vault '
               '-c cron.database_name=postgres -c cron.launch_active_jobs=off '
               '-c pgsodium.getkey_script=/usr/lib/postgresql/bin/pgsodium_getkey.sh')
    run(['docker', 'run', '-d', '--name', NAME, '--label', LABEL,
         '--network', 'none', '--cpus', '1', '--memory', '1g', '--user', '100:101',
         '--security-opt', 'no-new-privileges', '--cap-drop', 'ALL',
         '--mount', f'type=bind,source={ROOT}/data,target=/restore-data',
         '--mount', f'type=bind,source={config},target=/etc/postgresql-custom,readonly',
         '--mount', f'type=bind,source={ROOT}/input/database.dump,target=/database.dump,readonly',
         '--mount', f'type=bind,source={ROOT}/input/roles.sql,target=/roles.sql,readonly',
         '--entrypoint', '/bin/sh', IMAGE, '-c', command])
    for _ in range(40):
        try:
            sql('select 1')
            break
        except subprocess.CalledProcessError:
            time.sleep(0.5)
    else:
        raise RuntimeError('Test database did not become ready')
    info = json.loads(run(['docker', 'inspect', NAME]).stdout)[0]
    assert info['HostConfig']['NetworkMode'] == 'none'
    assert not info['HostConfig']['PortBindings']
    assert all(m['Source'].startswith(str(ROOT) + '/') for m in info['Mounts'])
    assert sql('show cron.launch_active_jobs') == 'off'
    print('Fresh isolated database ready; no production mounts or network.')


def restore():
    # PostgreSQL 17 records superuser grants as the bootstrap role. Initdb must
    # use the original supabase_admin name, and its CREATE ROLE is skipped.
    existing = set(sql('select rolname from pg_roles').splitlines())
    role_lines = []
    switched = False
    for line in (ROOT / 'input/roles.sql').read_text().splitlines():
        created = re.fullmatch(r'CREATE ROLE ([a-zA-Z0-9_]+);', line)
        if created and created[1] in existing:
            continue
        if line.startswith('GRANT ') and not switched:
            role_lines.append('SET ROLE supabase_admin;')
            switched = True
        role_lines.append(line)
    role_lines.append('RESET ROLE;')
    role_input = ('\n'.join(role_lines) + '\n').encode()
    for phase, command in [
        ('roles', ['psql', '-h', '/tmp', '-U', 'supabase_admin', '-d', 'postgres', '-v', 'ON_ERROR_STOP=1']),
        ('database', ['pg_restore', '-h', '/tmp', '-U', 'supabase_admin', '-d', 'postgres', '--clean', '--if-exists', '--exit-on-error', '--single-transaction', '/database.dump']),
    ]:
        result = subprocess.run(['docker', 'exec', '-i', NAME, *command], capture_output=True,
                                input=role_input if phase == 'roles' else None)
        (ROOT / (phase + '.stdout')).write_bytes(result.stdout)
        (ROOT / (phase + '.stderr')).write_bytes(result.stderr)
        if result.returncode:
            raise RuntimeError(phase + ' restore failed; inspect private diagnostic category')
        print(phase + ' restored successfully.')


def verify():
    counts = json.loads(sql("""select json_build_object(
      'users',(select count(*) from auth.users),
      'storage_objects',(select count(*) from storage.objects),
      'vault_secrets',(select count(*) from vault.decrypted_secrets),
      'vault_readable',(select count(*) from vault.decrypted_secrets where decrypted_secret is not null),
      'public_tables',(select count(*) from pg_tables where schemaname='public'),
      'rls_tables',(select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind='r' and c.relrowsecurity),
      'invalid_indexes',(select count(*) from pg_index where not indisvalid)
    )"""))
    assert counts['vault_secrets'] == counts['vault_readable']
    assert counts['invalid_indexes'] == 0
    references = json.loads(sql("select coalesce(json_agg(json_build_object('bucket',bucket_id,'name',name,'version',version)),'[]') from storage.objects"))
    storage = ROOT / 'input/storage'
    files = [p for p in storage.rglob('*') if p.is_file()]
    missing = 0
    for row in references:
        # FILE storage uses tenant/bucket/name[/version]. Metadata files are also retained.
        candidates = [p for p in files if ('/' + row['bucket'] + '/' + row['name']) in p.as_posix()]
        if not candidates:
            missing += 1
    assert missing == 0, 'Storage objects missing from archive'
    assert len(files) == 190
    counts.update(storage_files=len(files), missing_storage_references=missing)
    result = {'checked_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
              'archive': '20261004T022214Z.pkb', 'image': IMAGE, 'network': 'none',
              'cron_jobs_disabled': sql('show cron.launch_active_jobs') == 'off',
              'logical_restore_passed': True, 'counts': counts}
    (STAGING / 'restore-result.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result))


def cleanup():
    assert ROOT.resolve() == Path('/tmp/paskluis-restore-01a1078b')
    info = subprocess.run(['docker', 'inspect', NAME], capture_output=True)
    if info.returncode == 0:
        container = json.loads(info.stdout)[0]
        assert container['Config']['Labels'].get('paskluis.restore-drill') == '01a1078b'
        assert container['HostConfig']['NetworkMode'] == 'none'
        run(['docker', 'rm', '-f', NAME])
    if ROOT.exists():
        shutil.rmtree(ROOT)
    (STAGING / 'restore.tar.gz').unlink(missing_ok=True)
    print('Removed isolated container, test data and plaintext archive.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('phase', choices=['prepare', 'restore', 'verify', 'cleanup'])
    args = parser.parse_args()
    try:
        globals()[args.phase]()
    except Exception as error:
        print(json.dumps({'phase': args.phase, 'error': type(error).__name__, 'detail': str(error) if isinstance(error, (RuntimeError, AssertionError)) else 'See private diagnostics'}))
        raise SystemExit(1)
