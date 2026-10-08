"""Read-only export of Google's unprotected, Play-signed APKs for owner testing."""
import hashlib
import json
import os
from pathlib import Path
from urllib.parse import quote
from zipfile import ZipFile, ZIP_DEFLATED

from google.oauth2.service_account import Credentials
from google.auth.transport.requests import AuthorizedSession

version = int(os.environ.get("TEST_VERSION_CODE", "103"))
credentials = Credentials.from_service_account_info(
    json.loads(os.environ["GOOGLE_PLAY_SERVICE_ACCOUNT_CREDENTIALS"]),
    scopes=["https://www.googleapis.com/auth/androidpublisher"],
)
session = AuthorizedSession(credentials)
base = f"https://androidpublisher.googleapis.com/androidpublisher/v3/applications/nl.paskluis.app/generatedApks/{version}"
response = session.get(base, timeout=60)
response.raise_for_status()
metadata = response.json()
output = Path("play-test-export")
output.mkdir(exist_ok=True)
entries = []
with ZipFile(output / f"play-test-{version}.zip", "w", ZIP_DEFLATED) as archive:
    for key_index, group in enumerate(metadata.get("generatedApks", [])):
        for kind in ("unprotectedGeneratedStandaloneApks", "unprotectedGeneratedSplitApks"):
            for index, apk in enumerate(group.get(kind, [])):
                url = base + "/downloads/" + quote(apk["downloadId"], safe="") + ":download"
                result = session.get(url, params={"alt": "media"}, timeout=180)
                result.raise_for_status()
                if not result.content.startswith(b"PK"):
                    raise RuntimeError("Google did not return an APK archive")
                filename = f"key{key_index}/{kind}/{index}.apk"
                archive.writestr(filename, result.content)
                entries.append({**apk, "file": filename, "kind": kind,
                    "certificateSha256Hash": group["certificateSha256Hash"],
                    "sha256": hashlib.sha256(result.content).hexdigest()})
        print("Signing group", key_index, "exported entries:", len(entries), flush=True)
    if not entries:
        raise RuntimeError("No unprotected Google-generated APKs available; no fallback to protected APKs")
    archive.writestr("index.json", json.dumps({"version": version, "entries": entries,
        "targeting": [g.get("targetingInfo", {}) for g in metadata.get("generatedApks", [])]}, indent=2))
print(f"Exported {len(entries)} signed APKs for private testing. No Play release or protection setting changed.")
