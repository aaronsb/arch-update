# oh-my-posh Update Module

Updates and maintains the oh-my-posh shell prompt customization tool.

## Priority: 50 (User Module)

This module runs in the user maintenance range (50-79) as it manages a user-specific shell customization tool.

## Purpose

This module handles the maintenance of oh-my-posh, a custom prompt engine that enhances your shell experience. It provides:
- Automated version updates
- Configuration management guidance
- Educational information about shell customization

## Educational Value

Users will learn about:
- Shell prompt customization tools
- Version management for user tools
- Configuration file locations and backup practices
- Best practices for maintaining user customizations

## Requirements

- oh-my-posh must be installed
- sudo access (for upgrade command)
- Internet access (for updates)

## Operation

1. Displays educational information about oh-my-posh
   - Explains the tool's purpose
   - Provides documentation links
   - Emphasizes update importance

2. Checks current version
   - Shows installed version
   - Prepares for version comparison

3. Performs update process
   - Executes upgrade command
   - Shows version changes
   - Links to changelog for updates

4. Provides configuration guidance
   - Locates config files
   - Explains backup importance
   - Offers customization tips

## Related Documentation

- [oh-my-posh Official Docs](https://ohmyposh.dev/)
- [GitHub Releases](https://github.com/JanDeDobbeleer/oh-my-posh/releases)
- [Configuration Guide](https://ohmyposh.dev/docs/configuration/overview)

## Enable/Disable

To enable:
```bash
mv 50-oh-my-posh.disabled 50-oh-my-posh.sh && chmod +x 50-oh-my-posh.sh
```

To disable:
```bash
mv 50-oh-my-posh.sh 50-oh-my-posh.disabled
