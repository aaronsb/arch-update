#!/bin/bash

source ./utils.sh

# Set up error handling
set_error_handlers

check_system_health() {
    print_header "${INFO_ICON} PERFORMING SYSTEM HEALTH CHECKS"
    
    # Network check
    check_network || return 1
    
    # Disk space check
    check_disk_space || return 1
    
    # Pacman keyring check
    check_pacman_keyring || return 1
    
    # Check pacman database
    print_status "${PACKAGE_ICON}" "Checking pacman database..."
    if ! sudo pacman -Dk &>/dev/null; then
        print_warning "Pacman database needs repair"
        if ! sudo pacman -Dk --fix &>/dev/null; then
            print_error "Failed to repair pacman database"
            return 1
        fi
    fi
    print_success "Pacman database verified"
    
    # Check for reflector and update mirrors if installed
    if command -v reflector &>/dev/null; then
        print_status "${SYNC_ICON}" "Updating mirror list..."
        if ! sudo reflector --latest 20 --protocol https --sort rate --save /etc/pacman.d/mirrorlist &>/dev/null; then
            print_warning "Failed to update mirror list"
        else
            print_success "Mirror list updated"
        fi
    fi
    
    # Check for pending systemd failed units
    print_status "${INFO_ICON}" "Checking systemd status..."
    local failed_units=$(systemctl --failed --no-legend | wc -l)
    if [ "$failed_units" -gt 0 ]; then
        print_warning "Found $failed_units failed systemd units"
        systemctl --failed
    else
        print_success "No failed systemd units found"
    fi
    
    return 0
}

# Run checks if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    check_system_health
fi
