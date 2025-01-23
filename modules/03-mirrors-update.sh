#!/bin/bash
#
# Arch Linux mirror list update module
# Updates pacman mirror list using reflector if installed
# Provides educational information about mirror selection and management

MODULE_TYPE="system"

# Source utils if not already sourced
if ! command -v print_header &>/dev/null; then
    source "$(dirname "$(dirname "$(readlink -f "$0")")")/utils.sh"
fi

check_supported() {
    # Check if reflector is installed
    if ! command -v reflector &>/dev/null; then
        return 1
    fi
    return 0
}

run_update() {
    print_header "${SYNC_ICON} UPDATING MIRROR LIST"
    
    # Educational output about mirrors
    print_section_box \
        "About Mirrors" \
        "Mirrors are servers that host Arch Linux packages\nUsing fast, reliable mirrors improves download speed" \
        "https://wiki.archlinux.org/title/Mirrors"
    
    # Check current mirror list
    local mirrorlist="/etc/pacman.d/mirrorlist"
    if [ ! -f "$mirrorlist" ]; then
        print_error "Mirror list not found: $mirrorlist"
        return 1
    fi
    
    # Backup current mirror list
    print_status "${SYNC_ICON}" "Backing up current mirror list..."
    if ! sudo cp "$mirrorlist" "${mirrorlist}.backup"; then
        print_error "Failed to backup mirror list"
        return 1
    fi
    
    # Update mirrors with detailed output
    print_status "${SYNC_ICON}" "Finding fastest mirrors..."
    print_info_box "This may take a few minutes"
    print_info_box "Using criteria:\n- Latest 20 mirrors\n- HTTPS protocol only\n- Sorted by download rate"
    
    if ! sudo reflector --latest 20 --protocol https --sort rate --save "$mirrorlist"; then
        print_error "Failed to update mirror list"
        print_info_box "Common issues:\n- Network connectivity problems\n- Mirror server issues\n- Permission problems"
        print_status "${INFO_ICON}" "Restoring backup..."
        sudo mv "${mirrorlist}.backup" "$mirrorlist"
        return 1
    fi
    
    # Verify new mirror list
    if [ ! -s "$mirrorlist" ]; then
        print_error "New mirror list is empty"
        print_status "${INFO_ICON}" "Restoring backup..."
        sudo mv "${mirrorlist}.backup" "$mirrorlist"
        return 1
    fi
    
    print_success "Mirror list updated successfully"
    print_info_box "Backup saved as: ${mirrorlist}.backup\nView mirrors: cat $mirrorlist"
    return 0
}

# If script is run directly, check support and run
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if check_supported; then
        run_update
    else
        echo "reflector is not installed"
        exit 1
    fi
fi
