# Package Cache Cleanup Module

Handles the cleaning of pacman's package cache to maintain system disk space.

## Priority: 13 (System Module)

This module runs in the system maintenance range (10-19) as it handles system cleanup tasks that help maintain disk space and system performance.

## Purpose

This module manages the pacman package cache. It:
- Reports current cache size
- Removes old versions of installed packages
- Removes all versions of uninstalled packages
- Reports space saved after cleanup
- Maintains a balance between cache availability and disk space

## Requirements

- paccache (from pacman-contrib package)
- sudo access (for cache cleanup)
- du command (for size reporting)

## Operation

1. Verifies system requirements
   - Checks for paccache availability
   - Validates sudo access

2. Reports initial state
   - Measures current cache size
   - Shows size before cleanup

3. Performs cleanup operations
   - Keeps last 3 versions of installed packages
   - Removes all versions of uninstalled packages
   - Shows final cache size after cleanup

## Features

- Size reporting before and after cleanup
- Retention of recent package versions
- Complete removal of uninstalled package cache
- Clear progress indication
- Detailed status reporting

## Related Arch Wiki Pages

- [Pacman#Cleaning the package cache](https://wiki.archlinux.org/title/Pacman#Cleaning_the_package_cache)
- [System maintenance#Package cache](https://wiki.archlinux.org/title/System_maintenance#Package_cache)

## Enable/Disable

To enable:
```bash
mv 13-cache-cleanup.disabled 13-cache-cleanup.sh && chmod +x 13-cache-cleanup.sh
```

To disable:
```bash
mv 13-cache-cleanup.sh 13-cache-cleanup.disabled
