#!/bin/bash
#
# Flatpak Updates (20-29 priority range)
# Handles updating of Flatpak packages if installed
#
# This module manages Flatpak package updates, providing containerized application
# updates separate from the core system packages. It checks for available updates,
# displays version information, and handles the update process safely.
#
# Safety: Shows version changes before updating
# Rollback: Flatpak maintains previous versions for rollback

# Module type declaration
MODULE_TYPE="system"

# Source utils if not already sourced
if ! command -v print_header &>/dev/null; then
    source "$(dirname "$(dirname "$(readlink -f "$0")")")/utils.sh"
fi

# Check if this module can run
check_supported() {
    command -v flatpak &>/dev/null
    return $?
}

# Check network connectivity
check_network() {
    if ! ping -c 1 flathub.org &>/dev/null; then
        print_error "No network connection to Flatpak repositories"
        print_error "Please check your internet connection"
        return 1
    fi
    return 0
}

# Get detailed update information
get_update_details() {
    local updates="$1"
    print_status "${INFO_ICON}" "Update details:"
    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            local app_id=$(echo "$line" | awk '{print $1}')
            local old_version=$(flatpak info "$app_id" | grep "Version:" | cut -d: -f2 | tr -d ' ')
            local new_version=$(echo "$line" | awk '{print $3}')
            print_status "${INFO_ICON}" "- $app_id: $old_version → $new_version"
        fi
    done <<< "$updates"
}

# Run the update process
run_update() {
    print_header "${PACKAGE_ICON} UPDATING FLATPAK PACKAGES"
    
    # Educational output about Flatpak
    print_section_box \
        "About Flatpak" \
        "Flatpak provides containerized applications with automatic updates\nPackages are sandboxed for enhanced security and compatibility" \
        "https://wiki.archlinux.org/title/Flatpak"
    
    # Verify network connectivity first
    if ! check_network; then
        return 1
    fi
    
    # Check if any Flatpak packages are installed
    if ! flatpak list | grep -q .; then
        print_success "No Flatpak packages installed"
        return 0
    fi
    
    # List current updates
    print_status "${SYNC_ICON}" "Checking for Flatpak updates..."
    local updates=$(flatpak remote-ls --updates)
    if [ $? -ne 0 ]; then
        print_error "Failed to check for updates: flatpak remote-ls failed"
        print_info_box "Try running 'flatpak repair' to fix repository issues"
        return 1
    fi
    
    if [ -z "$updates" ]; then
        print_success "All Flatpak packages are up to date"
        return 0
    fi
    
    # Show available updates with version details
    print_status "${PACKAGE_ICON}" "Updates available:"
    echo "$updates"
    get_update_details "$updates"
    
    # Perform update
    print_status "${SYNC_ICON}" "Updating Flatpak packages..."
    if ! flatpak update -y; then
        print_error "Failed to update Flatpak packages"
        print_info_box "Common issues:\n- Disk space: Check available space with 'df -h'\n- Permissions: Ensure proper user permissions\n- Repository: Try 'flatpak repair' to fix repo issues"
        return 1
    fi
    
    print_success "Flatpak packages updated successfully"
    print_info_box "Rollback Instructions:\nUse 'flatpak history' to view changes\nUse 'flatpak undo' to revert updates"
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
