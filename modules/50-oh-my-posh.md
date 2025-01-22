# oh-my-posh Update Module

Updates oh-my-posh if installed on the system.

## Priority: 50

This module runs in the application updates range (50-79) since oh-my-posh is a user application.

## Requirements

- oh-my-posh must be installed
- sudo access (for upgrade command)

## Operation

1. Checks if oh-my-posh is installed
2. Runs `sudo oh-my-posh upgrade`
3. Reports success/failure status

## Enable/Disable

This module is enabled by default (.sh extension). To disable:
```bash
mv 50-oh-my-posh.sh 50-oh-my-posh.disabled
