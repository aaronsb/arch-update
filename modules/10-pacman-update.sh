#!/bin/bash
#
# Core System Package Updates (10-19 priority range)
# Handles official repository package updates via pacman
# Provides educational information about package management

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

# Run the update process
run_update() {
    print_header "${ICONS[package]} UPDATING SYSTEM PACKAGES"
    
    # Educational output about package management
    print_section_box \
        "About Package Management" \
        "pacman is the package manager for Arch Linux\nRegular updates ensure system stability and security" \
        "https://wiki.archlinux.org/title/Pacman"
    
    # Check for updates without modifying the system
    if command -v checkupdates &>/dev/null; then
        print_status "${ICONS[sync]}" "Checking for updates..."
        local updates=$(checkupdates 2>/dev/null)
        if [ $? -ne 0 ]; then
            if [[ -n "$DRY_RUN" ]]; then
                print_warning "Failed to check updates in dry-run mode"
                return 1
            else
                print_warning "Failed to check updates, proceeding with direct update"
            fi
        elif [ -z "$updates" ]; then
            print_success "System is up to date"
            return 0
        else
            print_status "${ICONS[package]}" "Updates available:"
            echo "$updates"
            if [[ -n "$DRY_RUN" ]]; then
                # In dry-run mode, just show what would be updated
                local update_count=$(echo "$updates" | wc -l)
                print_status "${ICONS[info]}" "Would update $update_count package(s)"
                return 0
            fi
        fi
    fi
    
    # Don't proceed with actual updates in dry-run mode
    if [[ -n "$DRY_RUN" ]]; then
        return 0
    fi
    
    # Check if system is busy with package manager
    if [ -f "/var/lib/pacman/db.lck" ]; then
        print_error "Package manager is locked. Another package operation may be in progress."
        print_status "${ICONS[info]}" "If no other package operations are running, remove the lock:"
        print_status "${ICONS[info]}" "sudo rm /var/lib/pacman/db.lck"
        return 1
    fi
    
    # Perform system update with detailed output
    print_status "${ICONS[sync]}" "Running system update..."
    print_status "${ICONS[info]}" "This will synchronize package databases and update all packages"
    
    if ! sudo pacman -Syu --noconfirm; then
        print_error "Failed to update system packages"
        print_info_box "Common issues:\n• Network connectivity problems\n• Mirror synchronization issues\n• Disk space limitations"
        return 1
    fi
    
    # Show post-update tips
    print_success "System packages updated successfully"
    print_info_box "• Some updates may require system restart\n• Check pacman logs: /var/log/pacman.log"
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
