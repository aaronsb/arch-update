#!/bin/bash
#
# oh-my-posh update module
# Updates oh-my-posh if installed

MODULE_TYPE="user"

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
    
    # Educational output about oh-my-posh
    print_status "${INFO_ICON}" "oh-my-posh is a custom prompt engine for any shell"
    print_status "${INFO_ICON}" "Regular updates ensure latest features and security"
    print_status "${INFO_ICON}" "Learn more: https://ohmyposh.dev/"
    
    # Check current version before update
    print_status "${SYNC_ICON}" "Checking current version..."
    if ! current_version=$(oh-my-posh version 2>/dev/null); then
        print_error "Failed to get current version"
        return 1
    fi
    print_status "${INFO_ICON}" "Current version: ${current_version}"
    
    # Check for config file
    config_file="${HOME}/.config/oh-my-posh/config.json"
    if [[ -f "${config_file}" ]]; then
        print_status "${INFO_ICON}" "Found configuration at: ${config_file}"
    else
        print_warning "No custom configuration found at: ${config_file}"
    fi
    
    # Perform update
    print_status "${SYNC_ICON}" "Updating oh-my-posh..."
    if ! sudo oh-my-posh upgrade; then
        print_error "Failed to update oh-my-posh"
        return 1
    fi
    
    # Show new version and educational info
    if ! new_version=$(oh-my-posh version 2>/dev/null); then
        print_error "Failed to get new version"
        return 1
    fi
    if [[ "${current_version}" != "${new_version}" ]]; then
        print_success "Updated from ${current_version} to ${new_version}"
        print_status "${INFO_ICON}" "Review changelog: https://github.com/JanDeDobbeleer/oh-my-posh/releases"
    else
        print_success "oh-my-posh is already at latest version ${current_version}"
    fi
    
    # Additional educational information
    print_status "${INFO_ICON}" "Configuration tips:"
    print_status "${INFO_ICON}" "- Backup your config file regularly"
    print_status "${INFO_ICON}" "- Check themes at: https://ohmyposh.dev/docs/themes"
    print_status "${INFO_ICON}" "- Test changes with: oh-my-posh init bash --config path/to/config.json"
    
    return 0
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
