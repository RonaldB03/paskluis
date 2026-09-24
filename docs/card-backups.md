# PasKluis account backups

Status: closed-test rollout only. The production app does not upload existing cards without consent.

## User behavior

Settings > Backup offers opt-in automatic backup, manual upload, a history of three versions, restore, and deletion. The account must own the active device session. A fresh installation with an existing cloud history must restore before uploading. Restore merges by card ID and asks whether to keep local conflicts or use the backup. Received shared cards are excluded; restoring cannot resurrect revoked sharing rights. Displayed gift card balances are historical user-entered values.

Each card is assigned a backup owner on explicit enablement or when created with backup enabled. Foreign-account cards are never automatically reassigned. Local personal cards keep the existing offline behavior after sign-out. Do not remove `backupOwnerId` when editing a card.

Automatic uploads are debounced for 15 seconds in the foreground. Pending failures are retried every two minutes while foregrounded; reopening the app also retries. Background delivery is not guaranteed. The last successful version is displayed rather than implying every local edit is already safe.

## Storage and cryptography

`card-backups` is private and has an explicit restrictive policy denying all direct anon/authenticated access. All requests pass through `card-backups` Edge Function, Auth.getUser, and a check of both auth.sessions and account_device_sessions. Server-only functions have no anon/authenticated execution grant.

The device uses cryptography's AES-256-GCM, random 12-byte nonces, a per-account 32-byte key, and AAD containing protocol version, account ID and content SHA-256. Images are resized to at most 1600 pixels on the longer side, losslessly encoded as PNG, and content-addressed per account. The manifest is independently encrypted. PINs, identifiers and images never appear in object names or logs.

Account keys live in the non-exposed `backup_private` schema, accessible only through restricted server functions. They are delivered to the authenticated active device over TLS and held in memory, not persisted in preferences. This is server-managed encryption, not end-to-end encryption. Password reset does not destroy keys. Deleting cloud backups rotates the account key and generation.

The 10,000,000-byte quota covers all unique retained ciphertext objects across at most three versions. A transient upload can use additional staging space while the last good backup remains intact. The server decrypts and validates submitted objects before uploading, checks proposed retention quota, uploads immutable files, then atomically commits metadata. Cleanup follows commit; orphaned files from interrupted requests are cleaned during the next account operation. The exclusive three-minute lease serializes account operations. Failed quota checks roll back history changes.

## Deployment and verification

Migration: `supabase/migrations/20260924205628_card_backups.sql`.
Functions: `card-backups` and updated `delete-account`.
The migration enables only accounts existing at migration time. New accounts default to disabled. Before broad rollout, replace the allowlist deliberately; do not assume all registered users have backup access.

Run Flutter tests, Node tests, and the rollback-only `supabase/tests/backup_database.sql`. That SQL inserts synthetic users and sessions inside a transaction and rolls it back; it must never return keys or real account content.

Admin > backup summary in the app displays counts, used bytes and failures without card content. Review capacity at 50 backed-up users or 70% of relevant storage/transfer quotas. Total organizational transfer must be checked in Supabase Billing > Usage; database object bytes alone are not a traffic meter.

## Independent recovery copy — required before broad rollout

NOT CONFIGURED by this feature. Three versions within Supabase are not an independent disaster-recovery copy, and a provider database backup does not contain Storage file contents.

Before opening beyond the test group, provision an independently secured destination and retention policy. Export the `backup_private` schema (including account keys, generations and version metadata) AND the referenced `card-backups` objects as a consistent set. Encrypt the complete export with a separate recovery key stored outside both the export destination and Supabase. Restrict operator access and log only counts/checksums. Pause uploads during export or use a checkpoint that retains every referenced object until export completes. Do not place plaintext keys, database dumps or card exports in GitHub or CI artifacts.

Test recovery into an isolated environment with synthetic cards: restore metadata and keys, copy objects, validate checksums, confirm account ownership and restore on both platforms. Define deletion propagation and maximum retention for disaster-recovery copies before creating any copies of user data. Existing test uploads have no independent recovery guarantee until this is implemented.
