#!/bin/bash

# Function to check system health
check_system_health() {
    local SCRIPT_DIR="$1"
    
    # Source utils.sh if not already sourced
    if ! command -v print_header &>/dev/null; then
        source "$SCRIPT_DIR/utils.sh"
    fi
    
    # Set up error handling
    set_error_handlers
    print_header "${INFO_ICON} PERFORMING SYSTEM HEALTH CHECKS"
    
    # Network check
    check_network || return 1
    
    # Disk space check
    check_disk_space || return 1
    
    return 0
}

# Run checks if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    check_system_health
fi
