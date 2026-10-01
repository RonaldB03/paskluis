#!/usr/bin/env bash
# Publish only the four live-support admin assets. Homepage and server configuration are untouched.
set -euo pipefail
release_commit="${1:?Usage: bash update-admin-live-support.sh FULL_COMMIT_SHA}"
[[ "$release_commit" =~ ^[0-9a-f]{40}$ ]] || { echo "Expected a full commit SHA" >&2; exit 1; }
admin_root=/var/www/paskluis-admin/public
[[ -d "$admin_root" && -f "$admin_root/index.html" && -f "$admin_root/app.js" ]] || { echo "Existing admin directory was not found" >&2; exit 1; }
stage_dir=$(mktemp -d)
trap 'rm -rf "$stage_dir"' EXIT
for asset in support-settings.js styles.css app.js index.html; do
  curl --fail --silent --show-error --location --retry 2 "https://raw.githubusercontent.com/RonaldB03/paskluis/$release_commit/admin/$asset" --output "$stage_dir/$asset"
done
cd "$stage_dir"
sha256sum --check <<'CHECKSUMS'
d9881e6f77d3f8cba8bc7d0edaec31ca2be1654346a2e4b4012b1831abdbdad2  support-settings.js
8d7d689ce563ccb98e2f9023891be29dfb3e14e42d210bf3b67181c014a7106a  styles.css
f438c891ac25d59c4c511b398d3b100cb3fe208e5237748f63c318922db7b2cc  app.js
b3133ce5785c8ee6945f07ffb50e285e7c2be18bde68f26610fadf3e80ca54f5  index.html
CHECKSUMS
backup_dir="/var/backups/paskluis-admin/live-support-$(date -u +%Y%m%dT%H%M%SZ)-$$"
install -d -m 700 "$backup_dir"
for asset in support-settings.js styles.css app.js index.html; do
  if [[ -f "$admin_root/$asset" ]]; then cp -p "$admin_root/$asset" "$backup_dir/$asset"; fi
  install -m 644 "$stage_dir/$asset" "$admin_root/.$asset.live-support"
  mv -f "$admin_root/.$asset.live-support" "$admin_root/$asset"
done
printf 'Admin deployed from %s. Backup: %s
' "$release_commit" "$backup_dir"
