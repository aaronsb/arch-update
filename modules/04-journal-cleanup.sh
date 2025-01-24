#!/bin/bash
#
# Journal Cleanup Module
# Cleans up old systemd journal entries to free disk space
# Provides educational information about journal maintenance

MODULE_TYPE="system"

# Source utils if not already sourced
if ! command -v print_header &>/dev/null; then
    source "$(dirname "$(dirname "$(readlink -f "$0")")")/utils.sh"
fi

# Check if this module can run
check_supported() {
    command -v journalctl &>/dev/null
    return $?
}

# Run the cleanup process
run_update() {
    print_header "${ICONS[trash]} CLEANING SYSTEM JOURNALS"
    
    # Educational output about system journals
    print_section_box \
        "About System Journals" \
        "systemd journals store system logs and events\nRegular cleanup prevents excessive disk usage" \
        "https://wiki.archlinux.org/title/Systemd/Journal"
    
    # Check current journal size and status
    print_status "${ICONS[sync]}" "Analyzing journal status..."
    local current_size=$(journalctl --disk-usage | cut -d' ' -f7-)
    local oldest_entry=$(journalctl --quiet --output=short-precise --reverse --boot=-1 | tail -n 1 | cut -d' ' -f1-3)
    local journal_files=$(journalctl --list-boots | wc -l)
    
    print_info_box "Current journal status:\n• Total size: $current_size\n• Number of boots: $journal_files\n• Oldest entry from: $oldest_entry"
    
    # In dry-run mode, show what would be cleaned
    if [[ -n "$DRY_RUN" ]]; then
        print_status "${ICONS[info]}" "Would clean system journals:"
        print_status "${ICONS[info]}" "• Current journal size: $current_size"
        print_status "${ICONS[info]}" "• Would retain only the last month of logs"
        print_status "${ICONS[info]}" "This would:"
        print_status "${ICONS[info]}" "• Free up disk space used by old logs"
        print_status "${ICONS[info]}" "• Keep recent system logs for troubleshooting"
        print_status "${ICONS[info]}" "• Remove logs older than 30 days"
        
        # Calculate how much would be freed
        local vacuum_size=$(journalctl --vacuum-time=30d --dry-run 2>&1 | grep "Deleted" | cut -d' ' -f4-)
        if [[ -n "$vacuum_size" ]]; then
            print_status "${ICONS[info]}" "• Would free approximately: $vacuum_size"
        fi
        return 0
    fi
    
    # Perform journal cleanup
    print_status "${ICONS[trash]}" "Cleaning old journal entries..."
    if ! sudo journalctl --vacuum-time=30d; then
        print_error "Failed to clean journal entries"
        print_info_box "Common issues:\n• Insufficient permissions\n• Journal files in use\n• File system errors"
        return 1
    fi
    
    # Calculate space saved
    local new_size=$(journalctl --disk-usage | cut -d' ' -f7-)
    print_success "Successfully cleaned journal entries"
    print_info_box "Results:\n• Previous size: $current_size\n• Current size: $new_size\n• Retained last 30 days of logs"
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
