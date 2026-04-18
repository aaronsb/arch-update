#!/bin/bash
# Remove old package versions from the pacman cache.

MODULE_TYPE="system"
MODULE_NAME="cache-cleanup"
MODULE_DESCRIPTION="Trim old package versions from the pacman cache"
MODULE_REQUIRES="paccache"
MODULE_DRY_RUN_SAFE="true"

run_update() {
    print_header "${ICONS[trash]} CLEANING PACKAGE CACHE"

    print_section_box \
        "About Package Cache" \
        "Package cache stores downloaded packages for possible rollback\nRegular cleanup helps manage disk space" \
        "https://wiki.archlinux.org/title/Pacman#Cleaning_the_package_cache"

    local cache_dir="/var/cache/pacman/pkg"
    if [[ ! -d "$cache_dir" ]]; then
        print_error "Package cache directory not found"
        return 1
    fi

    local current_size
    current_size=$(du -sh "$cache_dir" 2>/dev/null | cut -f1)
    print_status "${ICONS[info]}" "Current cache size: $current_size"

    if [[ -n "$DRY_RUN" ]]; then
        print_status "${ICONS[info]}" "Would run: paccache -rk3 (keep latest 3 per package)"
        paccache -dk3 2>/dev/null | tail -n 3
        return 0
    fi

    print_status "${ICONS[trash]}" "Cleaning package cache..."
    if ! sudo paccache -r; then
        print_error "Failed to clean package cache"
        return 1
    fi

    local new_size
    new_size=$(du -sh "$cache_dir" 2>/dev/null | cut -f1)
    print_success "Cache cleaned ($current_size -> $new_size)"
}
