# Desktop Entries Vs Optional Omarchy Integration

## Runtime Launcher

The package does not install default desktop entries for non-Omarchy use.

After `omarchy-exegol-vm install` succeeds, the command creates a single user-owned launcher:

- `~/.local/share/applications/omarchy-exegol-vm.desktop`

That `Exegol` launcher runs `omarchy-exegol-vm launch` and is removed by `omarchy-exegol-vm remove`. Until install completes, use the terminal commands directly.

## Optional Omarchy Integration

Omarchy users can run `omarchy-exegol-vm-integrate-os` to add two user-owned integrations:

- An Omarchy menu extension under `~/.config/omarchy/extensions/menu.sh` that adds `Exegol` entries to the Omarchy Install and Remove menus.
- A Hyprland `source = ...` block in `~/.config/hypr/hyprland.conf` that loads the packaged Exegol VM window rules from `~/.config/omarchy-exegol-vm/hypr/omarchy-exegol-vm.conf`.

This optional integration gives the smoothest Omarchy experience:

- Hyprland window rules make the `remote-viewer` window behave correctly for the Exegol session.
- Omarchy menu integration gives you direct Install and Remove entries alongside the existing system flows without relying on package-owned desktop files.

The helper is idempotent. Re-running it does not duplicate menu entries or Hyprland sources.

Run `omarchy-exegol-vm-unintegrate-os` to remove only the markers and files managed by this project.
