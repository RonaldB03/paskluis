"""Inspect and promote the existing PasKluis 1.9.4 store builds."""
import argparse
import json
import os
import subprocess
import urllib.error
import urllib.parse
import urllib.request

from provision_watch_ios import token

APPLE = "https://api.appstoreconnect.apple.com/v1/"
APP = "6764876159"
PACKAGE = "nl.paskluis.app"
VERSION = "1.9.4"


def apple(path):
    url = path if path.startswith("https://api.appstoreconnect.apple.com/") else APPLE + path
    request = urllib.request.Request(
        url, headers={"Authorization": "Bearer " + token()})
    try:
        with urllib.request.urlopen(request, timeout=45) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        payload = json.loads(error.read())
        print(json.dumps({"apple_errors": payload.get("errors", [])}))
        raise


def inspect_apple():
    query = urllib.parse.urlencode({
        "filter[app]": APP, "filter[preReleaseVersion.version]": VERSION,
        "include": "preReleaseVersion", "limit": 100,
    })
    builds = apple("builds?" + query)["data"]
    print(json.dumps({"apple_builds": [
        {"id": b["id"], **b["attributes"]} for b in builds]}))
    versions = apple(f"apps/{APP}/appStoreVersions?limit=20")["data"]
    print(json.dumps({"apple_versions": [
        {"id": v["id"], **v["attributes"]} for v in versions]}))
    availability = apple(f"apps/{APP}/appAvailabilityV2")["data"]
    path = availability["relationships"]["territoryAvailabilities"]["links"]["related"]
    territories = []
    while path:
        page = apple(path)
        territories.extend(page["data"])
        path = page.get("links", {}).get("next")
    print(json.dumps({"apple_available_territories": [
        {"id": t["id"], "attributes": t["attributes"],
         "territory": t.get("relationships", {}).get("territory", {}).get("data")}
        for t in territories if t["attributes"].get("available")]}))
    return builds, versions


def google_session():
    from google.oauth2.service_account import Credentials
    from google.auth.transport.requests import AuthorizedSession
    credentials = Credentials.from_service_account_info(
        json.loads(os.environ["GOOGLE_PLAY_SERVICE_ACCOUNT_CREDENTIALS"]),
        scopes=["https://www.googleapis.com/auth/androidpublisher"])
    return AuthorizedSession(credentials)


def inspect_google():
    session = google_session()
    base = ("https://androidpublisher.googleapis.com/androidpublisher/v3/"
            f"applications/{PACKAGE}/edits")
    response = session.post(base, json={}, timeout=45)
    response.raise_for_status()
    edit = response.json()["id"]
    tracks = session.get(f"{base}/{edit}/tracks", timeout=45)
    tracks.raise_for_status()
    print(json.dumps({"google_tracks": tracks.json()["tracks"]}))
    session.delete(f"{base}/{edit}", timeout=45).raise_for_status()


def promote_apple():
    builds, versions = inspect_apple()
    selected = [b for b in builds if b["id"] == "d9c09895-063a-401c-8d91-b4849df034ef"]
    assert len(selected) == 1
    assert selected[0]["attributes"]["processingState"] == "VALID"
    assert selected[0]["attributes"]["version"] == "155"
    current = [v for v in versions if v["attributes"]["versionString"] == VERSION]
    submitted = {"WAITING_FOR_REVIEW", "IN_REVIEW", "PENDING_APPLE_RELEASE",
                 "PROCESSING_FOR_APP_STORE", "READY_FOR_SALE"}
    if current and current[0]["attributes"]["appStoreState"] in submitted:
        print(json.dumps({"apple_already_submitted": current[0]}))
        return
    command = [
        "app-store-connect", "builds", "submit-to-app-store",
        selected[0]["id"], "--version-string", VERSION,
        "--release-type", "AFTER_APPROVAL", "--no-phased-release",
        "--whats-new",
        "PasKluis ondersteunt nu ook Belgische winkels. Je vindt Nederlandse en "
        "Belgische winkels in één zoeklijst. Winkels uit je ingestelde regio "
        "krijgen voorrang en dubbele winkelnamen worden samengevoegd.",
    ]
    result = subprocess.run(command, text=True, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT)
    with open("apple-promotion.log", "w") as output:
        output.write(result.stdout)
    print(json.dumps({"apple_submit_exit": result.returncode,
                      "apple_submit_output": result.stdout[-18000:]}))
    if result.returncode:
        raise RuntimeError("Apple submission failed; see apple-promotion.log")
    inspect_apple()


def promote_google():
    session = google_session()
    base = ("https://androidpublisher.googleapis.com/androidpublisher/v3/"
            f"applications/{PACKAGE}/edits")
    response = session.post(base, json={}, timeout=45)
    response.raise_for_status()
    edit = response.json()["id"]
    committed = False
    try:
        track_response = session.get(f"{base}/{edit}/tracks/internal", timeout=45)
        track_response.raise_for_status()
        candidates = [
            r for r in track_response.json().get("releases", [])
            if r.get("name") == VERSION and r.get("versionCodes") == ["120"]
            and r.get("status") == "completed"]
        assert len(candidates) == 1, "Expected tested Android 1.9.4 (120)"
        production = session.get(f"{base}/{edit}/tracks/production", timeout=45)
        production.raise_for_status()
        releases = production.json().get("releases", [])
        print(json.dumps({"google_production_before": production.json()}))
        availability = session.get(
            f"{base}/{edit}/countryAvailability/production", timeout=45)
        print(json.dumps({"google_countries_status": availability.status_code,
                          "google_countries": availability.json()}))
        if any(r.get("versionCodes") == ["120"] and
               r.get("status") == "completed" for r in releases):
            print(json.dumps({"google_already_promoted": True}))
            return
        assert all(int(code) < 120 for r in releases
                   for code in r.get("versionCodes", [])), "Newer production build found"
        payload = {"track": "production", "releases": [{
            "name": VERSION, "versionCodes": ["120"], "status": "completed",
            "releaseNotes": [{
                "language": "nl-NL",
                "text": "PasKluis ondersteunt nu ook Belgische winkels. Nederlandse "
                        "en Belgische winkels staan in één zoeklijst. Winkels uit "
                        "je ingestelde regio krijgen voorrang en dubbele "
                        "winkelnamen worden samengevoegd."}]}]}
        updated = session.put(f"{base}/{edit}/tracks/production",
                              json=payload, timeout=45)
        updated.raise_for_status()
        validation = session.post(f"{base}/{edit}:validate", timeout=45)
        if not validation.ok:
            print(json.dumps({"google_validation_error": validation.json()}))
        validation.raise_for_status()
        result = session.post(
            f"{base}/{edit}:commit",
            params={"changesInReviewBehavior": "ERROR_IF_IN_REVIEW"}, timeout=60)
        if not result.ok:
            print(json.dumps({"google_commit_error": result.json()}))
        result.raise_for_status()
        committed = True
        print(json.dumps({"google_commit": result.json()}))
    finally:
        if not committed:
            session.delete(f"{base}/{edit}", timeout=45).raise_for_status()
    inspect_google()


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--promote", action="store_true")
    arguments = parser.parse_args()
    if arguments.promote:
        failures = []
        for platform, promote in [("google", promote_google), ("apple", promote_apple)]:
            try:
                promote()
            except Exception as error:
                failures.append(platform)
                print(json.dumps({"promotion_failed": platform,
                                  "error": str(error)}))
        if failures:
            raise SystemExit(1)
    else:
        inspect_apple()
        inspect_google()
