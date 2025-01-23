#!/bin/bash
#
# Example User Module (50-79 priority range)
# Demonstrates user-specific maintenance tasks with educational output
#
# This module serves as a template and learning resource for user-level modules.
# It demonstrates proper handling of user configurations, AUR package management,
# and other user-specific maintenance tasks common in the update system.
#
# Safety: Read-only operations for demonstration
# Educational: Includes links to official documentation

# Module type declaration
MODULE_TYPE="user"

# Source utils if not already sourced
if ! command -v print_header &>/dev/null; then
    source "$(dirname "$(dirname "$(readlink -f "$0")")")/utils.sh"
fi

# Check if this module can run
check_supported() {
    # Example: check if a user tool exists
    command -v yay &>/dev/null
    return $?
}

# Run the update process
run_update() {
    print_header "${INFO_ICON} USER MAINTENANCE EXAMPLE"
    
    # User Module Structure Example
    print_status "${INFO_ICON}" "=== User Module Structure Example ==="
    print_status "${INFO_ICON}" "1. Header with description and safety info"
    print_status "${INFO_ICON}" "2. MODULE_TYPE declaration as 'user'"
    print_status "${INFO_ICON}" "3. User permission checks"
    print_status "${INFO_ICON}" "4. Configuration handling"
    print_status "${INFO_ICON}" "Learn more: https://wiki.archlinux.org/title/User:Example"
    
    # AUR Package Management Example
    print_status "${INFO_ICON}" "=== AUR Package Management Example ==="
    print_status "${SYNC_ICON}" "Checking AUR packages..."
    if ! aur_count=$(pacman -Qm | wc -l); then
        print_error "Failed to check AUR packages"
        print_error "Common issues:"
        print_error "- Database access"
        print_error "- Package manager lock"
        return 1
    fi
    print_status "${INFO_ICON}" "Found ${aur_count} AUR packages"
    print_status "${INFO_ICON}" "Learn more: https://wiki.archlinux.org/title/AUR_helpers"
    
    # User Configuration Example
    print_status "${INFO_ICON}" "=== User Configuration Example ==="
    print_status "${INFO_ICON}" "Configuration locations:"
    print_status "${INFO_ICON}" "1. ~/.config - XDG config home"
    print_status "${INFO_ICON}" "2. ~/.local/share - XDG data home"
    print_status "${INFO_ICON}" "3. ~/.cache - XDG cache home"
    print_status "${INFO_ICON}" "Learn more: https://wiki.archlinux.org/title/XDG_Base_Directory"
    
    # Safety Features Example
    print_status "${INFO_ICON}" "=== User Safety Features Example ==="
    print_status "${INFO_ICON}" "1. Config file backups"
    print_status "${INFO_ICON}" "2. Permission verification"
    print_status "${INFO_ICON}" "3. Safe update practices"
    print_status "${INFO_ICON}" "4. Recovery options"
    print_status "${INFO_ICON}" "Learn more: https://wiki.archlinux.org/title/System_maintenance#User_specific"
    
    return 0
}

# If script is run directly, check support and run
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if check_supported; then
        run_update
    else
        echo "Module requirements not met"
        exit 1
    fi
fi
