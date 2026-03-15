# omarchy-exegol-vm

Provides a secure, encrypted Exegol offensive-security VM for [Omarchy](https://github.com/basecamp/omarchy) using a dockerized QEMU environment. Ships with triple-layer encryption (host LUKS + ephemeral tmpfs + dedicated workspace LUKS), cloud-init automated setup, and full Hyprland/Walker integration.

Built following the exact pattern of [omarchy-kali-vm](https://github.com/reg1z/omarchy-kali-vm), adapted for Ubuntu Server + Docker + [Exegol](https://github.com/ThePorgs/Exegol).

## Installation

```
git clone https://github.com/piwi/omarchy-exegol-vm.git
cd omarchy-exegol-vm
chmod +x bin/*
chmod +x scripts/*.sh

# Add bin/ to your PATH, then:
omarchy-exegol-vm install
```

After installation, run `omarchy-exegol-vm-integrate-os` to import the Hyprland windowrules and Omarchy menu entries into your `~/.config`. This can easily be undone with `omarchy-exegol-vm-unintegrate-os`.

## Summary

Adds first-class Exegol VM support to Omarchy via `omarchy-exegol-vm`. Uses [`qemux/qemu`](https://github.com/qemus/qemu), a containerized QEMU environment, to minimize dependencies. The only external dependency is `virt-viewer` for the SPICE display.

The VM is an Ubuntu Server 24.04 LTS instance provisioned automatically via cloud-init with Docker and Exegol pre-installed. Three security layers protect your offensive work:

1. **Host LUKS** — Omarchy's full-disk encryption (already active, untouched).
2. **Ephemeral mode** — tmpfs overlays on `/home` and `/tmp` inside the VM. Nothing persists to disk between sessions by default.
3. **Workspace LUKS** — A separate encrypted container (`workspace.luks`) for persistent mission data, mounted on demand.

### Scope

The package does not edit `~/.local/share/omarchy` and does not clean up user dotfiles automatically on install or uninstall.

- Base package: launcher command, icon, packaged Hyprland and Omarchy menu snippets, and documentation.
- User runtime data: `~/.config/exegol`, `~/.exegol`, and the runtime-created desktop entry in `~/.local/share/applications`.
- Optional Omarchy integration: user-run helpers that add or remove Omarchy menu and Hyprland sourcing under `~/.config`.

### Control Flow

1. The user runs `omarchy-exegol-vm install` from a terminal or an Omarchy-integrated menu entry. This is a first-time setup command and exits early if managed Exegol VM state already exists.
2. The wizard gathers VM resources (RAM, CPU, Exegol image variant, workspace size) and credentials from the user.
3. It detects or downloads an Ubuntu Server 24.04 ISO, creates a QCOW2 virtual disk, builds a cloud-init seed image, and generates the Docker Compose configuration.
4. It creates the encrypted workspace.luks container with a user-chosen passphrase.
5. It starts the VM through the `qemux/qemu` container, waits for SPICE, writes a desktop entry, and opens `remote-viewer`. Cloud-init inside the VM installs Docker + Exegol automatically.
6. After cloud-init finishes, `omarchy-exegol-vm finalize` removes the ISO and seed boot media.
7. Later launches reuse the same compose/storage setup and just start the VM and connect over SPICE.
8. Removal tears down all Exegol VM state from the same entrypoint.

## Commands

- `omarchy-exegol-vm install`
- `omarchy-exegol-vm install --debug`
- `omarchy-exegol-vm launch`
- `omarchy-exegol-vm launch --keep-alive`
- `omarchy-exegol-vm stop`
- `omarchy-exegol-vm status`
- `omarchy-exegol-vm workspace mount`
- `omarchy-exegol-vm workspace umount`
- `omarchy-exegol-vm workspace status`
- `omarchy-exegol-vm finalize`
- `omarchy-exegol-vm remove`
- `omarchy-exegol-vm remove --debug`
- `omarchy-exegol-vm-integrate-os`
- `omarchy-exegol-vm-unintegrate-os`

## Cleanup Boundaries

- Remove Exegol VM data: `omarchy-exegol-vm remove`
- Remove Exegol VM data but preserve debug evidence: `omarchy-exegol-vm remove --debug`
- Remove optional Omarchy integration: `omarchy-exegol-vm-unintegrate-os`

Additional details live in [docs/cleanup.md](docs/cleanup.md), [docs/integration.md](docs/integration.md), and [docs/security.md](docs/security.md).

## Disk Budget

| Component | Size |
|-----------|------|
| QCOW2 Ubuntu (dynamically allocated) | max 40 Go |
| Exegol image `full` inside VM | ~25 Go |
| `workspace.luks` (configurable) | 50 Go default |
| **Total** | **~115 Go** |

## Dependencies

- Docker (with compose plugin)
- `virt-viewer` (for SPICE display)
- `gum` (interactive prompts)
- `cryptsetup` (workspace LUKS)
- KVM (`/dev/kvm`)

## Credits

Architecture and integration pattern from [omarchy-kali-vm](https://github.com/reg1z/omarchy-kali-vm) by [reg1z](https://github.com/reg1z).

Exegol project: [ThePorgs/Exegol](https://github.com/ThePorgs/Exegol).
