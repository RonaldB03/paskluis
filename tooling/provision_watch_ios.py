"""Provision only the watch companion, reusing the phone's installed certificate.

Runs on the Codemagic Mac. Never creates/revokes certificates, changes the phone
identifier, or updates an existing profile. Credentials stay in the runner.
"""
import base64
import datetime as dt
import json
import os
from pathlib import Path
import plistlib
import subprocess
import time
import urllib.error
import urllib.parse
import urllib.request

PHONE = "nl.paskluis.app"
WATCH = PHONE + ".watchkitapp"
API = "https://api.appstoreconnect.apple.com/v1/"


def valid_profile(profile, bundle, now):
    return (
        profile.get("Entitlements", {}).get("application-identifier", "").endswith("." + bundle)
        and profile.get("ExpirationDate", dt.datetime.min) > now
        and not profile.get("Entitlements", {}).get("get-task-allow", True)
        and not profile.get("ProvisionedDevices")
        and not profile.get("ProvisionsAllDevices", False)
    )


def installed_certificates(directory, now):
    certificates = set()
    for path in directory.glob("*.mobileprovision"):
        result = subprocess.run(["security", "cms", "-D", "-i", str(path)],
                                capture_output=True, check=True)
        profile = plistlib.loads(result.stdout)
        if valid_profile(profile, PHONE, now):
            certificates.update(profile.get("DeveloperCertificates", []))
    if not certificates:
        raise RuntimeError("No valid installed App Store profile for the PasKluis phone app")
    return certificates


def token():
    from cryptography.hazmat.primitives import hashes, serialization
    from cryptography.hazmat.primitives.asymmetric import ec, utils
    def b64(data):
        return base64.urlsafe_b64encode(data).rstrip(b"=")
    def part(data):
        return b64(json.dumps(data, separators=(",", ":")).encode())
    now = int(time.time())
    header = {"alg": "ES256", "kid": os.environ["APP_STORE_CONNECT_KEY_IDENTIFIER"], "typ": "JWT"}
    body = {"iss": os.environ["APP_STORE_CONNECT_ISSUER_ID"], "iat": now,
            "exp": now + 900, "aud": "appstoreconnect-v1"}
    raw = os.environ["APP_STORE_CONNECT_PRIVATE_KEY"]
    key_data = Path(raw[6:]).read_bytes() if raw.startswith("@file:") else raw.encode()
    key = serialization.load_pem_private_key(key_data, password=None)
    message = part(header) + b"." + part(body)
    r, s = utils.decode_dss_signature(key.sign(message, ec.ECDSA(hashes.SHA256())))
    return (message + b"." + b64(r.to_bytes(32, "big") + s.to_bytes(32, "big"))).decode()


def main():
    if os.environ.get("WATCH_BETA") != "1":
        raise RuntimeError("WATCH_BETA=1 required")
    directory = Path.home() / "Library/MobileDevice/Provisioning Profiles"
    now = dt.datetime.now(dt.timezone.utc).replace(tzinfo=None)
    local_certs = installed_certificates(directory, now)
    bearer = token()

    def request(path, payload=None):
        url = path if path.startswith(API) else API + path
        if not url.startswith(API):
            raise RuntimeError("Unexpected API URL")
        data = json.dumps(payload).encode() if payload else None
        req = urllib.request.Request(url, data=data, headers={
            "Authorization": "Bearer " + bearer, "Content-Type": "application/json"})
        try:
            with urllib.request.urlopen(req, timeout=60) as response:
                return json.load(response)
        except urllib.error.HTTPError as error:
            # Do not print response bodies, credentials or provisioning data.
            raise RuntimeError(f"Apple signing API returned HTTP {error.code} for {path.split('?')[0]}") from None

    def records(path):
        while path:
            page = request(path)
            yield from page["data"]
            path = page.get("links", {}).get("next")

    cert_ids = [c["id"] for c in records("certificates?limit=200")
                if base64.b64decode(c["attributes"].get("certificateContent", "")) in local_certs]
    if not cert_ids:
        raise RuntimeError("The phone signing certificate was not found in this Apple account")
    bundles = list(records("bundleIds?" + urllib.parse.urlencode({"filter[identifier]": WATCH})))
    bundles = [b for b in bundles if b["attributes"]["identifier"] == WATCH]
    if not bundles:
        bundle = request("bundleIds", {"data": {"type": "bundleIds", "attributes": {
            "identifier": WATCH, "name": "PasKluis Watch", "platform": "IOS"}}})["data"]
    else:
        bundle = bundles[0]
    selected = None
    for profile in records(f"bundleIds/{bundle['id']}/profiles?limit=200"):
        attrs = profile["attributes"]
        if attrs.get("profileState") != "ACTIVE" or attrs.get("profileType") != "IOS_APP_STORE":
            continue
        contents = base64.b64decode(attrs["profileContent"])
        decoded = subprocess.run(["security", "cms", "-D"], input=contents,
                                 capture_output=True, check=True)
        info = plistlib.loads(decoded.stdout)
        if valid_profile(info, WATCH, now) and local_certs.intersection(info.get("DeveloperCertificates", [])):
            selected = profile
            break
    if selected is None:
        selected = request("profiles", {"data": {"type": "profiles", "attributes": {
            "name": "PasKluis Watch beta " + str(int(time.time())), "profileType": "IOS_APP_STORE"},
            "relationships": {"bundleId": {"data": {"type": "bundleIds", "id": bundle["id"]}},
                              "certificates": {"data": [{"type": "certificates", "id": c} for c in cert_ids]}}}})["data"]
    attrs = selected["attributes"]
    directory.mkdir(parents=True, exist_ok=True)
    # UUID is from Apple, but still constrain the filename to its basename.
    filename = Path(attrs["uuid"]).name + ".mobileprovision"
    (directory / filename).write_bytes(base64.b64decode(attrs["profileContent"]))
    print("Watch companion profile ready; phone profile and certificates unchanged.")


if __name__ == "__main__":
    main()
