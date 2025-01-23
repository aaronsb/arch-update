# Oh My Posh Update Module

## Overview
This user module manages updates for oh-my-posh, a custom prompt engine that works with any shell. It handles version checking, updates, and provides educational information about configuration management.

## Type
User Module (50-79 priority range)

## Dependencies
- oh-my-posh
- sudo (for upgrade process)

## Operation
1. Verifies oh-my-posh installation
2. Checks current version
3. Verifies configuration file existence
4. Performs update using sudo
5. Verifies successful update
6. Provides configuration tips and documentation links

## Error Handling
- Checks for oh-my-posh installation
- Validates version checking operations
- Handles update failures gracefully
- Returns appropriate exit codes
- Redirects stderr to prevent error message pollution

## Configuration
- Default config location: ~/.config/oh-my-posh/config.json
- Supports custom themes and configurations
- Configuration changes require shell reload

## Output
The module provides:
- Current and new version information
- Update status and results
- Configuration file location and status
- Educational tips for customization
- Links to documentation and changelog

## Notes
- Requires sudo privileges for updates
- Preserves user configuration during updates
- Provides guidance for theme customization
- Includes links to official documentation
