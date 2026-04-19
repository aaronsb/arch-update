#!/bin/bash
# Initialize and refresh the pacman keyring so package signatures validate.

MODULE_TYPE="system"
MODULE_NAME="keyring-update"
MODULE_DESCRIPTION="Initialize and refresh the pacman keyring"
MODULE_REQUIRES="pacman-key"
MODULE_DRY_RUN_SAFE="true"

run_update() {
    print_header "${ICONS[key]} UPDATING PACMAN KEYRING"

    print_section_box \
        "About Package Signing" \
        "The pacman keyring ensures package authenticity\nPackage signing prevents malicious modifications" \
        "https://wiki.archlinux.org/title/Pacman/Package_signing"

    if [[ -n "$DRY_RUN" ]]; then
        print_status "${ICONS[info]}" "Would initialize keyring if missing and refresh trustdb"
        return 0
    fi

    print_status "${ICONS[key]}" "Checking pacman keyring..."

    if [[ ! -d "/etc/pacman.d/gnupg" ]]; then
        print_info_box "Keyring directory not found\nInitializing new keyring"
        if ! sudo pacman-key --init; then
            print_error "Failed to initialize pacman keyring"
            return 1
        fi
        print_success "Keyring initialized"
    fi

    print_status "${ICONS[sync]}" "Verifying trust database..."
    if sudo pacman-key --updatedb &>/dev/null; then
        print_success "Pacman keyring verified"
        return 0
    fi

    print_warning "Trust database needs updating"

    print_status "${ICONS[sync]}" "Populating keyring with official Arch Linux keys..."
    if ! sudo pacman-key --populate archlinux; then
        print_error "Failed to populate keyring"
        return 1
    fi

    print_status "${ICONS[sync]}" "Refreshing keys from keyservers..."
    if ! sudo pacman-key --refresh-keys; then
        print_warning "Failed to refresh keys (often transient)"
    fi

    if ! sudo pacman-key --updatedb &>/dev/null; then
        print_error "Trust database still invalid after update"
        return 1
    fi

    print_success "Pacman keyring updated"
}
