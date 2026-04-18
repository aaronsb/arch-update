#!/bin/bash
# Update installed Flatpak applications.

MODULE_TYPE="system"
MODULE_NAME="flatpak-update"
MODULE_DESCRIPTION="Update installed Flatpak apps"
MODULE_REQUIRES="flatpak"
MODULE_DRY_RUN_SAFE="true"

run_update() {
    print_header "${ICONS[package]} UPDATING FLATPAK APPLICATIONS"

    print_section_box \
        "About Flatpak" \
        "Flatpak is a universal package format for Linux applications\nUpdates ensure latest features and security fixes" \
        "https://flatpak.org/"

    print_status "${ICONS[sync]}" "Checking for Flatpak updates..."
    local updates
    updates=$(flatpak remote-ls --updates 2>/dev/null)

    if [[ -z "$updates" ]]; then
        print_success "All Flatpak apps up to date"
        return 0
    fi

    print_status "${ICONS[package]}" "Updates available:"
    echo "$updates"

    local n
    n=$(wc -l <<< "$updates")

    if [[ -n "$DRY_RUN" ]]; then
        print_status "${ICONS[info]}" "Would update $n Flatpak app(s)"
        return 0
    fi

    print_status "${ICONS[sync]}" "Updating Flatpak apps..."
    if ! flatpak update --noninteractive; then
        print_error "Failed to update Flatpak applications"
        return 1
    fi
    print_success "Updated $n Flatpak app(s)"
}
