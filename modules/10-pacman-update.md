# Pacman Update Module

Handles core system package updates using the pacman package manager.

## Priority: 10 (System Module)

This module runs in the system maintenance range (10-19) as it handles essential package updates from official Arch Linux repositories.

## Purpose

This module manages the core system package updates through pacman. It:
- Checks for available updates using checkupdates
- Performs system package updates via pacman
- Provides clear status updates during the process
- Handles errors gracefully with informative messages

## Requirements

- pacman (core package manager)
- sudo access (for system updates)
- checkupdates (optional, from pacman-contrib)

## Operation

1. Verifies system requirements
   - Checks for pacman availability
   - Validates sudo access

2. Checks for updates
   - Uses checkupdates if available
   - Shows list of pending updates
   - Skips update if system is current

3. Performs update
   - Executes pacman -Syu
   - Provides real-time status
   - Reports success or failure

## Related Arch Wiki Pages

- [Pacman](https://wiki.archlinux.org/title/Pacman)
- [System maintenance](https://wiki.archlinux.org/title/System_maintenance)

## Enable/Disable

To enable:
```bash
mv 10-pacman-update.disabled 10-pacman-update.sh && chmod +x 10-pacman-update.sh
```

To disable:
```bash
mv 10-pacman-update.sh 10-pacman-update.disabled
