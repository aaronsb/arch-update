#!/bin/bash
#
# Display system information using fastfetch
# This is a post-update status module that runs without privileges
# Provides a clean, fast system information display after updates complete

# Source utils if not already sourced
if ! command -v print_header &>/dev/null; then
    source "$(dirname "$(dirname "$(readlink -f "$0")")")/utils.sh"
fi

MODULE_TYPE="status"

# Check if this module can run
check_supported() {
    command -v fastfetch &>/dev/null
    return $?
}

# Run the update process
run_update() {
    print_header "${INFO_ICON} SYSTEM INFORMATION"
    
    # Educational output explaining fastfetch
    print_status "${INFO_ICON}" "Displaying system information using fastfetch"
    print_status "${INFO_ICON}" "Fastfetch is a fast, highly customizable system info tool"
    print_status "${INFO_ICON}" "Learn more: https://github.com/fastfetch-cli/fastfetch"
    
    # Run fastfetch with error handling
    if ! fastfetch; then
        print_error "Failed to display system information"
        return 1
    fi
    
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
