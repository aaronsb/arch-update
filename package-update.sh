#!/bin/bash

source ./utils.sh

# Set up error handling
set_error_handlers

update_packages() {
    print_header "${PACKAGE_ICON} UPDATING SYSTEM PACKAGES"
    
    # Determine package manager
    local pkg_manager=$(check_aur_helper)
    print_status "${INFO_ICON}" "Using package manager: $pkg_manager"
    
    # Check for updates without modifying the system
    if command -v checkupdates &>/dev/null; then
        print_status "${SYNC_ICON}" "Checking for updates..."
        local updates=$(checkupdates 2>/dev/null)
        if [ $? -ne 0 ]; then
            print_warning "Failed to check updates, proceeding with direct update"
        elif [ -z "$updates" ]; then
            print_success "System is up to date"
            return 0
        else
            print_status "${PACKAGE_ICON}" "Updates available:"
            echo "$updates"
        fi
    fi
    
    # Perform system update
    print_status "${SYNC_ICON}" "Running system update..."
    if [ "$pkg_manager" = "pacman" ]; then
        if ! sudo pacman -Syu --noconfirm; then
            print_error "Failed to update system packages"
            return 1
        fi
    else
        if ! $pkg_manager -Syu --noconfirm; then
            print_warning "AUR helper failed, falling back to pacman"
            if ! sudo pacman -Syu --noconfirm; then
                print_error "Failed to update system packages"
                return 1
            fi
        fi
    fi
    print_success "System packages updated successfully"
    
    # Handle orphaned packages
    print_header "${TRASH_ICON} CHECKING FOR ORPHANED PACKAGES"
    local orphans=$(pacman -Qdtq)
    if [ $? -eq 0 ] && [ ! -z "$orphans" ]; then
        print_warning "Found orphaned packages. Removing..."
        if ! sudo pacman -Rns $orphans --noconfirm; then
            print_error "Failed to remove orphaned packages"
            return 1
        fi
        print_success "Orphaned packages removed"
    else
        print_success "No orphaned packages found"
    fi
    
    # Clean package cache
    print_header "${TRASH_ICON} CLEANING PACKAGE CACHE"
    if command -v paccache &>/dev/null; then
        print_status "${SYNC_ICON}" "Cleaning package cache (keeping last 3 versions)..."
        if ! sudo paccache -r; then
            print_warning "Failed to clean package cache"
        else
            print_success "Package cache cleaned"
        fi
    fi
    
    return 0
}

# Run updates if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    update_packages
fi
