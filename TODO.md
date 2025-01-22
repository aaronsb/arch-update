# Arch Update Script Improvements

<!--
This is a living document tracking planned improvements for the Arch Linux update script.
Each item can be marked as completed by changing [ ] to [x].
New improvements can be added to appropriate sections as they are identified.
Sections are arranged in order of implementation priority.
-->

A living document of planned improvements and enhancements for the Arch Linux update script.

## Critical Improvements

- [ ] Core Update Process
  - [ ] Add pacman keyring update check
  - [ ] Implement download timeout handling
  - [ ] Add network connectivity verification
  - [ ] Handle partial update recovery

- [ ] Error Handling and Recovery
  - [ ] Add error checking for AUR helper availability (yay/paru)
  - [ ] Implement fallback to pacman if AUR helper isn't available
  - [ ] Add trap handlers for script interruption
  - [ ] Add --noconfirm override flag option

- [ ] Package Management Essentials
  - [ ] Add pacman database check/repair (pacman -Dk)
  - [ ] Implement checkupdates from pacman-contrib
  - [ ] Add package signature verification checks
  - [ ] Add mirror list update check (if reflector is installed)

## System Health & Safety

- [ ] Pre-update Checks
  - [ ] Add disk space verification
  - [ ] Check memory availability for large updates
  - [ ] Verify system integrity
  - [ ] Check for pending reboot

- [ ] Post-update Verification
  - [ ] Check for failed systemd services
  - [ ] Verify critical system components
  - [ ] Check for broken packages
  - [ ] DKMS module rebuild verification

## Feature Enhancements

- [ ] Package Management
  - [ ] Add option to view package changes before applying
  - [ ] Support for different AUR helpers
  - [ ] Implement parallel downloads check
  - [ ] Add option for full package cache cleanup

- [ ] System-Specific Features
  - [ ] Make Flatpak updates optional (check if installed)
  - [ ] Make oh-my-posh updates optional (check if installed)
  - [ ] Add systemd-boot updates for UEFI systems
  - [ ] Add microcode update detection

## User Experience

- [ ] Progress Reporting
  - [ ] Add progress percentage for long operations
  - [ ] Show estimated time remaining
  - [ ] Implement better progress bars
  - [ ] Add stage completion indicators

- [ ] Information Display
  - [ ] Add summary of changes at completion
  - [ ] Show package statistics
  - [ ] Add system status overview
  - [ ] Implement quiet mode for scripted runs

## Security

- [ ] Package Verification
  - [ ] Add checksum verification
  - [ ] Add pacman hook status checks

- [ ] System Security
  - [ ] Add Arch news check for critical updates
  - [ ] Add package vulnerability scanning

## Logging & Monitoring

- [ ] Log Management
  - [ ] Implement basic log rotation
  - [ ] Add simple log cleanup
  - [ ] Save update history

- [ ] Debugging
  - [ ] Add debug mode
  - [ ] Add verbose logging option
  - [ ] Add basic error reporting

## Command-Line Interface

- [ ] Basic Options
  - [ ] Add --help flag with usage information
  - [ ] Add --version flag
  - [ ] Add --dry-run option
  - [ ] Add --verbose and --quiet modes

## Configuration

- [ ] Settings Management
  - [ ] Add simple configuration file support
  - [ ] Add basic customization options
  - [ ] Make cleanup policies configurable

## Documentation

- [ ] Script Documentation
  - [ ] Add help output
  - [ ] Document configuration options
  - [ ] Add usage examples

## Testing & Validation

- [ ] Basic Testing
  - [ ] Add dry-run mode for testing changes
  - [ ] Test on backup system first
  - [ ] Document common failure scenarios
  - [ ] Create simple test cases for new features

## Future Considerations

- [ ] Filesystem-Aware Backup Integration
  - [ ] Detect filesystem type (ext4/btrfs)
  - [ ] For btrfs:
    - [ ] Implement pre-update snapshots
    - [ ] Add snapshot cleanup policy
    - [ ] Enable snapshot rollback
  - [ ] For ext4:
    - [ ] Implement image-based backup
    - [ ] Add compression for space efficiency
    - [ ] Provide restore instructions
  - [ ] Add backup size estimation
  - [ ] Add backup verification

## Script Modularization

- [ ] Core Scripts
  - [ ] Package update script (pacman/AUR operations)
  - [ ] System health check script
  - [ ] Backup management script
  - [ ] Log management script

- [ ] Helper Scripts
  - [ ] Filesystem detection and handling
  - [ ] Network connectivity check
  - [ ] Disk space management
  - [ ] Error handling utilities

- [ ] Orchestration
  - [ ] Main coordinator script
  - [ ] Configuration parser
  - [ ] Status reporting
  - [ ] Inter-script communication

## Notes

- Priority order: Critical → System Health → Security → Features
- Follow Unix philosophy: small, focused scripts working together
- Each script should do one thing well
- Keep individual scripts simple and testable
- Use clear naming conventions for scripts
