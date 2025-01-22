# Arch Linux Update Script

A modular system update script for Arch Linux that follows the Unix philosophy of small, focused tools working together. This script handles system updates, AUR packages, Flatpak updates, and system maintenance tasks in a reliable and maintainable way.

## Features

- **Modular Design**: Split into focused, maintainable components
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

Simply run:
```bash
update-arch
```

The script will:
1. Perform system health checks
2. Update system packages
3. Handle AUR updates
4. Clean up orphaned packages
5. Manage logs
6. Show system information

## Components

- **update.sh**: Main script orchestrator
- **system-check.sh**: Pre-update system health verification
- **package-update.sh**: Package management operations
- **log-manage.sh**: Log handling and rotation
- **utils.sh**: Shared functions and utilities

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
