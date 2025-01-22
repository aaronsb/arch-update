# Example User Module

Demonstrates user-specific maintenance tasks with educational output.

## Priority: 50 (User Module)

This module runs in the user maintenance range (50-79) as it handles user-specific customizations and personal tool updates.

## Purpose

This module serves as an example of user-level maintenance tasks and educational output. It demonstrates:
- AUR package management
- User configuration monitoring
- Educational explanations of user customization

## Educational Value

Users will learn about:
- The Arch User Repository (AUR) and its role
- Managing user-contributed packages
- XDG base directory specification
- Best practices for configuration management

## Requirements

- yay (or another AUR helper)
- User-level access to ~/.config
- Basic understanding of AUR concepts

## Operation

1. Checks AUR package status
   - Counts installed AUR packages
   - Explains the purpose of AUR
   - Provides security recommendations
   - Links to AUR documentation

2. Monitors user configuration
   - Tracks recently modified config files
   - Explains XDG base directory structure
   - Provides backup recommendations
   - Educates about configuration management

## Related Arch Wiki Pages

- [Arch User Repository](https://wiki.archlinux.org/title/Arch_User_Repository)
- [XDG Base Directory](https://wiki.archlinux.org/title/XDG_Base_Directory)
- [System maintenance](https://wiki.archlinux.org/title/System_maintenance#User_specific_configuration)

## Enable/Disable

To enable:
```bash
mv 50-example-user.disabled 50-example-user.sh && chmod +x 50-example-user.sh
```

To disable:
```bash
mv 50-example-user.sh 50-example-user.disabled
