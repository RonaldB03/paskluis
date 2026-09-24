"""Submit only the authorized PasKluis 1.5.0 (102) to its existing tester group.

Uses the existing Codemagic Apple integration. No credentials are read or logged.
"""
import json
import subprocess
import time


def asc(*args, capture=False):
    result = subprocess.run(
        ['app-store-connect', *args], check=True,
        stdout=subprocess.PIPE if capture else None,
        text=True,
    )
    return json.loads(result.stdout) if capture else None


for attempt in range(20):
    builds = asc('builds', 'list', '--app-id', '6764876159',
                 '--build-version-number', '102', '--pre-release-version', '1.5.0',
                 '--not-expired', '--json', capture=True)
    if isinstance(builds, dict):
        builds = builds.get('data', [builds] if 'id' in builds else [])
    if builds:
        break
    print('Waiting for PasKluis 1.5.0 (102) to appear in App Store Connect.', flush=True)
    time.sleep(30)
else:
    raise RuntimeError('The authorized build 102 was not found; no other build was changed.')

if len(builds) != 1:
    raise RuntimeError('Expected exactly one matching build; nothing changed.')
build = builds[0]
if str(build['attributes']['version']) != '102':
    raise RuntimeError('Unexpected build version; nothing changed.')
build_id = build['id']
print('Selected PasKluis 1.5.0 (102):', build_id, flush=True)
asc('builds', 'add-beta-test-info', build_id, '--locale', 'nl-NL', '--whats-new',
    'Test de leesbaarheid van de locatie-uitleg op het beginscherm, ook met grotere letters. '
    'Bij klantenkaart toevoegen kun je na de winkelkeuze nu Handmatig barcode invoeren kiezen.')
asc('builds', 'submit-to-testflight', build_id, '--max-build-processing-wait', '10')
asc('beta-groups', 'add-build', build_id, '--beta-group', 'Paskluis Testers')
asc('builds', 'beta-details', build_id, '--json')
print('Build 102 submitted and added to Paskluis Testers.', flush=True)
