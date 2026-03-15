#!/bin/bash
set -euo pipefail

# workspace-mount.sh — Mount or unmount the encrypted Exegol workspace.
# Usage: workspace-mount.sh mount|umount|status
#
# The workspace is a LUKS2 container stored at ~/.exegol/workspace.luks.
# When mounted, it is available at ~/.exegol/workspace-mount on the host
# and shared into the VM at /workspace via the compose volume bind.

LUKS_FILE="$HOME/.exegol/workspace.luks"
MAPPER_NAME="exegol-workspace"
MOUNT_POINT="$HOME/.exegol/workspace-mount"

status_workspace() {
  if [[ -e "/dev/mapper/$MAPPER_NAME" ]]; then
    if mountpoint -q "$MOUNT_POINT" 2>/dev/null; then
      echo "Workspace: mounted at $MOUNT_POINT"
    else
      echo "Workspace: LUKS open but not mounted"
    fi
  else
    echo "Workspace: locked (not mounted)"
  fi
}

mount_workspace() {
  if [[ ! -f "$LUKS_FILE" ]]; then
    echo "ERROR: workspace.luks not found at $LUKS_FILE"
    echo "Run omarchy-exegol-vm install to create it."
    exit 1
  fi

  if mountpoint -q "$MOUNT_POINT" 2>/dev/null; then
    echo "Workspace is already mounted at $MOUNT_POINT"
    return 0
  fi

  echo "Opening workspace.luks..."
  if [[ ! -e "/dev/mapper/$MAPPER_NAME" ]]; then
    sudo cryptsetup open "$LUKS_FILE" "$MAPPER_NAME"
  fi

  mkdir -p "$MOUNT_POINT"
  sudo mount /dev/mapper/"$MAPPER_NAME" "$MOUNT_POINT"
  sudo chown "$(id -u):$(id -g)" "$MOUNT_POINT"

  echo "Workspace mounted at $MOUNT_POINT"
  echo "Inside the VM it will be available at /workspace"
}

umount_workspace() {
  if mountpoint -q "$MOUNT_POINT" 2>/dev/null; then
    echo "Unmounting workspace..."
    sudo umount "$MOUNT_POINT" 2>/dev/null || true
  fi

  if [[ -e "/dev/mapper/$MAPPER_NAME" ]]; then
    echo "Closing LUKS container..."
    sudo cryptsetup close "$MAPPER_NAME" 2>/dev/null || true
  fi

  echo "Workspace locked."
}

case "${1:-status}" in
  mount)
    mount_workspace
    ;;
  umount|unmount)
    umount_workspace
    ;;
  status)
    status_workspace
    ;;
  *)
    echo "Usage: workspace-mount.sh mount|umount|status"
    exit 1
    ;;
esac
