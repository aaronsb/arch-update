#!/bin/bash
#
# Arch Linux pacman database verification module
# Checks and repairs the pacman database if needed
# Provides educational information about package database maintenance

MODULE_TYPE="system"

# Source utils if not already sourced
if ! command -v print_header &>/dev/null; then
    source "$(dirname "$(dirname "$(readlink -f "$0")")")/utils.sh"
fi

check_supported() {
    # This module is supported on all Arch Linux systems
    return 0
}

run_update() {
    print_header "${PACKAGE_ICON} VERIFYING PACKAGE DATABASE"
    
    # Educational output about package database
    print_section_box \
        "About Package Database" \
        "The pacman database tracks installed packages\nDatabase integrity is crucial for system stability" \
        "https://wiki.archlinux.org/title/Pacman#Package_database"
    
    # Check database location
    local db_path="/var/lib/pacman"
    if [ ! -d "$db_path" ]; then
        print_error "Package database directory not found: $db_path"
        return 1
    fi
    
    # Check database permissions
    if [ ! -w "$db_path" ]; then
        print_error "Package database is not writable"
        print_info_box "Fix permissions: sudo chown -R root:root $db_path"
        return 1
    fi
    
    # Verify database integrity
    print_status "${SYNC_ICON}" "Checking package database integrity..."
    if ! sudo pacman -Dk &>/dev/null; then
        print_warning "Package database needs repair"
        print_info_box "This may be due to:\n- Interrupted package operations\n- Disk errors or power failures\n- Manual database modifications"
        
        print_status "${SYNC_ICON}" "Attempting database repair..."
        if ! sudo pacman -Dk --fix; then
            print_error "Failed to repair package database"
            print_info_box "Manual intervention may be required:\n1. Backup: cp -r $db_path ${db_path}.bak\n2. Remove: sudo rm -r $db_path/local\n3. Reinit: sudo pacman -Sy"
            return 1
        fi
        print_success "Database repaired successfully"
    else
        print_success "Package database verified"
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
