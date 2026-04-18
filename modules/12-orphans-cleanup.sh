#!/bin/bash
# Remove packages no longer required by anything else.

MODULE_TYPE="system"
MODULE_NAME="orphans-cleanup"
MODULE_DESCRIPTION="Remove packages no longer required"
MODULE_REQUIRES="pacman"
MODULE_DRY_RUN_SAFE="true"

# Sum "Installed Size" fields from pacman -Qi output, returning MB.
orphan_total_mb() {
    local pkgs="$1"
    [[ -z "$pkgs" ]] && { echo 0; return; }
    # shellcheck disable=SC2086
    pacman -Qi $pkgs 2>/dev/null | awk '
        /^Installed Size/ {
            # Fields like "1.23 MiB", "456.00 KiB", "1.50 GiB"
            n = $(NF-1); u = $NF
            if (u == "KiB") bytes = n * 1024
            else if (u == "MiB") bytes = n * 1024 * 1024
            else if (u == "GiB") bytes = n * 1024 * 1024 * 1024
            else if (u == "B")   bytes = n
            else bytes = 0
            total += bytes
        }
        END { printf "%d", total / 1024 / 1024 }
    '
}

run_update() {
    print_header "${ICONS[trash]} CLEANING ORPHANED PACKAGES"

    print_section_box \
        "About Orphaned Packages" \
        "Orphaned packages are those no longer required as dependencies\nRemoving them helps maintain a clean system" \
        "https://wiki.archlinux.org/title/Pacman/Tips_and_tricks#Removing_unused_packages"

    print_status "${ICONS[sync]}" "Checking for orphaned packages..."
    local orphans
    orphans=$(pacman -Qtdq)

    if [[ -z "$orphans" ]]; then
        print_success "No orphaned packages found"
        return 0
    fi

    print_status "${ICONS[package]}" "Orphaned packages:"
    echo "$orphans"

    local total_mb
    total_mb=$(orphan_total_mb "$orphans")

    if [[ -n "$DRY_RUN" ]]; then
        local n
        n=$(wc -l <<< "$orphans")
        print_status "${ICONS[info]}" "Would remove $n orphan(s), freeing ~${total_mb}MB"
        return 0
    fi

    print_status "${ICONS[trash]}" "Removing orphaned packages..."
    # shellcheck disable=SC2086
    if ! sudo pacman -Rns $orphans --noconfirm; then
        print_error "Failed to remove orphaned packages"
        return 1
    fi
    print_success "Removed orphans, freed ~${total_mb}MB"
}
