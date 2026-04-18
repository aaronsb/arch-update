#!/bin/bash
# Refresh the pacman mirrorlist using reflector.

MODULE_TYPE="system"
MODULE_NAME="mirrors-update"
MODULE_DESCRIPTION="Refresh the mirrorlist with reflector"
MODULE_REQUIRES="reflector"
MODULE_DRY_RUN_SAFE="true"

run_update() {
    print_header "${ICONS[sync]} UPDATING MIRROR LIST"

    print_section_box \
        "About Mirrors" \
        "Mirrors are servers that host Arch Linux packages\nUsing fast, reliable mirrors improves download speed" \
        "https://wiki.archlinux.org/title/Mirrors"

    local mirrorlist="/etc/pacman.d/mirrorlist"
    if [[ ! -f "$mirrorlist" ]]; then
        print_error "Mirror list not found: $mirrorlist"
        return 1
    fi

    if [[ -n "$DRY_RUN" ]]; then
        print_status "${ICONS[info]}" "Would refresh $mirrorlist (latest 20, HTTPS, sorted by rate)"
        return 0
    fi

    print_status "${ICONS[sync]}" "Backing up current mirror list..."
    if ! sudo cp "$mirrorlist" "${mirrorlist}.backup"; then
        print_error "Failed to backup mirror list"
        return 1
    fi

    print_status "${ICONS[sync]}" "Finding fastest mirrors..."
    print_info_box "Criteria: latest 20, HTTPS, sorted by download rate"

    if ! sudo reflector --latest 20 --protocol https --sort rate --save "$mirrorlist"; then
        print_error "Failed to update mirror list, restoring backup"
        sudo mv "${mirrorlist}.backup" "$mirrorlist"
        return 1
    fi

    if [[ ! -s "$mirrorlist" ]]; then
        print_error "New mirror list is empty, restoring backup"
        sudo mv "${mirrorlist}.backup" "$mirrorlist"
        return 1
    fi

    print_success "Mirror list updated"
    print_info_box "Backup saved as: ${mirrorlist}.backup"
}
