#!/bin/bash
#
# Flatpak Updates Module
# Updates installed Flatpak applications
# Provides educational information about Flatpak package management

MODULE_TYPE="system"

# Source utils if not already sourced
if ! command -v print_header &>/dev/null; then
    source "$(dirname "$(dirname "$(readlink -f "$0")")")/utils.sh"
fi

# Check if this module can run
check_supported() {
    command -v flatpak &>/dev/null
    return $?
}

# Run the update process
run_update() {
    print_header "${ICONS[package]} UPDATING FLATPAK APPLICATIONS"
    
    # Educational output about Flatpak
    print_section_box \
        "About Flatpak" \
        "Flatpak is a universal package format for Linux applications\nUpdates ensure latest features and security fixes" \
        "https://flatpak.org/"
    
    # Check for updates
    print_status "${ICONS[sync]}" "Checking for Flatpak updates..."
    
    # Update repository metadata
    if ! flatpak remote-ls --updates &>/dev/null; then
        print_warning "Failed to check for updates, attempting to repair..."
        if ! flatpak repair --user && ! sudo flatpak repair --system; then
            print_error "Failed to repair Flatpak installation"
            return 1
        fi
    fi
    
    # Get list of available updates
    local updates=$(flatpak remote-ls --updates)
    if [ -z "$updates" ]; then
        print_success "All Flatpak applications are up to date"
        return 0
    fi
    
    # Show available updates
    print_status "${ICONS[package]}" "Updates available:"
    echo "$updates"
    
    # Get update details
    local update_count=$(echo "$updates" | wc -l)
    local total_size=$(flatpak remote-ls --updates --columns=download-size | awk '{sum += $1} END {print sum/1024/1024}')
    total_size=$(printf "%.2f" $total_size)
    
    # In dry-run mode, just show what would be updated
    if [[ -n "$DRY_RUN" ]]; then
        print_status "${ICONS[info]}" "Would update $update_count Flatpak application(s)"
        print_status "${ICONS[info]}" "This would:"
        print_status "${ICONS[info]}" "• Download approximately ${total_size}MB of updates"
        print_status "${ICONS[info]}" "• Update application runtimes and dependencies"
        print_status "${ICONS[info]}" "• Clean up old application versions"
        return 0
    fi
    
    # Perform update
    print_status "${ICONS[sync]}" "Updating Flatpak applications..."
    if ! flatpak update --noninteractive; then
        print_error "Failed to update Flatpak applications"
        print_info_box "Common issues:\n• Network connectivity problems\n• Disk space limitations\n• Repository issues"
        return 1
    fi
    
    # Show update results
    print_success "Successfully updated Flatpak applications"
    print_info_box "• Updated $update_count application(s)\n• Downloaded ${total_size}MB of updates\n• Check app-specific release notes for changes"
    return 0
}

# If script is run directly, check support and run
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if check_supported; then
        run_update
    else
        echo "Flatpak is not installed"
        exit 1
    fi
fi
