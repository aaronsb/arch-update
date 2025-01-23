#!/bin/bash
#
# Orphaned Packages Cleanup (10-19 priority range)
# Handles removal of orphaned packages to maintain system cleanliness
#
# This module identifies and removes packages that were installed as dependencies
# but are no longer required by any installed package. This helps keep the system
# clean and reduces disk usage by removing unnecessary packages.
#
# Safety: Creates a backup list of orphaned packages before removal
# Rollback: Packages can be reinstalled from backup if needed

# Module type declaration
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

# Backup orphaned packages list
backup_orphans() {
    local backup_dir="/tmp/update-scripts/orphans"
    mkdir -p "$backup_dir"
    echo "$1" > "$backup_dir/orphans-$(date +%Y%m%d-%H%M%S).txt"
}

# Run the update process
run_update() {
    print_header "${TRASH_ICON} CHECKING FOR ORPHANED PACKAGES"
    
    # Educational output about orphaned packages
    print_section_box \
        "About Orphaned Packages" \
        "Orphaned packages are former dependencies no longer required by any installed package\nRemoving them helps maintain system cleanliness and reduces disk usage" \
        "https://wiki.archlinux.org/title/Pacman#Removing_unused_packages"
    
    # Find orphaned packages
    local orphans=$(pacman -Qdtq)
    if [ $? -ne 0 ]; then
        print_error "Failed to check for orphaned packages: pacman query failed"
        print_info_box "Please check if pacman database is locked or corrupted"
        return 1
    fi
    
    # Handle orphaned packages if found
    if [ ! -z "$orphans" ]; then
        print_status "${INFO_ICON}" "Found orphaned packages:"
        echo "$orphans"
        
        # Create backup before removal
        print_info_box "Creating backup of orphaned packages list for safety\nBackup location: /tmp/update-scripts/orphans/"
        backup_orphans "$orphans"
        
        print_status "${SYNC_ICON}" "Removing orphaned packages..."
        if ! sudo pacman -Rns $orphans --noconfirm; then
            print_error "Failed to remove orphaned packages: pacman removal failed"
            print_info_box "Recovery Instructions:\n- Package list saved in /tmp/update-scripts/orphans/\n- To reinstall, use: pacman -S \$(cat /tmp/update-scripts/orphans/[backup-file])"
            return 1
        fi
        print_success "Orphaned packages removed successfully"
        print_info_box "Backup saved in /tmp/update-scripts/orphans/\nKeep this backup until you verify system stability"
    else
        print_success "No orphaned packages found"
    fi
    
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
