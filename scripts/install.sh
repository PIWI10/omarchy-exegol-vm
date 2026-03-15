#!/bin/bash
set -euo pipefail

# install.sh — Interactive wizard for omarchy-exegol-vm first-time setup.
# Called by: bin/omarchy-exegol-vm install

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXEGOL_STORAGE="$HOME/.exegol"
EXEGOL_CONFIG="$HOME/.config/exegol"
COMPOSE_FILE="$EXEGOL_CONFIG/docker-compose.yml"

# ── ISO detection ─────────────────────────────────────────────────

detect_iso() {
  local match
  for match in \
    "$HOME/Downloads/"ubuntu-24.04*-live-server-amd64.iso \
    "$HOME/Downloads/"ubuntu-24.04*-server-amd64.iso \
    "$HOME/Downloads/"ubuntu-24.04*-desktop-amd64.iso \
    "$HOME/Downloads/"ubuntu-24.04*.iso \
  ; do
    if [[ -f "$match" ]]; then
      echo "$match"
      return 0
    fi
  done
  return 1
}

download_iso() {
  local ISO_URL="https://releases.ubuntu.com/24.04/ubuntu-24.04.2-live-server-amd64.iso"
  local ISO_DEST="$HOME/Downloads/ubuntu-24.04.2-live-server-amd64.iso"

  echo "No Ubuntu ISO found locally." >&2
  echo "Downloading Ubuntu Server 24.04 LTS..." >&2
  echo "URL: $ISO_URL" >&2

  mkdir -p "$HOME/Downloads"
  curl -fL --retry 2 --retry-delay 5 -C - -o "$ISO_DEST" "$ISO_URL" || {
    echo "ERROR: Failed to download Ubuntu Server ISO." >&2
    exit 1
  }

  # Only the path goes to stdout (for capture by caller)
  echo "$ISO_DEST"
}

# ── Wizard ────────────────────────────────────────────────────────

run_wizard() {
  trap "echo ''; echo 'Installation cancelled.'; exit 1" INT

  # ── ISO ──
  echo ""
  echo "Searching for Ubuntu ISO..."
  local ISO_PATH=""
  if ISO_PATH=$(detect_iso); then
    echo "Found: $ISO_PATH"
    if ! gum confirm "Use this ISO?"; then
      ISO_PATH=$(download_iso)
    fi
  else
    ISO_PATH=$(download_iso)
  fi

  if [[ ! -f "$ISO_PATH" ]]; then
    echo "ERROR: ISO not found at $ISO_PATH"
    exit 1
  fi

  # ── System resources ──
  local TOTAL_RAM_GB
  TOTAL_RAM_GB=$(awk 'NR==1 {printf "%d", $2/1024/1024}' /proc/meminfo)
  local TOTAL_CORES
  TOTAL_CORES=$(nproc)

  echo ""
  echo "System Resources Detected:"
  echo "  Total RAM: ${TOTAL_RAM_GB}G"
  echo "  Total CPU Cores: $TOTAL_CORES"
  echo ""

  # RAM
  local RAM_OPTIONS=""
  local size
  for size in 2 4 8 16 32; do
    if (( size <= TOTAL_RAM_GB )); then
      RAM_OPTIONS="$RAM_OPTIONS ${size}G"
    fi
  done

  local SELECTED_RAM
  SELECTED_RAM=$(echo $RAM_OPTIONS | tr ' ' '\n' | gum choose --selected="4G" --header="RAM to allocate to the Exegol VM?")
  [[ -z "$SELECTED_RAM" ]] && { echo "Installation cancelled."; exit 1; }

  # CPU
  local SELECTED_CORES
  SELECTED_CORES=$(gum input --placeholder="Number of CPU cores (1-$TOTAL_CORES)" --value="2" --header="CPU cores to allocate to the Exegol VM?" --char-limit=2)
  [[ -z "$SELECTED_CORES" ]] && { echo "Installation cancelled."; exit 1; }
  if ! [[ $SELECTED_CORES =~ ^[0-9]+$ ]] || (( SELECTED_CORES < 1 )) || (( SELECTED_CORES > TOTAL_CORES )); then
    echo "Invalid input. Using default: 2 cores"
    SELECTED_CORES=2
  fi

  # Exegol image
  local SELECTED_IMAGE
  SELECTED_IMAGE=$(printf 'full\nlight\nweb\nad' | gum choose --selected="full" --header="Exegol image to install inside the VM?")
  [[ -z "$SELECTED_IMAGE" ]] && { echo "Installation cancelled."; exit 1; }

  # Workspace size
  local WORKSPACE_SIZE
  WORKSPACE_SIZE=$(gum input --placeholder="Size in Go (default: 50)" --value="50" --header="Encrypted workspace size (Go)?" --char-limit=4)
  [[ -z "$WORKSPACE_SIZE" ]] && WORKSPACE_SIZE=50
  if ! [[ $WORKSPACE_SIZE =~ ^[0-9]+$ ]] || (( WORKSPACE_SIZE < 1 )); then
    echo "Invalid input. Using default: 50 Go"
    WORKSPACE_SIZE=50
  fi

  # ── VM password ──
  echo ""
  local VM_PASSWORD
  VM_PASSWORD=$(gum input --placeholder="Password for piwi user inside VM" --password --header="VM user password (piwi):")
  [[ -z "$VM_PASSWORD" ]] && { echo "Installation cancelled."; exit 1; }
  local VM_PASSWORD_CONFIRM
  VM_PASSWORD_CONFIRM=$(gum input --placeholder="Confirm password" --password --header="Confirm VM password:")
  if [[ "$VM_PASSWORD" != "$VM_PASSWORD_CONFIRM" ]]; then
    echo "ERROR: Passwords do not match."
    exit 1
  fi

  # ── Workspace passphrase ──
  local WORKSPACE_PASS
  WORKSPACE_PASS=$(gum input --placeholder="Passphrase for workspace.luks" --password --header="Workspace LUKS passphrase:")
  [[ -z "$WORKSPACE_PASS" ]] && { echo "Installation cancelled."; exit 1; }
  local WORKSPACE_PASS_CONFIRM
  WORKSPACE_PASS_CONFIRM=$(gum input --placeholder="Confirm passphrase" --password --header="Confirm workspace passphrase:")
  if [[ "$WORKSPACE_PASS" != "$WORKSPACE_PASS_CONFIRM" ]]; then
    echo "ERROR: Passphrases do not match."
    exit 1
  fi

  # ── Summary ──
  gum style \
    --border normal \
    --padding "1 2" \
    --margin "1" \
    --align left \
    --bold \
    "Exegol VM Configuration" \
    "" \
    "ISO:         $(basename "$ISO_PATH")" \
    "RAM:         $SELECTED_RAM" \
    "CPU:         $SELECTED_CORES cores" \
    "Exegol:      $SELECTED_IMAGE" \
    "Workspace:   ${WORKSPACE_SIZE} Go (LUKS2)" \
    "VM user:     piwi"

  echo ""
  if ! gum confirm "Proceed with this configuration?"; then
    echo "Installation cancelled."
    exit 1
  fi

  # ── sudo pre-auth ──
  echo ""
  echo "sudo is required for LUKS container creation."
  sudo -v || exit 1

  # ── Create directories ──
  mkdir -p "$EXEGOL_STORAGE" "$EXEGOL_CONFIG"
  chattr +C "$EXEGOL_STORAGE" 2>/dev/null || true

  # ── Copy ISO into storage ──
  if [[ ! -f "$EXEGOL_STORAGE/ubuntu.iso" ]]; then
    echo "Copying ISO to storage..."
    cp "$ISO_PATH" "$EXEGOL_STORAGE/ubuntu.iso"
  fi

  # ── Note: qemux/qemu auto-creates data.qcow2 from DISK_SIZE ──
  # No manual QCOW2 creation needed.

  # ── Create workspace.luks ──
  echo ""
  bash "$SCRIPT_DIR/luks-setup.sh" "$WORKSPACE_SIZE" "$WORKSPACE_PASS"

  # ── Generate cloud-init seed image ──
  echo ""
  echo "Generating cloud-init configuration..."
  local CLOUD_INIT_DIR="$EXEGOL_CONFIG/cloud-init"
  mkdir -p "$CLOUD_INIT_DIR"

  cp "$SCRIPT_DIR/cloud-init/meta-data" "$CLOUD_INIT_DIR/meta-data"

  sed \
    -e "s|__VM_PASSWORD__|${VM_PASSWORD}|g" \
    -e "s|__EXEGOL_IMAGE__|${SELECTED_IMAGE}|g" \
    "$SCRIPT_DIR/cloud-init/user-data.tmpl" > "$CLOUD_INIT_DIR/user-data"

  echo "Building cloud-init seed image..."
  docker run --rm \
    -v "$EXEGOL_CONFIG:/config" \
    -v "$EXEGOL_STORAGE:/storage" \
    --entrypoint /bin/bash \
    qemux/qemu -c "
      apt-get update -qq && apt-get install -y --no-install-recommends genisoimage > /dev/null 2>&1
      genisoimage -output /storage/seed.img \
        -volid cidata -joliet -rock \
        /config/cloud-init/user-data \
        /config/cloud-init/meta-data
    "

  shred -u "$CLOUD_INIT_DIR/user-data" 2>/dev/null || rm -f "$CLOUD_INIT_DIR/user-data"
  echo "cloud-init seed image created. user-data shredded."

  # ── Write start.sh hook (SPICE module) ──
  cat << 'STARTHOOK' | tee "$EXEGOL_CONFIG/start.sh" > /dev/null
#!/bin/bash
set -e
if qemu-system-x86_64 -spice help >/dev/null 2>&1; then
  exit 0
fi
echo "Installing QEMU SPICE module..."
DEBIAN_FRONTEND=noninteractive apt-get -qq update
DEBIAN_FRONTEND=noninteractive apt-get -qq --no-install-recommends -y install qemu-system-modules-spice > /dev/null
STARTHOOK
  chmod +x "$EXEGOL_CONFIG/start.sh"

  # ── Generate compose.yml ──
  echo "Generating docker-compose.yml..."
  sed \
    -e "s|__RAM__|${SELECTED_RAM}|g" \
    -e "s|__CPU__|${SELECTED_CORES}|g" \
    -e "s|__HOME__|${HOME}|g" \
    "$SCRIPT_DIR/compose.yml.tmpl" > "$COMPOSE_FILE"

  # ── First boot ──
  echo ""
  echo "Starting first boot of Exegol VM..."
  echo "The VM will install Ubuntu via cloud-init."
  echo "This process takes 10-20 minutes (Docker + Exegol image pull)."
  echo ""
  echo "The SPICE viewer will open automatically."
  echo "You can monitor cloud-init progress inside the VM with:"
  echo "  sudo tail -f /var/log/cloud-init-output.log"
  echo ""

  docker compose -f "$COMPOSE_FILE" up -d 2>&1 || {
    echo "ERROR: Failed to start Exegol VM."
    echo "Check: sudo systemctl start docker && ls /dev/kvm"
    exit 1
  }

  local SPICE_SOCK="$EXEGOL_STORAGE/spice.sock"
  echo "Waiting for VM SPICE to be ready..."
  local WAIT_COUNT=0
  until [[ -S "$SPICE_SOCK" ]]; do
    sleep 2
    WAIT_COUNT=$((WAIT_COUNT + 1))
    if (( WAIT_COUNT > 90 )); then
      echo "Timeout: Exegol VM SPICE not ready within 3 minutes."
      exit 1
    fi
  done
  docker exec omarchy-exegol-vm chmod 666 /storage/spice.sock

  echo ""
  echo "Exegol VM is booting! Launching SPICE viewer..."
  echo "Closing the viewer will power down the VM."

  setsid bash -c "
    remote-viewer 'spice+unix://$SPICE_SOCK' -t 'Exegol VM' --auto-resize=always &>/dev/null
    docker exec 'omarchy-exegol-vm' bash -c 'echo system_powerdown | nc -q1 localhost 7100' 2>/dev/null || true
    WAIT=0
    while docker inspect --format='{{.State.Status}}' 'omarchy-exegol-vm' 2>/dev/null | grep -q running; do
      sleep 2
      WAIT=\$((WAIT + 1))
      (( WAIT > 30 )) && break
    done
    docker compose -f '$COMPOSE_FILE' down 2>/dev/null || true
    rm -f '$SPICE_SOCK'
  " &>/dev/null &

  echo ""
  echo "Installation complete!"
  echo ""
  echo "After cloud-init finishes inside the VM, shut it down and"
  echo "remove the ISO/seed boot media with:"
  echo "  omarchy-exegol-vm finalize"
  echo ""
  echo "Or simply relaunch later with:"
  echo "  omarchy-exegol-vm launch"
}

run_wizard "$@"
