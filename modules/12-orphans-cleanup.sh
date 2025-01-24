#!/bin/bash
#
# Orphaned Package Cleanup (10-19 priority range)
# Removes packages that are no longer required by any other package
# Provides educational information about package maintenance

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
    print_header "${ICONS[trash]} CLEANING ORPHANED PACKAGES"
    
    # Educational output about orphaned packages
    print_section_box \
        "About Orphaned Packages" \
        "Orphaned packages are those no longer required as dependencies\nRemoving them helps maintain a clean system" \
        "https://wiki.archlinux.org/title/Pacman/Tips_and_tricks#Removing_unused_packages"
    
    # Check for orphaned packages
    print_status "${ICONS[sync]}" "Checking for orphaned packages..."
    local orphans=$(pacman -Qtdq)
    
    if [ $? -ne 0 ]; then
        print_error "Failed to check for orphaned packages"
        return 1
    fi
    
    if [ -z "$orphans" ]; then
        print_success "No orphaned packages found"
        return 0
    fi
    
    # Get detailed information about orphaned packages
    print_status "${ICONS[package]}" "Found orphaned packages:"
    local orphan_details=$(pacman -Qti $(echo "$orphans"))
    echo "$orphan_details"
    
    # Calculate total size of orphaned packages
    local total_size=0
    while IFS= read -r pkg; do
        local size=$(pacman -Qi "$pkg" | grep "Installed Size" | cut -d: -f2 | tr -d ' ')
        if [[ $size =~ ^[0-9]+\.[0-9]+.MiB$ ]]; then
            size=$(echo "$size" | cut -d. -f1)
            total_size=$((total_size + size))
        elif [[ $size =~ ^[0-9]+\.[0-9]+.KiB$ ]]; then
            size=$(echo "$size" | cut -d. -f1)
            total_size=$((total_size + (size / 1024)))
        fi
    done <<< "$orphans"
    
    # In dry-run mode, just show what would be removed
    if [[ -n "$DRY_RUN" ]]; then
        local orphan_count=$(echo "$orphans" | wc -l)
        print_status "${ICONS[info]}" "Would remove $orphan_count orphaned package(s)"
        print_status "${ICONS[info]}" "This would:"
        print_status "${ICONS[info]}" "• Free approximately ${total_size}MB of disk space"
        print_status "${ICONS[info]}" "• Remove packages no longer needed as dependencies"
        print_status "${ICONS[info]}" "• Clean up package database entries"
        return 0
    fi
    
    # Remove orphaned packages
    print_status "${ICONS[trash]}" "Removing orphaned packages..."
    if ! sudo pacman -Rns $(echo "$orphans") --noconfirm; then
        print_error "Failed to remove orphaned packages"
        print_info_box "Common issues:\n• Package required by another package\n• File conflicts\n• Insufficient permissions"
        return 1
    fi
    
    # Show cleanup results
    print_success "Successfully removed orphaned packages"
    print_info_box "• Freed approximately ${total_size}MB of disk space\n• System is now cleaner and more maintainable"
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
