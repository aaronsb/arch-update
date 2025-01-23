#!/bin/bash
#
# Example System Module (10-29 priority range)
# Demonstrates core system maintenance tasks with educational output
#
# This module serves as a template and learning resource for system-level modules.
# It demonstrates proper module structure, error handling, safety features, and
# documentation practices used throughout the update system.
#
# Safety: Read-only operations for demonstration
# Educational: Includes links to official documentation

# Module type declaration
MODULE_TYPE="system"

# Source utils if not already sourced
if ! command -v print_header &>/dev/null; then
    source "$(dirname "$(dirname "$(readlink -f "$0")")")/utils.sh"
fi

# Check if this module can run
check_supported() {
    # Example: check if pacman exists (it should on Arch!)
    command -v pacman &>/dev/null
    return $?
}

# Run the update process
run_update() {
    print_header "${INFO_ICON} SYSTEM MAINTENANCE EXAMPLE"
    
    # Module Structure Example
    print_status "${INFO_ICON}" "=== Module Structure Example ==="
    print_status "${INFO_ICON}" "1. Header with description and safety info"
    print_status "${INFO_ICON}" "2. MODULE_TYPE declaration"
    print_status "${INFO_ICON}" "3. Utils sourcing check"
    print_status "${INFO_ICON}" "4. Support check function"
    print_status "${INFO_ICON}" "5. Main update function"
    print_status "${INFO_ICON}" "Learn more: https://wiki.archlinux.org/title/Bash_scripting"
    
    # Error Handling Example
    print_status "${INFO_ICON}" "=== Error Handling Example ==="
    print_status "${SYNC_ICON}" "Checking package cache size..."
    if ! cache_size=$(du -sh /var/cache/pacman/pkg/ 2>/dev/null | cut -f1); then
        print_error "Failed to check cache size"
        print_error "Common issues:"
        print_error "- Directory permissions"
        print_error "- Disk mount status"
        return 1
    fi
    print_status "${INFO_ICON}" "Package cache size: ${cache_size}"
    print_status "${INFO_ICON}" "Learn more: https://wiki.archlinux.org/title/System_maintenance"
    
    # Safety Features Example
    print_status "${INFO_ICON}" "=== Safety Features Example ==="
    print_status "${INFO_ICON}" "1. Backup critical data"
    print_status "${INFO_ICON}" "2. Version comparison before updates"
    print_status "${INFO_ICON}" "3. Rollback capabilities"
    print_status "${INFO_ICON}" "4. Permission checks"
    print_status "${INFO_ICON}" "Learn more: https://wiki.archlinux.org/title/System_backup"
    
    # Documentation Example
    print_status "${INFO_ICON}" "=== Documentation Example ==="
    print_status "${INFO_ICON}" "Each module includes:"
    print_status "${INFO_ICON}" "1. Detailed .md file"
    print_status "${INFO_ICON}" "2. Usage examples"
    print_status "${INFO_ICON}" "3. Troubleshooting guide"
    print_status "${INFO_ICON}" "4. Related documentation"
    print_status "${INFO_ICON}" "Learn more: https://wiki.archlinux.org/title/Help:Reading"
    
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
