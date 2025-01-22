#!/bin/bash
#
# oh-my-posh update module
# Updates oh-my-posh if installed

# Source utils if not already sourced
if ! command -v print_header &>/dev/null; then
    source "$(dirname "$(dirname "$(readlink -f "$0")")")/utils.sh"
fi

# Check if this module can run
check_supported() {
    command -v oh-my-posh &>/dev/null
    return $?
}

# Run the update process
run_update() {
    print_header "${SYNC_ICON} UPDATING OH-MY-POSH"
    
    if ! sudo oh-my-posh upgrade; then
        print_warning "Failed to update oh-my-posh"
        return 1
    else
        print_success "oh-my-posh updated successfully"
        return 0
    fi
}

# If script is run directly, check support and run
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if check_supported; then
        run_update
    else
        echo "oh-my-posh is not installed"
        exit 1
    fi
fi
