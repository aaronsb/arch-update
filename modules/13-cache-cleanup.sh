#!/bin/bash
#
# Package Cache Cleanup (10-19 priority range)
# Handles cleaning of pacman package cache to free disk space
#
# This module manages the pacman package cache, removing old versions while keeping
# the most recent ones. This helps maintain system performance by preventing
# excessive disk usage from accumulated package files.
#
# Safety: Keeps last 3 versions of each package
# Rollback: Recent versions remain available for downgrade if needed

# Module type declaration
MODULE_TYPE="system"

# Source utils if not already sourced
if ! command -v print_header &>/dev/null; then
    source "$(dirname "$(dirname "$(readlink -f "$0")")")/utils.sh"
fi

# Check if this module can run
check_supported() {
    command -v paccache &>/dev/null
    return $?
}

# Backup package list before cleanup
backup_package_list() {
    local backup_dir="/tmp/update-scripts/cache"
    mkdir -p "$backup_dir"
    pacman -Q > "$backup_dir/packages-$(date +%Y%m%d-%H%M%S).txt"
}

# Run the update process
run_update() {
    print_header "${TRASH_ICON} CLEANING PACKAGE CACHE"
    
    # Educational output about package cache
    print_section_box \
        "About Package Cache" \
        "The package cache stores downloaded packages for possible rollbacks\nRegular cleanup prevents excessive disk usage while keeping recent versions" \
        "https://wiki.archlinux.org/title/Pacman#Cleaning_the_package_cache"
    
    # Create backup of current package list
    print_info_box "Creating backup of current package list for safety\nBackup location: /tmp/update-scripts/cache/"
    backup_package_list
    
    # Get initial cache size
    local initial_size=$(du -sh /var/cache/pacman/pkg/ 2>/dev/null | cut -f1)
    print_status "${INFO_ICON}" "Current package cache size: $initial_size"
    
    # Clean package cache
    print_status "${SYNC_ICON}" "Cleaning package cache (keeping last 3 versions)..."
    if ! sudo paccache -r; then
        print_error "Failed to clean package cache: paccache removal failed"
        print_info_box "Common issues:\n- Pacman is currently running\n- Cache directory is locked\n- Insufficient permissions"
        return 1
    fi
    
    # Remove all cached versions of uninstalled packages
    print_status "${SYNC_ICON}" "Removing cached versions of uninstalled packages..."
    if ! sudo paccache -ruk0; then
        print_warning "Failed to remove uninstalled package cache: paccache uninstalled cleanup failed"
        print_warning "This is non-critical, continuing with cleanup..."
    fi
    
    # Get final cache size
    local final_size=$(du -sh /var/cache/pacman/pkg/ 2>/dev/null | cut -f1)
    local saved_space=$(echo "$initial_size $final_size" | awk '{print $1-$2}')
    print_info_box "Package Cache Cleanup Summary:\n- Initial size: $initial_size\n- Final size: $final_size\n- Space freed: $saved_space\n- Backup saved in /tmp/update-scripts/cache/\n\nNote: Last 3 versions of each package are kept for safety"
    
    print_success "Package cache cleaned successfully"
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
