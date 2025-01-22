# Flatpak Update Module

Handles updates for Flatpak packages if the Flatpak system is installed.

## Priority: 20 (Additional Package Systems)

This module runs in the additional package systems range (20-29) as it handles updates for an optional package management system that may be installed on Arch Linux.

## Purpose

This module manages Flatpak package updates. It:
- Checks if Flatpak is installed and in use
- Lists available Flatpak updates
- Performs package updates
- Provides clear status updates during the process
- Handles errors gracefully with informative messages

## Requirements

- flatpak package installed
- At least one Flatpak package installed
- Internet connection for updates

## Operation

1. Verifies system requirements
   - Checks for Flatpak installation
   - Verifies presence of installed Flatpak packages

2. Checks for updates
   - Lists available package updates
   - Shows pending updates if found
   - Skips update if all packages are current

3. Performs update
   - Updates all Flatpak packages
   - Uses non-interactive mode (-y flag)
   - Reports success or failure

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
