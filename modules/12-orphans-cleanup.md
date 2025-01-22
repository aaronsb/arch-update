# Orphaned Packages Cleanup Module

Handles the detection and removal of orphaned packages to maintain system cleanliness.

## Priority: 12 (System Module)

This module runs in the system maintenance range (10-19) as it handles system cleanup tasks that help maintain system health and disk space.

## Purpose

This module manages orphaned packages in the system. It:
- Detects packages that are no longer required by any other package
- Lists found orphaned packages for user awareness
- Safely removes orphaned packages
- Maintains system cleanliness by preventing package buildup

## Requirements

- pacman (core package manager)
- sudo access (for package removal)

## Operation

1. Verifies system requirements
   - Checks for pacman availability
   - Validates sudo access

2. Detects orphaned packages
   - Uses pacman -Qdtq to find unrequired packages
   - Lists found orphaned packages

3. Removes orphaned packages
   - Uses pacman -Rns for complete removal
   - Removes package and unneeded dependencies
   - Cleans up configuration files

## Features

- Safe package detection
- Complete package removal
- Configuration cleanup
- Clear progress indication
- Detailed status reporting

## Related Arch Wiki Pages

- [Pacman/Tips and tricks](https://wiki.archlinux.org/title/Pacman/Tips_and_tricks#Removing_unused_packages_(orphans))
- [System maintenance](https://wiki.archlinux.org/title/System_maintenance#Package_cache)

## Enable/Disable

To enable:
```bash
mv 12-orphans-cleanup.disabled 12-orphans-cleanup.sh && chmod +x 12-orphans-cleanup.sh
```

To disable:
```bash
mv 12-orphans-cleanup.sh 12-orphans-cleanup.disabled
