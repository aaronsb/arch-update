# Flatpak Update Module

Handles updates for Flatpak packages if the Flatpak system is installed.

## Priority: 20 (Additional Package Systems)

This module runs in the additional package systems range (20-29) as it handles updates for an optional package management system that may be installed on Arch Linux.

## Purpose

This module manages Flatpak package updates. It:
- Checks if Flatpak is installed
- Lists available updates for the system and user installations
- Updates each installation that has pending updates, without prompting
- Provides clear status updates during the process
- Handles errors gracefully with informative messages

## Requirements

- flatpak package installed
- At least one Flatpak package installed (system or user installation)
- sudo, for the system installation (update-arch holds a session for the system phase)
- Internet connection for updates

## Operation

1. Verifies system requirements
   - Skips the module when `flatpak` is not installed

2. Checks for updates
   - Lists pending updates for the system installation (`flatpak remote-ls --updates --system`) and the user installation (`--user`)
   - Skips the update if both are current
   - A check that fails (offline, remote unreachable) is not a module failure: it prints a warning, adds a run note ("Flatpak system updates not checked (remote-ls exit N)"), and never claims "up to date" for that installation. The other installation is still checked and updated
   - In a dry run, lists the pending updates grouped as "system (via sudo)" and "user", and changes nothing

3. Performs the update, non-interactively (`--noninteractive`)
   - System installation: `sudo flatpak update --system`, as root
   - User installation: `flatpak update --user`, as the invoking user
   - Both installations are always attempted; a failure in one is reported and fails the module, but does not skip the other

## Why the system installation goes through sudo

Run as an ordinary user, `flatpak update` changes the system installation
through flatpak's system-helper, and polkit allows that without a password
only for a local, active session. Over SSH, from a timer, or with no
authentication agent, `--noninteractive` cannot prompt and every deploy is
refused (`Flatpak system operation Deploy not allowed for user`). Root needs
no polkit authorization, and update-arch already holds a sudo session for the
system phase. The user installation stays with the invoking user, since under
sudo `--user` would mean root's own installation.

## Features

- Automatic detection of Flatpak installation
- Verification of installed packages
- Update availability checking
- Clear progress indication
- Detailed status reporting

## Related Arch Wiki Pages

- [Flatpak](https://wiki.archlinux.org/title/Flatpak)
- [Software package management](https://wiki.archlinux.org/title/Software_package_management)

## Enable/Disable

To enable:
```bash
mv 20-flatpak-update.disabled 20-flatpak-update.sh && chmod +x 20-flatpak-update.sh
```

To disable:
```bash
mv 20-flatpak-update.sh 20-flatpak-update.disabled
