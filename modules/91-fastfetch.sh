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
    print_section_box \
        "About Fastfetch" \
        "Fastfetch is a fast, highly customizable system info tool\nDisplays detailed system information in a clean, organized format" \
        "https://github.com/fastfetch-cli/fastfetch"
    
    # Run fastfetch with error handling
    if ! fastfetch; then
        print_error "Failed to display system information"
        print_info_box "Common issues:\n- Configuration file missing or invalid\n- Required system information not accessible\n- Display issues with certain terminal emulators"
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
