import datetime as dt
import hashlib
import json
import pathlib
import tempfile
import unittest
import drive_backup


class Backups(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.folder = pathlib.Path(self.temp.name)
        self.name = dt.datetime.now(dt.timezone.utc).strftime('%Y%m%dT%H%M%SZ.pkb')
        self.archive = self.folder / self.name
        self.archive.write_bytes(b'PKB1synthetic encrypted fixture')
        self.report = {'archive': '/server/' + self.name, 'bytes': self.archive.stat().st_size,
                       'sha256': hashlib.sha256(self.archive.read_bytes()).hexdigest()}
        self.write_report()

    def write_report(self):
        (self.folder / 'latest.json').write_text(json.dumps(self.report))

    def test_valid_and_corrupt(self):
        self.assertEqual(drive_backup.validate(self.folder)[0], self.archive)
        self.archive.write_bytes(b'PKB1changed')
        with self.assertRaises(ValueError):
            drive_backup.validate(self.folder)

    def test_rejects_plaintext_and_stale_archives(self):
        self.archive.write_bytes(b'not encrypted')
        with self.assertRaises(ValueError):
            drive_backup.validate(self.folder)
        self.archive.write_bytes(b'PKB1synthetic encrypted fixture')
        with self.assertRaises(ValueError):
            drive_backup.validate(self.folder, dt.datetime.now(dt.timezone.utc) + dt.timedelta(days=2))

    def test_no_manifest_when_remote_hash_is_wrong(self):
        calls = []
        def run(command, **kwargs):
            calls.append(command)
            return type('Result', (), {'stdout':'bad  file\n'})()
        with self.assertRaises(ValueError):
            drive_backup.upload(self.folder, 'config', runner=run)
        self.assertEqual(len(calls), 2)
        self.assertTrue(all('latest.json' not in ' '.join(c) for c in calls))

    def test_only_archive_then_verified_manifests_leave_machine(self):
        calls = []
        md5 = hashlib.md5(self.archive.read_bytes(), usedforsecurity=False).hexdigest()
        def run(command, **kwargs):
            calls.append(command)
            return type('Result', (), {'stdout': md5 + '  file\n'})()
        result = drive_backup.upload(self.folder, 'config', runner=run)
        self.assertTrue(result['automatic_offsite'])
        self.assertEqual(len(calls), 4)
        self.assertIn('--immutable', calls[0])
        self.assertEqual(calls[-1][3], 'paskluis-drive:latest.json')
        self.assertTrue(all(drive_backup.FOLDER in c for c in calls))


if __name__ == '__main__':
    unittest.main()
