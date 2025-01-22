# AUR Update Module

Handles package updates from the Arch User Repository (AUR) using available AUR helpers.

## Priority: 11 (System Module)

This module runs in the system maintenance range (10-19) as it handles package updates from the AUR, which often include important system tools and applications.

## Purpose

This module manages updates for packages installed from the AUR. It:
- Detects and uses available AUR helpers (yay or paru)
- Performs AUR package updates
- Provides clear status updates during the process
- Handles errors gracefully with informative messages

## Requirements

One of the following AUR helpers:
- yay
- paru

## Operation

1. Verifies system requirements
   - Checks for supported AUR helper availability
   - Determines which helper to use

2. Performs update
   - Uses detected AUR helper
   - Updates only AUR packages (-Sua flag)
   - Provides real-time status
   - Reports success or failure

## Features

- Automatic AUR helper detection
- Support for multiple AUR helpers
- Clear progress indication
- Error handling and reporting

## Related Arch Wiki Pages

- [AUR helpers](https://wiki.archlinux.org/title/AUR_helpers)
- [Arch User Repository](https://wiki.archlinux.org/title/Arch_User_Repository)

## Enable/Disable

To enable:
```bash
mv 11-aur-update.disabled 11-aur-update.sh && chmod +x 11-aur-update.sh
```

To disable:
```bash
mv 11-aur-update.sh 11-aur-update.disabled
