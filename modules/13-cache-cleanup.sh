#!/bin/bash
#
# Package Cache Cleanup (10-19 priority range)
# Cleans old package cache to free disk space
# Provides educational information about package cache maintenance

MODULE_TYPE="system"

# Source utils if not already sourced
if ! command -v print_header &>/dev/null; then
    source "$(dirname "$(dirname "$(readlink -f "$0")")")/utils.sh"
fi

# Check if this module can run
check_supported() {
    command -v pacman &>/dev/null
    return $?
}

# Run the cleanup process
run_update() {
    print_header "${ICONS[trash]} CLEANING PACKAGE CACHE"
    
    # Educational output about package cache
    print_section_box \
        "About Package Cache" \
        "Package cache stores downloaded packages for possible rollback\nRegular cleanup helps manage disk space" \
        "https://wiki.archlinux.org/title/Pacman#Cleaning_the_package_cache"
    
    # Check current cache size and content
    print_status "${ICONS[sync]}" "Analyzing package cache..."
    local cache_dir="/var/cache/pacman/pkg"
    local current_size=$(du -sh "$cache_dir" 2>/dev/null | cut -f1)
    
    if [ ! -d "$cache_dir" ]; then
        print_error "Package cache directory not found"
        return 1
    fi
    
    # Count packages and calculate sizes
    local total_packages=$(ls -1 "$cache_dir"/*.pkg.tar.* 2>/dev/null | wc -l)
    local uninstalled_packages=$(pacman -Qdtq | wc -l)
    local old_versions=$(ls -1 "$cache_dir" | grep -v "$(pacman -Q | awk '{print $1"-"$2}' | sed 's/-[^-]*$/-/' | tr '\n' '|' | sed 's/|$//')" | wc -l)
    
    print_info_box "Current cache status:\n• Total size: $current_size\n• Total packages: $total_packages\n• Old versions: $old_versions"
    
    # In dry-run mode, show what would be cleaned
    if [[ -n "$DRY_RUN" ]]; then
        print_status "${ICONS[info]}" "Would clean package cache:"
        print_status "${ICONS[info]}" "• Current cache size: $current_size"
        print_status "${ICONS[info]}" "• Would remove all but the latest version of each package"
        print_status "${ICONS[info]}" "• Approximately $old_versions package(s) would be removed"
        print_status "${ICONS[info]}" "This would:"
        print_status "${ICONS[info]}" "• Free up significant disk space"
        print_status "${ICONS[info]}" "• Keep latest version of each package for potential rollback"
        print_status "${ICONS[info]}" "• Remove old and unneeded package versions"
        return 0
    fi
    
    # Perform cache cleanup
    print_status "${ICONS[trash]}" "Cleaning package cache..."
    if ! sudo paccache -r; then
        print_error "Failed to clean package cache"
        print_info_box "Common issues:\n• Insufficient permissions\n• Disk write errors\n• Cache lock issues"
        return 1
    fi
    
    # Calculate space saved
    local new_size=$(du -sh "$cache_dir" 2>/dev/null | cut -f1)
    print_success "Successfully cleaned package cache"
    print_info_box "Results:\n• Previous size: $current_size\n• Current size: $new_size\n• Latest version of each package retained"
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
