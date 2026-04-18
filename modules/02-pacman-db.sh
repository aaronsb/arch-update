#!/bin/bash
# Verify and repair the pacman package database.

MODULE_TYPE="system"
MODULE_NAME="pacman-db"
MODULE_DESCRIPTION="Verify and repair the pacman package database"
MODULE_REQUIRES="pacman"
MODULE_DRY_RUN_SAFE="true"

run_update() {
    print_header "${ICONS[package]} VERIFYING PACKAGE DATABASE"

    print_section_box \
        "About Package Database" \
        "The pacman database tracks installed packages\nDatabase integrity is crucial for system stability" \
        "https://wiki.archlinux.org/title/Pacman#Package_database"

    local db_path="/var/lib/pacman"
    if [[ ! -d "$db_path" ]]; then
        print_error "Package database directory not found: $db_path"
        return 1
    fi

    print_status "${ICONS[sync]}" "Checking package database integrity..."
    if sudo pacman -Dk &>/dev/null; then
        print_success "Package database verified"
        return 0
    fi

    print_warning "Package database needs repair"

    if [[ -n "$DRY_RUN" ]]; then
        print_status "${ICONS[info]}" "Would run: sudo pacman -Dk --fix"
        return 0
    fi

    print_status "${ICONS[sync]}" "Attempting database repair..."
    if ! sudo pacman -Dk --fix; then
        print_error "Failed to repair package database"
        return 1
    fi
    print_success "Database repaired"
}
