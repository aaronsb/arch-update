#!/bin/bash
# Synchronize and upgrade official repository packages via pacman.

MODULE_TYPE="system"
MODULE_NAME="pacman-update"
MODULE_DESCRIPTION="Sync and upgrade official repo packages"
MODULE_REQUIRES="pacman"
MODULE_DRY_RUN_SAFE="true"

run_update() {
    print_header "${ICONS[package]} UPDATING SYSTEM PACKAGES"

    print_section_box \
        "About Package Management" \
        "pacman is the package manager for Arch Linux\nRegular updates ensure system stability and security" \
        "https://wiki.archlinux.org/title/Pacman"

    if command -v checkupdates &>/dev/null; then
        print_status "${ICONS[sync]}" "Checking for updates..."
        local updates
        updates=$(checkupdates 2>/dev/null)
        local rc=$?
        # checkupdates: 0 = updates pending, 2 = none pending, 1 = check failed.
        case $rc in
            0)
                print_status "${ICONS[package]}" "Updates available:"
                echo "$updates"
                if [[ -n "$DRY_RUN" ]]; then
                    local n
                    n=$(wc -l <<< "$updates")
                    print_status "${ICONS[info]}" "Would update $n package(s)"
                    return 0
                fi
                ;;
            2)
                print_success "System is up to date"
                return 0
                ;;
            *)
                if [[ -n "$DRY_RUN" ]]; then
                    print_warning "Update check failed (checkupdates exit $rc)"
                    return 0
                fi
                print_warning "Update check failed; proceeding anyway"
                ;;
        esac
    fi

    [[ -n "$DRY_RUN" ]] && return 0

    if [[ -f "$PACMAN_DB_LOCK" ]]; then
        print_error "Package manager is locked. Another pacman operation may be in progress."
        print_status "${ICONS[info]}" "If none is running: sudo rm $PACMAN_DB_LOCK"
        return 1
    fi

    print_status "${ICONS[sync]}" "Running system update..."
    if ! sudo pacman -Syu --noconfirm; then
        print_error "Failed to update system packages"
        return 1
    fi

    print_success "System packages updated"
    print_info_box "• Some updates may require a reboot\n• Log: /var/log/pacman.log"
}
