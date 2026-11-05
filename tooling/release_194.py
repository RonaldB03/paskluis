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
    request = urllib.request.Request(
        APPLE + path, headers={"Authorization": "Bearer " + token()})
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


if __name__ == "__main__":
    inspect_apple()
    inspect_google()
