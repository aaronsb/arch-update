# Arch Linux Update Script

A modular system update script for Arch Linux that follows the Unix philosophy of small, focused tools working together. This script handles system updates, AUR packages, Flatpak updates, and system maintenance tasks in a reliable and maintainable way.

## Features

- **Modular Design**: 
  - Split into focused, maintainable components
  - Extensible module system with priority-based execution
  - Easy enable/disable via file extensions
- **Comprehensive System Checks**: Verifies system health before updates
- **Smart Package Management**: 
  - Supports both official repos and AUR
  - Handles multiple AUR helpers (yay/paru)
  - Fallback to pacman if AUR helper unavailable
- **System Maintenance**:
  - Cleans package cache
  - Removes orphaned packages
  - Manages system logs
  - Updates mirrors (if reflector is installed)
- **Error Handling**: 
  - Proper error detection and reporting
  - Graceful failure handling
  - Detailed logging
- **Optional Updates**:
  - Flatpak packages (if installed)
  - oh-my-posh (if installed)

## Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/arch-update.git
cd arch-update

# Run the installer
./deploy.sh
```

The installer will:
1. Create directory ~/.local/share/update-arch
2. Copy all required scripts
3. Create symlink in ~/.local/bin
4. Set appropriate permissions

## Usage

Run with no arguments to see help:
```bash
update-arch
```

To perform updates:
```bash
update-arch --run --confirm
```

Available options:
```bash
-h, --help      Show help message
--version       Show version information
--dry-run       Show what would be updated without changes
--run           Run the update process
--confirm       Required with --run for safety
```

The update process will:
1. Perform system health checks
2. Update system packages
3. Handle AUR updates
4. Clean up orphaned packages
5. Manage logs
6. Show system information

## Components

Core:
- **update.sh**: Main script orchestrator
- **system-check.sh**: Pre-update system health verification
- **package-update.sh**: Package management operations
- **utils.sh**: Core utilities, logging setup, and helper functions
- **utils.sh**: Shared functions and utilities

Modules (in modules/):
- Named with priority prefix like udev rules (e.g., 10-pacman.sh)
- Organized into two main categories:
  1. System Modules (10-29):
     - Core system maintenance tasks recommended by Arch Wiki
     - Educational output explaining each maintenance operation
     - Examples: package updates, mirror management, system checks
  2. User Modules (50-79):
     - User-specific customization maintenance
     - Detailed output about user-level updates
     - Examples: oh-my-posh, custom AUR packages, user tools

- Each module provides verbose, educational output to help users:
  - Understand what maintenance tasks are being performed
  - Learn system administration best practices
  - Gain familiarity with Arch Linux maintenance
- Status controlled by extension:
  - .sh: Module is enabled
  - .disabled (or any non-.sh): Module is disabled

## Dependencies

Required:
- bash
- sudo
- pacman
- systemd

Optional:
- yay or paru (for AUR support)
- reflector (for mirror updates)
- flatpak
- oh-my-posh
- fastfetch (for system information display)

## Module Management

### Module Types

1. System Modules (10-29):
   - Essential system maintenance tasks
   - Follow Arch Wiki recommendations
   - Educational output for learning
   - Example: 10-pacman.sh, 15-mirrors.sh

2. User Modules (50-79):
   - User customization maintenance
   - Personal tool updates
   - Example: 50-oh-my-posh.sh

### Module Control

Enable a module:
```bash
mv XX-modulename.disabled XX-modulename.sh && chmod +x XX-modulename.sh
```

Disable a module:
```bash
mv XX-modulename.sh XX-modulename.disabled
```

Create a new module:
1. Copy the example module:
```bash
cp modules/50-example.disabled modules/XX-yourmodule.sh
```
2. Edit the module implementation
3. Make it executable:
```bash
chmod +x modules/XX-yourmodule.sh
```

Each module must implement:
- check_supported(): Returns 0 if module can run
- run_update(): Performs the actual update

## Logging

Logs are stored in `/var/log/system_updates/` with automatic rotation (keeps last 5 logs).

## Troubleshooting

### Common Issues

1. **Permission Denied**
   ```bash
   sudo chmod +x ~/.local/share/update-arch/*.sh
   ```

2. **Command Not Found**
   - Ensure ~/.local/bin is in your PATH
   - Check if symlink exists: `ls -l ~/.local/bin/update-arch`

3. **AUR Helper Issues**
   - Script will automatically fall back to pacman
   - Install yay or paru for AUR support

### Error Messages

- "System health checks failed": Check system status and logs
- "Failed to update packages": Check internet connection and pacman status
- "Failed to initialize logging": Ensure /var/log is writable

## Uninstallation

```bash
~/.local/share/update-arch/deploy.sh --uninstall
```

## License

MIT License - See LICENSE file for details

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request
