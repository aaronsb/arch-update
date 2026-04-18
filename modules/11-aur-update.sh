#!/bin/bash
# Update AUR packages via the first available AUR helper.

MODULE_TYPE="system"
MODULE_NAME="aur-update"
MODULE_DESCRIPTION="Update AUR packages with yay or paru"
MODULE_DRY_RUN_SAFE="true"

check_supported() {
    command -v yay &>/dev/null || command -v paru &>/dev/null
}

get_aur_helper() {
    for helper in yay paru; do
        command -v "$helper" &>/dev/null && { echo "$helper"; return 0; }
    done
    return 1
}

run_update() {
    print_header "${ICONS[package]} UPDATING AUR PACKAGES"

    print_section_box \
        "About AUR" \
        "The AUR (Arch User Repository) contains community packages\nAUR helpers automate building and installing AUR packages" \
        "https://wiki.archlinux.org/title/Arch_User_Repository"

    local helper
    helper=$(get_aur_helper) || { print_error "No AUR helper found"; return 1; }
    print_info_box "Using AUR helper: $helper"

    print_status "${ICONS[sync]}" "Checking for AUR updates..."
    local updates
    updates=$("$helper" -Qum 2>/dev/null)

    if [[ -z "$updates" ]]; then
        print_success "No AUR updates available"
        return 0
    fi

    print_status "${ICONS[package]}" "AUR updates available:"
    echo "$updates"

    if [[ -n "$DRY_RUN" ]]; then
        local n
        n=$(wc -l <<< "$updates")
        print_status "${ICONS[info]}" "Would update $n AUR package(s)"
        return 0
    fi

    print_status "${ICONS[sync]}" "Running AUR updates..."
    if ! "$helper" -Sua --noconfirm; then
        print_error "Failed to update AUR packages"
        return 1
    fi
    print_success "AUR packages updated"
}
