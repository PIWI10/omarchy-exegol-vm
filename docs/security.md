# Security Architecture

omarchy-exegol-vm implements a layered security model with three distinct protection mechanisms.

## Layer 1 — Host LUKS (Omarchy default)

The Arch/Omarchy host already runs on a LUKS2-encrypted root partition (Argon2id KDF). This is the outermost layer and is managed entirely by the host OS. omarchy-exegol-vm does not touch it.

An attacker who physically steals the SSD sees only encrypted noise.

## Layer 2 — Ephemeral Mode (tmpfs overlay)

By default, the VM boots with tmpfs overlays on `/home` and `/tmp`. Everything that happens during a session — shell history, Exegol container artifacts, downloaded files, logs — lives only in RAM.

When the VM shuts down, all session data is lost. The QCOW2 base image retains only the installed system (Ubuntu + Docker + Exegol). No forensic trace of the session remains on disk.

The `home-piwi-init.service` systemd unit repopulates a clean `/home/piwi` from the skeleton on each boot.

## Layer 3 — Workspace LUKS Container

For data that must persist between sessions (loot, reports, notes, mission files), a dedicated LUKS2 container is available at `~/.exegol/workspace.luks`.

Key properties:

- Created during `omarchy-exegol-vm install` with a user-chosen passphrase.
- Uses LUKS2 with Argon2id KDF (3000ms iteration time).
- Never mounted automatically — requires explicit `omarchy-exegol-vm workspace mount`.
- Mounted on the host at `~/.exegol/workspace-mount`, shared into the VM at `/workspace`.
- Automatically unmounted when the VM stops.
- Passphrase is independent of all other credentials.

## Passphrase Summary

| # | When | Purpose |
|---|------|---------|
| 1 | Host boot | LUKS host (Omarchy, pre-existing) |
| 2 | VM login (SPICE) | Ubuntu user password |
| 3 | `workspace mount` | workspace.luks (optional, on demand) |

## Cloud-init Passphrase Handling

During initial setup, the VM user password is injected into a cloud-init seed image. After cloud-init completes its first run, a `runcmd` step shreds the user-data file from `/var/lib/cloud/instance/`. The seed image (`seed.img`) is deleted from the host during `omarchy-exegol-vm finalize`.

## SPICE Binding

The SPICE socket is created as a Unix domain socket at `~/.exegol/spice.sock` — it is never exposed on a TCP port. Only the local user can connect.
