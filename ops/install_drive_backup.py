#!/usr/bin/env python3
"""Install the reviewed units using an existing authorized gdrive remote."""
import configparser
import os
from pathlib import Path
import shutil
import subprocess

os.umask(0o077)
source = Path(__file__).resolve().parent
destination = Path('/opt/paskluis-supabase/tools/offsite')
config_dir = Path('/etc/paskluis-drive')
state_dir = Path('/var/lib/paskluis-offsite')
for folder in [destination, config_dir, state_dir]:
    folder.mkdir(parents=True, exist_ok=True, mode=0o700)
config_path = config_dir / 'rclone.conf'
if not config_path.exists():
    existing = configparser.RawConfigParser()
    existing.read('/root/.config/rclone/rclone.conf')
    if not existing.has_section('gdrive') or existing['gdrive'].get('type') != 'drive':
        raise SystemExit('Expected authorized gdrive remote missing')
    scoped = configparser.RawConfigParser()
    scoped['paskluis-drive'] = dict(existing['gdrive'])
    scoped['paskluis-drive']['root_folder_id'] = '1K7mPH9sEAsTLTalN92QPZkrSoh6w7Off'
    with config_path.open('x') as stream:
        scoped.write(stream)
    config_path.chmod(0o600)
shutil.copyfile(source / 'drive_backup.py', destination / 'drive_backup.py')
(destination / 'drive_backup.py').chmod(0o700)
for name in ['paskluis-offsite.service', 'paskluis-offsite.timer']:
    target = Path('/etc/systemd/system') / name
    # Preserve a previous definition when applying a future reviewed update.
    if target.exists() and not target.with_suffix(target.suffix + '.before').exists():
        shutil.copyfile(target, target.with_suffix(target.suffix + '.before'))
    target.write_text((source / name).read_text())
    target.chmod(0o644)
subprocess.run(['systemd-analyze', 'verify', '/etc/systemd/system/paskluis-offsite.service',
                '/etc/systemd/system/paskluis-offsite.timer'], check=True)
subprocess.run(['systemctl', 'daemon-reload'], check=True)
print('Installed offsite service. Timer not enabled until first upload is verified.')
