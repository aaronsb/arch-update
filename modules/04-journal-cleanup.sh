#!/bin/bash
#
# Arch Linux systemd journal cleanup module
# Cleans and maintains systemd journal logs
# Provides educational information about system logging

MODULE_TYPE="system"

# Source utils if not already sourced
if ! command -v print_header &>/dev/null; then
    source "$(dirname "$(dirname "$(readlink -f "$0")")")/utils.sh"
fi

check_supported() {
    # Check if journalctl exists
    if ! command -v journalctl &>/dev/null; then
        return 1
    fi
    return 0
}

run_update() {
    print_header "${TRASH_ICON} MAINTAINING SYSTEM JOURNALS"
    
    # Educational output about system journals
    print_section_box \
        "About System Journals" \
        "The systemd journal records system events and logs\nRegular cleanup prevents excessive disk usage" \
        "https://wiki.archlinux.org/title/Systemd/Journal"
    
    # Check journal directory
    local journal_dir="/var/log/journal"
    if [ ! -d "$journal_dir" ]; then
        print_warning "Journal directory not found: $journal_dir"
        print_info_box "System may be using volatile logging\nSee: https://wiki.archlinux.org/title/Systemd/Journal#Persistent_journals"
        return 0
    fi
    
    # Get initial journal size
    print_status "${SYNC_ICON}" "Checking current journal size..."
    local initial_size=$(du -sh "$journal_dir" 2>/dev/null | cut -f1)
    if [ ! -z "$initial_size" ]; then
        print_status "${INFO_ICON}" "Current journal size: $initial_size"
    fi
    
    # Show retention settings
    print_info_box "Cleanup criteria:\n- Remove entries older than 2 weeks\n- Keep total size under 500MB"
    
    # Clean old system journals
    print_status "${SYNC_ICON}" "Cleaning system journals..."
    if ! sudo journalctl --vacuum-time=2weeks --vacuum-size=500M; then
        print_error "Failed to clean system journals"
        print_info_box "Common issues:\n- Insufficient permissions\n- Journal directory corruption\n- System resource limitations"
        return 1
    fi
    
    # Get final journal size
    local final_size=$(du -sh "$journal_dir" 2>/dev/null | cut -f1)
    if [ ! -z "$final_size" ]; then
        print_success "Journals cleaned successfully"
        print_status "${INFO_ICON}" "Final journal size: $final_size"
    fi
    
    # Show journal statistics
    print_info_box "Journal statistics:\n$(journalctl --disk-usage)\n\nView recent logs: journalctl -n 50"
    
    return 0
}

# If script is run directly, check support and run
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if check_supported; then
        run_update
    else
        echo "journalctl is not available"
        exit 1
    fi
fi
