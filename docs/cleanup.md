# Cleanup Boundaries

The project keeps package ownership, VM runtime data, and Omarchy-specific user integration separate on purpose.

## Package Removal

Removing the package only removes package-owned files installed by pacman:

- launcher binaries in `/usr/bin`
- icon assets in `/usr/share/icons`
- packaged snippets and docs in `/usr/share/omarchy-exegol-vm`

Package removal does not remove `~/.config/exegol`, `~/.exegol`, the runtime-created launcher in `~/.local/share/applications`, or any optional Omarchy integration markers under `~/.config`.

## VM Data Removal

Run `omarchy-exegol-vm remove` when you want to delete the Exegol VM runtime data created for your user. This removes:

- `~/.config/exegol` (compose file, start hook)
- `~/.exegol` (QCOW2, workspace.luks, ISO, seed image)
- `~/.local/share/applications/omarchy-exegol-vm.desktop`

It does not uninstall the package and does not remove Omarchy integration markers.

Run `omarchy-exegol-vm remove --debug` when you want the same VM cleanup while preserving debug evidence in a report directory under `~/.local/state/omarchy-exegol-vm`.

**Warning:** `omarchy-exegol-vm remove` permanently destroys workspace.luks. Any data inside the encrypted workspace is irrecoverable after removal.

## Omarchy Integration Removal

Run `omarchy-exegol-vm-unintegrate-os` when you want to remove Omarchy menu and Hyprland integration that was previously added by this project. The helper removes only its own marked blocks and its own copied snippets under `~/.config/omarchy-exegol-vm`.

## Workspace Data

The workspace LUKS container (`~/.exegol/workspace.luks`) is included in the `remove` command. If you need to preserve workspace data, back it up before removal:

```
omarchy-exegol-vm workspace mount
cp -r ~/.exegol/workspace-mount/ /path/to/backup/
omarchy-exegol-vm workspace umount
```
