#!/usr/bin/env python3
"""Upload only a verified, encrypted PasKluis archive. Never upload recovery keys."""
import argparse
import datetime as dt
import hashlib
import json
import os
import pathlib
import re
import subprocess
import tempfile

FOLDER = '1K7mPH9sEAsTLTalN92QPZkrSoh6w7Off'
BACKUPS = pathlib.Path('/var/backups/paskluis-supabase/daily')
STATE = pathlib.Path('/var/lib/paskluis-offsite/status.json')


def validate(folder, now=None):
    report = json.loads((folder / 'latest.json').read_text())
    name = pathlib.PurePosixPath(report['archive']).name
    if not re.fullmatch(r'\d{8}T\d{6}Z\.pkb', name):
        raise ValueError('Unexpected archive name')
    archive = folder / name
    if archive.is_symlink() or not archive.is_file():
        raise ValueError('Archive must be a regular file')
    created = dt.datetime.strptime(name, '%Y%m%dT%H%M%SZ.pkb').replace(tzinfo=dt.timezone.utc)
    age = (now or dt.datetime.now(dt.timezone.utc)) - created
    if age < dt.timedelta(minutes=-10) or age > dt.timedelta(hours=30):
        raise ValueError('Latest backup is missing or stale')
    sha, md5 = hashlib.sha256(), hashlib.md5(usedforsecurity=False)
    with archive.open('rb') as stream:
        if stream.read(4) != b'PKB1':
            raise ValueError('Refusing unencrypted backup')
        stream.seek(0)
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            sha.update(chunk)
            md5.update(chunk)
    if sha.hexdigest() != report['sha256'] or archive.stat().st_size != report['bytes']:
        raise ValueError('Backup checksum or size mismatch')
    return archive, report, md5.hexdigest()


def upload(folder, config, runner=subprocess.run):
    archive, report, md5 = validate(folder)
    common = ['--config', str(config), '--drive-root-folder-id', FOLDER,
              '--retries', '3', '--low-level-retries', '5', '--contimeout', '30s',
              '--timeout', '5m', '--log-level', 'ERROR']

    def rclone(*args):
        return runner(['/usr/bin/rclone', *args, *common], check=True,
                      capture_output=True, text=True, timeout=1200).stdout

    target = 'paskluis-drive:' + archive.name
    rclone('copyto', str(archive), target, '--checksum', '--immutable')
    hashes = rclone('md5sum', target).splitlines()
    if len(hashes) != 1 or hashes[0].split()[0].lower() != md5:
        raise ValueError('Google Drive checksum verification failed')
    # Publish a manifest only after the encrypted object has been verified.
    manifest = {**report, 'archive': archive.name, 'automatic_offsite': True,
                'offsite_verified_at': dt.datetime.now(dt.timezone.utc).isoformat()}
    with tempfile.TemporaryDirectory(prefix='paskluis-offsite-') as temp:
        source = pathlib.Path(temp) / 'manifest.json'
        source.write_text(json.dumps(manifest, indent=2) + '\n')
        source.chmod(0o600)
        rclone('copyto', str(source), 'paskluis-drive:' + archive.stem + '.json', '--checksum')
        rclone('copyto', str(source), 'paskluis-drive:latest.json', '--checksum')
    return manifest


def record(status, path=STATE):
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    staged = path.with_suffix('.tmp')
    staged.write_text(json.dumps(status, indent=2) + '\n')
    staged.chmod(0o600)
    staged.replace(path)


def main():
    os.umask(0o077)
    parser = argparse.ArgumentParser()
    parser.add_argument('--check-local', action='store_true')
    args = parser.parse_args()
    if args.check_local:
        archive, _, _ = validate(BACKUPS)
        print(json.dumps({'local_verified': True, 'archive': archive.name}))
        return
    config = pathlib.Path('/etc/paskluis-drive/rclone.conf')
    previous = json.loads(STATE.read_text()) if STATE.exists() else {}
    try:
        manifest = upload(BACKUPS, config)
        record({'ok': True, 'archive': manifest['archive'], 'sha256': manifest['sha256'],
                'last_success': manifest['offsite_verified_at'], 'folder_id': FOLDER})
        print('Encrypted backup uploaded and remote checksum verified.')
    except Exception as error:
        # Do not log OAuth credentials, process output or plaintext contents.
        record({**previous, 'ok': False, 'last_attempt': dt.datetime.now(dt.timezone.utc).isoformat(),
                'error': type(error).__name__})
        raise SystemExit('Offsite backup failed; previous copies have been retained.') from None


if __name__ == '__main__':
    main()
