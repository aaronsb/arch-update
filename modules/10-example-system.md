# Example System Module

Demonstrates core system maintenance tasks with educational output.

## Priority: 10 (System Module)

This module runs in the system maintenance range (10-29) as it demonstrates core system tasks that are essential for Arch Linux maintenance.

## Purpose

This module serves as an example of system-level maintenance tasks and educational output. It demonstrates:
- Package cache monitoring
- System journal management
- Educational explanations of system components

## Educational Value

Users will learn about:
- The purpose and location of the package cache
- How package caching affects disk usage
- The role of systemd journal in system logging
- Best practices for system maintenance

## Requirements

- pacman (core package manager)
- systemd (for journal access)
- sudo access (for system operations)

## Operation

1. Checks package cache size in /var/cache/pacman/pkg/
   - Explains the purpose of package caching
   - Provides maintenance recommendations
   - Links to relevant Arch Wiki documentation

2. Verifies system journal status
   - Shows current journal disk usage
   - Explains the importance of log management
   - Provides educational context about systemd

## Related Arch Wiki Pages

- [Pacman](https://wiki.archlinux.org/title/Pacman)
- [System maintenance](https://wiki.archlinux.org/title/System_maintenance)
- [Systemd/Journal](https://wiki.archlinux.org/title/Systemd/Journal)

## Enable/Disable

To enable:
```bash
mv 10-example-system.disabled 10-example-system.sh && chmod +x 10-example-system.sh
```

To disable:
```bash
mv 10-example-system.sh 10-example-system.disabled
