# Internal Apple receipt verifier

Keyless internal Docker service, using Apple's official `@apple/app-store-server-library` 3.1.0 and the public Apple G2/G3 trust anchors from https://www.apple.com/certificateauthority/.

The Supabase Edge Runtime v1.76.2 cannot run this library directly (`crypto.X509Certificate.prototype.toString` is unimplemented). The Node service validates signatures, trust chains and OCSP with online checks. Edge Functions then make a fresh authenticated Apple lookup and validate transaction identity, product, bundle and environment before recording access. This service has no App Store credentials, no Supabase keys and no database access. It publishes no host ports.

Installed at `/opt/paskluis-supabase/store-verifier`, container `paskluis-store-verifier`, Docker alias `store-verifier`, same private network as the functions service. Node image pinned to `node@sha256:0a7108bf6c7bf5de370ffb1a3ed6be93d405b43ff159f681a8d18c0e2bc2e402`. Dependencies installed with `npm ci --omit=dev --ignore-scripts`. Directory mode 0755, code read-only in container, UID/GID 1000, all capabilities dropped, no-new-privileges, 192 MiB memory, 0.5 CPU, restart unless-stopped. `/tmp` is an isolated 16 MiB noexec/nosuid tmpfs.

`POST /verify` accepts a bounded signed Apple proof and an `allowSandbox` boolean; only the internal function chooses whether sandbox is allowed. Returned fields are used only after the signature is checked. Errors log fixed event names and numeric verification statuses, never proofs or personal data. A crash or verification outage fails closed; the app retains only its bounded, previously verified offline access.

`deploy/probe-store-verification.py` runs on the VPS, obtains the newest existing Apple purchase from the ledger, fetches its signed receipt directly from Apple and verifies it through the new API without transferring the purchase. Output is limited to status booleans. No new payment is made.

The existing production verification endpoint remains available for 1.7.0 clients. Rollback backups of the router, purchase tables, admin source and reconciliation function are under `/var/backups/paskluis-supabase/accountless-*` and `purchase-ui-*`. Do not remove the additive schema after clients have started using the new route.
