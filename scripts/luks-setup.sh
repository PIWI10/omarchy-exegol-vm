#!/bin/bash
set -euo pipefail

# luks-setup.sh — Create an encrypted LUKS2 container for the Exegol workspace.
# Usage: luks-setup.sh <size_in_gb> <passphrase>
#
# The resulting file is never auto-mounted. It must be explicitly opened
# and mounted via workspace-mount.sh before use.

SIZE="${1:?Usage: luks-setup.sh <size_gb> <passphrase>}"
PASS="${2:?Usage: luks-setup.sh <size_gb> <passphrase>}"

LUKS_FILE="$HOME/.exegol/workspace.luks"

if [[ -f "$LUKS_FILE" ]]; then
  echo "workspace.luks already exists at $LUKS_FILE — skipping."
  exit 0
fi

echo "Creating workspace.luks (${SIZE} Go)..."
echo "This may take a few minutes depending on disk speed."

# Allocate the file (sparse-friendly fallocate, fallback to dd)
if command -v fallocate >/dev/null 2>&1; then
  fallocate -l "${SIZE}G" "$LUKS_FILE"
else
  dd if=/dev/zero of="$LUKS_FILE" bs=1M count=$((SIZE * 1024)) status=progress
fi

# Format as LUKS2 with Argon2id KDF
echo -n "$PASS" | cryptsetup luksFormat \
  --type luks2 \
  --pbkdf argon2id \
  --iter-time 3000 \
  --batch-mode \
  "$LUKS_FILE" -

# Open, format ext4, close — so it is ready to use on first mount
echo -n "$PASS" | sudo cryptsetup open "$LUKS_FILE" exegol-workspace-init -
sudo mkfs.ext4 -L exegol-workspace /dev/mapper/exegol-workspace-init
sudo cryptsetup close exegol-workspace-init

echo "workspace.luks created: $LUKS_FILE (${SIZE} Go, LUKS2 Argon2id, ext4)"
