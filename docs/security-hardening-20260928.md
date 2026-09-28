# Security hardening — 28 September 2026

## Implemented and verified

- Anonymous callers can no longer execute staff-role changes, legacy card sharing
  or last-seen updates. Authenticated sharing and guest support remain available.
- Internal trigger functions are no longer directly executable by app clients.
- Active-device access, device claims/validation and backup operations reject
  deleted and expired Auth sessions.
- Login sessions and PKCE login-link verifiers use FlutterSecureStorage, with
  migration from preferences only after a verified secure write. Logout removes
  the migration source so an old session cannot be restored accidentally.
- Android protects app windows against screenshots/screen recording.
- Revealed gift-card PINs are hidden when the app leaves the foreground.
- The admin portal supports TOTP authenticator enrollment and step-up login.
  Wrong codes do not open the portal; canceling removes the newly created,
  unverified factor; enrollment secrets are removed from the page afterwards.

## Verification

- Separate, free Supabase test project in the existing organization; no production
  users, card data, credentials, Edge workers or scheduled outbound jobs copied.
- All schema migrations plus the security changes applied. Data-only logo
  migrations 016/017 omitted: their production catalog preconditions do not hold
  in a clean database, and they do not affect security behavior.
- SQL integration tests pass for device takeover, old/expired/deleted sessions,
  backup session validation, internal support notes, guest acknowledgments,
  purchase refunds and independent staff-granted Plus access. Fixtures roll back;
  no Auth users, support threads or notification jobs remain afterwards.
- Production function definitions match the tested definitions.
- GitHub CI: Flutter analysis completed; all 79 Flutter tests pass. Existing
  unused-element warnings remain unrelated to these changes.
- All 42 local Node tests pass, including six admin MFA UI tests and six Edge authorization tests.
- Source commit for mobile release: 2b815890a54491a91e8682c7146b199bc596883f.
- Admin MFA publication: fdb43ec087d1b54cfd2c91330e1c82d71a3aeb9f.

## Rollout boundary

Mobile release builds target TestFlight and the Google Play closed Alpha track.
Starting a build is not proof that store processing/review has completed.

**MFA is now enforced by the database and privileged Edge Functions.**
- Staff portal login requires enrollment or an existing-factor challenge before
  loading management data. Staff without a factor must enroll on next login.
- `is_admin` / `is_staff` require JWT AAL2, a live unexpired AAL2 Auth session and
  its matching verified factor. Database policies, Storage logo writes and
  privileged RPCs use these helpers; backup-admin access also checks `is_admin`.
- `invite-staff`, legacy `clever-endpoint` and `support-attachments` use the caller
  JWT through the same RPC checks, never a service-role authorization shortcut.
- Isolated tests cover AAL1 denial, valid AAL2 admin/support access, role isolation,
  expired/deleted/downgraded sessions, revoked factors, RPCs and Storage writes.
- Production read-only checks confirm the enrolled owner session is allowed and
  the equivalent password-only claims are denied. No real account was modified
  or impersonated for a write test.
- Live Edge source was read back and matches the tested implementation.

Recovery must use an independently secured Supabase project-owner account and
Supabase's administrative MFA-factor removal API after identity verification.
Do not add an unauthenticated reset endpoint or temporarily disable MFA globally.
A real lost-authenticator recovery drill is still pending; protect the owner
account and retain an independent recovery method.

Build rollout verified: Android version code 83 was uploaded to closed Alpha.
iOS build processing completed, the build was added to Paskluis Testers and was
submitted for beta review (WAITING_FOR_REVIEW at submission). Neither statement
implies that a later store review has already finished.

Enrollment may sign out other sessions of the same account. Never put TOTP
secrets, recovery codes or production credentials in source, reports or logs.

## Remaining work / limits

- Independent owner-account recovery setup and a controlled recovery drill.
- Independent encrypted disaster backups plus a restore drill, separate from
  users' card backups. No VPS job has been configured by this change.
- Managed local card images are not yet encrypted at application level. Existing
  Hive card data is encrypted. Encrypting images requires migrating every reader,
  writer and backup consumer without losing current files.
- Cloud card backups use authenticated encryption but are not end-to-end
  encrypted: authorized server code can access their encryption keys. E2EE needs
  a recovery-key design that also supports lost-phone recovery.
- Leaked-password protection requires a paid Supabase plan and remains disabled.
- Password-change reauthentication needs matching app UX before enforcement.
- Clipboard expiry, admin dependency pinning/CSP and additional public-endpoint
  abuse protection remain audit follow-ups.
- Physical-device validation is still needed for secure-storage migration,
  Android screenshot blocking and PIN hiding across app interruptions.
- This is security hardening, not a guarantee of absolute security or an
  independent penetration test.

Supabase advisories intentionally remain for service-only tables with deny-all
RLS and narrowly scoped SECURITY DEFINER functions. Review each function's
permissions and internal checks; do not remove warnings by granting broad access.
