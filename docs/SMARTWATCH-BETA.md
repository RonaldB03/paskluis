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
  The Wear app has package `nl.paskluis.app`. Store builds set `WATCH_VERSION_CODE`
  above the phone code; local builds default to 1,000,143. Phone and watch MUST
  have the same signing certificate. Use both
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
Four local profile-selection safety tests pass; signed build 146 subsequently
confirmed provisioning and upload. A TestFlight build installed by the owner
updates their local test app; the publicly distributed App Store app is unchanged.

The GitHub starter is `.github/workflows/watch-ios-testflight.yml` and is restricted
to `codex/smartwatch-beta`. Its initial Codemagic build is
`6accd326d0025cd97ad5ecd5`; do not start duplicates while that build is queued/running.

## Private tester distribution (13 October 2026)

- Public App Store and Google Play releases are outside this beta workflow.
- Internal iPhone build 146 (1.9.1) is available in the owner-only internal group.
  External tester build 147 (1.9.2) also built and uploaded successfully.
- `ios-smartwatch-external-beta` uploads to TestFlight without App Store
  submission or automatic distribution to existing tester groups.
- The external group `PasKluis Apple Watch beta` is separate from the existing
  general testers. Assign only the verified watch build to this group.
- Build 147 was assigned to that one-tester group and submitted to Beta App
  Review. App Store Connect confirmed `Waiting for Review`; automatic tester
  notification is enabled. The existing general external group was not selected.
- `android-smartwatch-beta` produces signed phone and Wear OS bundles with
  distinct version codes. Both use the existing upload key and package name.
  It has no automatic publishing configuration.
- Google Play has separate `smartwatch-beta` closed tracks for mobile and
  Wear OS, both restricted to the new `PasKluis smartwatch beta` mailing list.
  Neither track may be promoted to production as part of this request.
- Google Play accepted phone code 105 and Wear OS code 106, both version 1.9.2.
  The two closed releases, their one-tester list, Wear OS opt-in and two Wear
  screenshots were submitted for review. No production release was included.
- Wear OS screenshots are generated from the real Activity in an emulator by
  test-only instrumentation with synthetic cards. `FLAG_SECURE` remains enabled.
- Emulator storage/read/erase checks passed in run 38468020341. Native watch
  validation and release regression checks passed for commit 5638183. Signed
  tester build workflow 38467293035 completed successfully for both platforms.
- Tester email addresses are kept in the stores, not this public repository.
- Store review and real-device tests remain necessary. Do not describe prepared
  tracks or successful compilations as an available installation.

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
| iPhone + fēnix 6 / fēnix 7 | Garmin Connect callback, Bluetooth permission denied/allowed, device selection, receipt ACK |
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

## Garmin iOS callback regression (14 October 2026)

The first phone test returned from Garmin Connect without displaying any watch
in PasKluis. The watch app was running and Garmin Connect showed a connected
device. The Runner plist does not opt into UIScene, so handling the callback
only in SceneDelegate misses the AppDelegate URL entry point.

Internal TestFlight 1.9.2 (148), source commit `195e99e`, was built and uploaded
successfully. The internal beta now handles the Garmin URL in AppDelegate under WATCH_BETA,
preserving Flutter's fallback for other URLs. Both lifecycle entry points use
WatchBridge.shared so the Garmin bridge exists even before method-channel
registration. No public release workflow is changed.

Device retest: update the internal TestFlight build, open the watch app, choose
Garmin in the phone's smartwatch settings and run device selection again.
Verify that the fēnix 7 appears, select it, allow Bluetooth if prompted, then
synchronize one selected card. Confirm receipt on both screens. Also test a
callback after terminating the phone app, and ordinary non-Garmin deep links.
Compilation and automated snapshot/service tests do not prove physical receipt;
that remains a device acceptance check.

### Wear OS refinement and offline store logos (14 October 2026)

Jordi installed the internal phone and Wear OS builds and displayed an Albert
Heijn barcode on his Galaxy Watch8. A checkout scanner test remains outstanding.
The next Wear OS beta adds a dark card list with store logos, favorites first,
rotary scrolling, a last-received timestamp and a separate settings screen with
confirmation before local erase/reconnect. The scan screen uses integer barcode
modules, temporary full brightness and a 45-second awake limit.

Only logos of selected eligible cards are exported from the phone. Thumbnails
are optional 64-pixel PNGs, at most 4,500 bytes each, sent beside the unchanged
bounded barcode snapshot. Missing logos use a letter tile. The watch stores
them encrypted with matching owner and revision and clears them on local erase.
The watch does not download logos itself. Both Android phone and watch updates
are needed; synchronize once after updating to populate the logos.

Validation: 15 targeted Flutter tests and static analysis pass. Android and
Apple compilation pass in run 38545803636. Full Flutter regression checks pass.
Wear emulator run 38547014273 passes encrypted logo storage, owner isolation,
erase, scan brightness and restoration, and captures the real list/barcode/QR/
settings views. ZXing independently decodes both rendered screenshot codes to
their original synthetic values. Brightness assertions run on the UI thread.
Signed Android bundles were built from 41743ce by Codemagic build
6acf519cde779117a460a978 (phone 107, watch 108, version 1.9.2).

Acceptance checks: verify AH and another store logo, favorites order, scrolling
on a round watch, a barcode and a QR code, brightness restoration after backing
out and after timeout, offline reopening, erase cancellation and confirmed
erase. Public releases and Apple/Garmin distribution are outside this update.

### Follow-up: repeated Garmin synchronization

The fēnix 7 received and displayed a card with phone build 148, but subsequent
syncs left the watch's retry warning and the phone's unconfirmed status visible.
Monkey C owner strings were compared by object identity. Compare their content
with `equals` so separately decoded snapshots from the same phone are accepted.
The language and reconnect menu string comparisons use the same correction.
A retry of the stored revision clears an earlier receive error and resends its
receipt; it does not acknowledge locally erased content or older revisions.

Three fēnix 7 simulator tests cover consecutive updates, rejection of another
owner, and duplicate receipt/older revision handling. All pass after the fix.
Restoring only the old owner comparison in a separate test copy reproduces two
test failures. Receipt probes verify storage precedes acknowledgment; Bluetooth
receipt still requires a physical-device retest.

Replacement watch binary: `build/garmin-fenix7-sync-fix/PKBETA.prg`.
SHA-256: `E20EE3A98BE6F1182C10A9CB9D6B2B51A5206B6CA3BB9A145BC01A4D7911213E`.
This update requires replacing the sideloaded watch binary; phone build 148
already includes the callback fix. No new phone or public store release needed.

### Legacy QR format and selection diagnostics

The device retest confirmed receipt on the phone, plus successful Air Miles
selection. A legacy Fietsenstalling QR card was incorrectly exported as a linear
barcode: the exporter only checked codeFormat, ignoring type=QR-code. Source
commit `76b6543` preserves either QR marker and adds a regression using an
EAN-valid numeric value, without changing the stored source card or code.

Gall & Gall is rejected before transport; its exact validation failure has not
yet been observed. The beta now displays the rejected card name and distinguishes
unsupported format, invalid code, rendering dimensions, code length, total size
and card count. Never shorten a real code or silently change its symbology.

All 14 targeted Flutter tests passed. The independent scanner check passed for
11 synthetic fixtures, including a legacy numeric QR card decoded as QR with its
original value. Physical retest: update the internal phone beta, synchronize
Fietsenstalling again, check its QR display, then select Gall & Gall and report
the specific message. No watch USB update is needed for this phone export fix.


### Wear OS refinement: fixed watch and automatic selection sync (14 October 2026)

- Wear launcher/header use the existing PasKluis icon. Store marks sit inside white circles without cropping; the list omits offline counts and receipt timestamps.
- Phone setup selects one reachable Wear app advertising `paskluis_addressed_watch`, or one Garmin. Platform and selected passes persist until explicit disconnection. Existing beta users select their watch once after updating both apps; their previous platform selection is retained for the first sync.
- Selections sync automatically, including empty selections. Durable preferences retain the latest selection through failures/restarts; app resume and a 20-second pending retry restore failed transfers. Wear Data Layer retains accepted transfers while the watch is offline. Garmin still needs Garmin Connect and its watch app available; retries require the phone app running/resuming.
- Wear snapshots use a device-addressed path and acknowledgements must originate from the chosen node. Legacy watches ignore that path; the new watch ignores old unaddressed snapshots. Unlink removes queued Wear data before another node can be selected. Already delivered offline copies may remain and the unlink dialog explains how to erase them.
- Flutter regression tests cover persistent pairing, refusing a second platform, remove/re-add, offline/restart recovery, and edits during an in-flight send. Native tests cover wrong-device delivery and acknowledgement rejection. Emulator preview uses five synthetic cards and checks that the list scrolls.
- Only the internal Android/Wear workflow is triggered for distribution. No public release or Apple external test distribution is changed.

Automatic pending retries respect a confirmed local watch erase until the phone selection is edited again. Status reads await cached Wear acknowledgements before deciding whether to retry.

Validation and internal delivery: Android/Apple compilation and full Flutter checks
passed for 6b28f4c (runs 38563634035 and 38563634108). Emulator run
38564456232 passed with final UI, five-card scrolling, barcode/QR screens,
brightness restoration, encrypted storage and erase checks. The scroll test
captures and asserts the same UI frame to avoid asynchronous view replacement.
Phone widget tests cover toggle/remove/re-add without a manual sync button.

Signed source: 6b28f4c320194369dca6a2466c6d8a4d6cbb5635, Codemagic
6acf75358164b8ee6f198b27. Internal publication confirmed 14 October 2026 14:49:
phone 109 / release 49 / track 4701274852138143157; Wear 110 / release 3 /
track 4697492455578368389. Both version 1.9.2, existing tester groups unchanged.
Phone SHA-256: 4038CDD2D5AEE2B8DBB083245E4FC288214617A09FEB5E5E3579F60E77BCE0B0.
Wear SHA-256: D73D2D354E7AF0C196B84C4CD3777E3D6F55E59415565B13D7F144A41BD8D6FB.

Physical acceptance remains with Jordi: update both apps, choose Watch8 once,
remove and re-add a card, reopen settings, check offline recovery and scrolling.
Public distribution and Apple external beta remain unchanged.

### Three categories across Wear OS, Apple Watch and Garmin (14 October 2026)

The phone now selects cards within Klantenkaarten, QR-codes and Cadeaukaarten.
Selection remains shared across these views and every change uses the existing
fixed-watch automatic synchronization. The combined limit remains twelve cards
and the existing payload/rendering bounds still apply. Category follows the
source card type, independently of barcode symbology; a QR gift card remains a
gift card and a numeric legacy QR remains QR.

Gift exports use the same explicit allowlist as loyalty and QR cards. PINs,
balances and notes never enter the snapshot. Archived/shared/received cards
remain excluded. The phone explains that the gift-code copy can be spent.

Wear OS and Apple Watch provide three category controls and horizontal paging,
with vertically scrolling card lists. Wear uses a circular launcher mask and
explicit circular canvas clipping for its header. Apple receives the same
bounded optional store-logo payload and clips its header and thumbnails round.
Garmin uses UP/DOWN and START for category/card navigation, BACK to return,
and a scrolling three-row list. Its header and launcher use the PasKluis mark.

Validation: 21 targeted Flutter tests and analysis passed. Native Android and
Apple compilation passed; full Flutter release checks passed. Independent
ZXing decoding passed all 13 synthetic fixtures, including gift EAN/QR and
legacy numeric QR. Wear emulator run 38577297636 passed category navigation,
scrolling, storage/erase and brightness restoration; the rendered barcode,
gift barcode and QR decoded to their original synthetic values. Its software
capture exposed a square header, corrected with explicit canvas clipping in
831724d and covered by a pixel assertion in 53a8691.

Garmin builds succeeded for fenix6, fenix6pro, fenix6s, fenix6spro, fenix6xpro
and fenix7. All four fenix7 simulator tests passed, including category isolation.
The USB package is build/PasKluis-Garmin-categorieen-2026-10-14.zip, with model
binaries, installation instructions and checksums. Physical installation and
checkout scanner acceptance remain device checks; no claim of those follows
from compilation or synthetic decoding.

Final Wear emulator run 38579752831 passed, including transparent-corner and
opaque-center assertions on the real PasKluis header. Final screenshots are in
build/watch-round-categories-preview/store-preview. The round header was also
visually verified. Apple signed build 1.9.2 (150), including its watch companion,
was uploaded by Codemagic 6acf8bfe9ceaf9a3bae479ba and is processing in App Store
Connect; this is not yet external tester availability.
