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
    print_header "${ICONS[sync]} UPDATING OH-MY-POSH"
    
    # Educational output about oh-my-posh
    print_section_box \
        "About Oh My Posh" \
        "oh-my-posh is a custom prompt engine for any shell\nRegular updates ensure latest features and security" \
        "https://ohmyposh.dev/"
    
    # Check current version before update
    print_status "${ICONS[sync]}" "Checking current version..."
    if ! current_version=$(oh-my-posh version 2>/dev/null); then
        print_error "Failed to get current version"
        return 1
    fi
    print_info_box "Current version: ${current_version}"
    
    # Check for config file
    config_file="${HOME}/.config/oh-my-posh/config.json"
    if [[ -f "${config_file}" ]]; then
        print_info_box "Found configuration at: ${config_file}"
    else
        print_warning "No custom configuration found at: ${config_file}"
    fi
    
    # In dry-run mode, just show what would be done
    if [[ -n "$DRY_RUN" ]]; then
        print_status "${ICONS[info]}" "Would attempt to upgrade oh-my-posh from version ${current_version}"
        print_status "${ICONS[info]}" "This would:"
        print_status "${ICONS[info]}" "• Download latest oh-my-posh release"
        print_status "${ICONS[info]}" "• Replace current binary with new version"
        print_status "${ICONS[info]}" "• Preserve existing configuration at ${config_file}"
        return 0
    fi
    
    # Perform update
    print_status "${ICONS[sync]}" "Updating oh-my-posh..."
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
        print_info_box "Review changelog: https://github.com/JanDeDobbeleer/oh-my-posh/releases"
    else
        print_success "oh-my-posh is already at latest version ${current_version}"
    fi
    
    # Additional educational information
    print_info_box "Configuration Tips:\n- Backup your config file regularly\n- Check themes at: https://ohmyposh.dev/docs/themes\n- Test changes with: oh-my-posh init bash --config path/to/config.json"
    
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
