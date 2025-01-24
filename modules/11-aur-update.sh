#!/bin/bash
#
# AUR Package Updates (10-19 priority range)
# Handles AUR package updates via detected AUR helper
# Provides educational information about AUR package management

MODULE_TYPE="system"

# Source utils if not already sourced
if ! command -v print_header &>/dev/null; then
    source "$(dirname "$(dirname "$(readlink -f "$0")")")/utils.sh"
fi

# Check if this module can run
check_supported() {
    # Check for common AUR helpers
    for helper in yay paru; do
        if command -v "$helper" &>/dev/null; then
            return 0
        fi
    done
    return 1
}

# Detect installed AUR helper
get_aur_helper() {
    for helper in yay paru; do
        if command -v "$helper" &>/dev/null; then
            echo "$helper"
            return 0
        fi
    done
    echo "none"
    return 1
}

# Run the update process
run_update() {
    print_header "${ICONS[package]} UPDATING AUR PACKAGES"
    
    # Educational output about AUR
    print_section_box \
        "About AUR" \
        "The AUR (Arch User Repository) contains community packages\nAUR helpers automate building and installing AUR packages" \
        "https://wiki.archlinux.org/title/Arch_User_Repository"
    
    # Get AUR helper
    local aur_helper=$(get_aur_helper)
    if [ "$aur_helper" = "none" ]; then
        print_error "No supported AUR helper found"
        return 1
    fi
    
    print_info_box "• Using AUR helper: $aur_helper\n• Supported helpers: yay, paru"
    
    # Check for updates first
    print_status "${ICONS[sync]}" "Checking for AUR updates..."
    local updates
    if [[ "$aur_helper" == "yay" ]]; then
        updates=$(yay -Qum 2>/dev/null)
    else
        updates=$(paru -Qum 2>/dev/null)
    fi
    
    if [ $? -ne 0 ]; then
        print_error "Failed to check for AUR updates"
        return 1
    fi
    
    if [ -z "$updates" ]; then
        print_success "No AUR updates available"
        return 0
    fi
    
    # Show available updates
    print_status "${ICONS[package]}" "AUR updates available:"
    echo "$updates"
    
    # In dry-run mode, just show what would be updated
    if [[ -n "$DRY_RUN" ]]; then
        local update_count=$(echo "$updates" | wc -l)
        print_status "${ICONS[info]}" "Would update $update_count AUR package(s)"
        print_status "${ICONS[info]}" "This would:"
        print_status "${ICONS[info]}" "• Download updated PKGBUILD files"
        print_status "${ICONS[info]}" "• Verify package integrity"
        print_status "${ICONS[info]}" "• Build packages from source"
        print_status "${ICONS[info]}" "• Install built packages"
        return 0
    fi
    
    # Perform AUR update with detailed output
    print_status "${ICONS[sync]}" "Running AUR updates..."
    print_status "${ICONS[info]}" "This will download, build, and install AUR packages"
    
    if ! $aur_helper -Sua --noconfirm; then
        print_error "Failed to update AUR packages"
        print_info_box "Common issues:\n• Network connectivity problems\n• Build dependencies missing\n• Package maintainer changes"
        return 1
    fi
    
    # Show post-update information
    print_success "AUR packages updated successfully"
    print_info_box "• Review installed AUR packages: $aur_helper -Qm\n• Check package issues: https://aur.archlinux.org"
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
