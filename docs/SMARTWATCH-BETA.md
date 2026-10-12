# PasKluis smartwatch beta

Scope: selected personal loyalty cards and individual QR codes, favourites first,
offline display, full replacement on edit/delete, explicit receipt acknowledgement,
local erase. Gift cards, PINs, notes, images, received/shared cards and QR sets are
excluded. Limit: 12 cards, 7,000 UTF-8 bytes, 192 barcode modules or 49×49 QR modules.
Some dense codes will not fit smaller watches and explicitly require the phone.

## Build and distribution

The phone entry appears only with `--dart-define=WATCH_BETA=true`. Normal phone
builds do not expose this unfinished beta. No production store release is part of
this change. Do not add testers to a production publishing workflow.

- Flutter: `flutter pub get`, `flutter analyze --no-fatal-infos`,
  `flutter test --dart-define=WATCH_BETA=true` (includes the beta-only sync tests).
- Android phone: `flutter build apk --debug --dart-define=WATCH_BETA=true`.
- Wear OS: from `android`, `gradle :wear:assembleDebug :wear:testDebugUnitTest`.
  The Wear app has package `nl.paskluis.app`, with separate version codes beginning
  at 1,000,143. Phone and watch MUST have the same signing certificate. Use both
  debug APKs together, or the same Google Play app signing identity for both beta
  tracks. A locally signed watch cannot communicate with a differently Play-signed
  phone build. Minimum Wear OS API level: 30.
- iOS/watchOS: on a Mac with Xcode and CocoaPods, set `WATCH_BETA=1`, run
  `ruby tooling/configure_watch_ios.rb`, then
  `flutter build ios --config-only --no-codesign --dart-define=WATCH_BETA=true`,
  `cd ios && pod install`. Build the Runner scheme. The script adds the companion
  target, embeds it and pins Garmin's official ConnectIQ Swift package to 1.8.0.
  Distribution needs a provisioning profile for `nl.paskluis.app.watchkitapp` in
  addition to the phone profile, and synchronized version/build numbers. Never
  run the project-generation script in an ordinary production checkout before
  a production archive. Use a disposable beta checkout/CI runner.
- Garmin: install Garmin Connect IQ SDK Manager, sign in and install the fēnix 6
  family device profiles. The generic compiler check does NOT validate device
  resources, minimum API availability or runtime memory. From `garmin`, run
  `monkeyc -f monkey.jungle -d fenix6 -y /private/developer_key.der -o ../build/paskluis-fenix6.prg`.
  Repeat for `fenix6pro`, `fenix6s`, `fenix6spro`, `fenix6xpro`. Store a real release
  signing key outside Git and keep it for future updates. The generated local key
  under the parent workspace's `.tooling` is development-only. App UUID is
  `5fdfca89-1939-4cb8-b3bb-d96184aa208c`. Register the Connect IQ listing, check its
  store UUID against the iOS bridge, and distribute a beta before inviting testers.
  Garmin Android SDK is pinned to 2.4.0. SDK Manager uses the owner's existing
  Garmin Connect login. Login and device downloads completed on 12 October 2026;
  a separate Connect IQ Store listing has not been created.

`.github/workflows/watch-beta-validation.yml` compiles the native clients without
store publishing. Its debug artifacts are for paired testing only, not App Store
or Play distribution. Final build results and outstanding failures belong in the
implementation handoff; the presence of the workflow does not prove a passed run.

## Verified locally on 12 October 2026

- All 131 Flutter tests passed with `WATCH_BETA=true`.
- All six Wear OS protocol tests passed (revision ordering, local erase,
  duplicate acknowledgement, owner/source changes, invalid grids, leading zeroes).
- The ten transmitted synthetic barcode/QR fixtures were independently decoded
  by zxing-cpp. The watch renderers still need optical tests on actual devices.
- Targeted Dart analysis reports no issues. `git diff --check` passes.
- Wear OS and Android phone debug assembly passed. Both APK signatures were
  verified and have the same SHA-256 certificate fingerprint:
  `c23e178f9c6bfae45c5e311a2c176f90e34602d3e70bd96b547055becb603480`.
  The paired local package is `build/paskluis-android-watch-beta.zip`; its README
  explains installation on a test device without removing a production vault.
- Garmin SDK 9.2.0 device builds passed for `fenix6`, `fenix6pro`, `fenix6s`,
  `fenix6spro` and `fenix6xpro` after SDK Manager login. The fēnix 6 build reports
  1,705 bytes of static foreground data, 4,748 bytes of code and a 98,844-byte PRG.
  These are compiler statistics, not a measurement of peak runtime memory.
  Gradual type checking still emits dynamic-container warnings. Real-device
  pairing, runtime and scanning checks remain required.
- The isolated `codex/smartwatch-beta` branch was pushed with the owner's approval.
  macOS successfully built the iPhone app (including the Garmin bridge) and embedded
  Apple Watch app without signing. Android phone/Wear builds also passed remotely.
  Validated source commit: `e54b381a2c753d5269edc749ad828cfe577f3d8e`.
  Run: https://github.com/RonaldB03/paskluis/actions/runs/38247795141
  The first Apple run exposed a watch-copy/Flutter Thin Binary dependency cycle;
  placing the watch embed phase before Thin Binary resolved it in the successful run.
  Existing release-regression checks also passed. No store release was triggered.
- Garmin device-specific sideload builds and instructions are packaged in
  `build/paskluis-garmin-fenix6-beta.zip`. Select the exact model folder.
  iPhone distribution still requires a separate signed beta build and provisioning;
  the unsigned Mac compilation does not produce an installable iPhone beta.
- No real phone/watch pairing, scanner testing or store distribution has occurred.

## Internal iPhone installation build

`ios-smartwatch-beta` in `codemagic.yaml` is isolated from all existing workflows.
It prepares the watch target before applying provisioning profiles, enables
`WATCH_BETA`, and archives with `testFlightInternalTestingOnly: true`. Publishing
uploads to App Store Connect without App Store submission or external beta review.
The current internal TestFlight group `Test Ro` contains the owner only and has
automatic build distribution enabled. Verify processing and group availability
before telling the owner to install an update.

`tooling/provision_watch_ios.py` uses Codemagic's Apple integration and the
certificate already installed for the phone. It may create only the companion
identifier `nl.paskluis.app.watchkitapp` and its new profile. It does not create or
revoke certificates, alter the phone identifier/profile, or print credentials.
Four local profile-selection safety tests pass; the signed remote build must
still confirm provisioning and upload. A TestFlight build installed by the owner
updates their local test app; the publicly distributed App Store app is unchanged.

The GitHub starter is `.github/workflows/watch-ios-testflight.yml` and is restricted
to `codex/smartwatch-beta`. Its initial Codemagic build is
`6accd326d0025cd97ad5ecd5`; do not start duplicates while that build is queued/running.

## Sync and privacy contract

`schema:1`, `owner` (random per phone installation), increasing `revision`,
`language` and a complete `cards` array form a snapshot. Card fields are exactly
`id`, `name`, `code`, `favorite`, `width`, `height`, `bits`. Bits are lowercase hex,
row-major and most-significant-bit first; trailing unused nibble bits are zero.
Render at integer module sizes on white, with 10 quiet modules for 1D codes and
4 on every side of a QR code. Never change the code format to make it fit.

The phone persists selection, watches persist the received snapshot. Selection
changes, card-store events and foreground resume trigger sync. Garmin requires a
selected device and an open watch app; retries occur on subsequent phone syncs.
Apple Watch uses latest application context. Wear OS uses one latest DataItem.
An empty snapshot revokes all cards. Only acknowledge AFTER successful storage.
Queued or sent is not the same as confirmed by the watch. Offline deletion is
eventual; no design can remotely erase a disconnected watch immediately.

An owner mismatch is rejected until the watch is explicitly reconnected. Garmin
device switching is blocked until the prior copy has been confirmed empty (if a
copy was previously submitted). A user who loses that watch can explicitly forget
the connection after confirming the warning that this does NOT erase the offline
copy. Remove its app or clear it through vendor tooling wherever possible.

Apple Watch stores its snapshot in a device-only, when-unlocked Keychain item.
Android uses a non-exportable AndroidKeyStore AES-GCM key and an atomic ciphertext
file in the no-backup directory. Garmin uses app-private Application.Storage;
this is NOT equivalent to the encrypted phone vault. The selection screen says
so. The phone's Face ID/app lock does not protect copies on any watch. Garmin
does not receive PINs or gift cards. Barcode data are not logged or put in crash
messages. No new PasKluis cloud endpoint, account token or location access is used.
Wear Data Layer may route encrypted transport through Google's infrastructure;
do not describe the feature as Bluetooth-only.

## Test matrix before inviting the full group

Use synthetic cards first, then the tester's own explicitly selected loyalty cards.

| Combination | Required checks |
|---|---|
| iPhone + Apple Watch | Install companion, background delivery, Keychain persistence, watch lock, dimmed display |
| Android + Wear OS | Matched signatures, round/small screens, listener after process death, offline restart |
| iPhone + fēnix 6 | Garmin Connect callback, Bluetooth permission denied/allowed, device selection, receipt ACK |
| Android + Garmin | Garmin Connect missing/available, device selection, app not open, ACK and retry |

For every row: select and remove cards; edit a visible card; delete while the code
is open; archive a selected card; send an empty selection while offline then
reconnect; interrupt a transfer; restart both devices; submit an older revision;
erase locally; switch phone owner; switch Garmin; open an unsupported/oversized
code; scan EAN-13, EAN-8, Code128, Code39 and QR at real scanners. Keep leading
zeroes. Verify read failures show an error rather than a fabricated success.

Independent barcode check: run `dart run tooling/watch_fixtures.dart`, then
`python tooling/verify_watch_barcodes.py` with Pillow and zxing-cpp installed.
It decodes synthetic transmitted patterns; it does not replace real optical
scanner tests. Collect watch model, phone OS, code format, expected behaviour,
observed result and reproduction steps. Do not collect actual card numbers/PINs.

Release only after device builds, pairing/sync, privacy checks and in-store scans
have passed. Add store metadata and a reviewed privacy-text update before beta
distribution. There are no live balance, payment, NFC or automatic location features.
