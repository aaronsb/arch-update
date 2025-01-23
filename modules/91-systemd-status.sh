#!/bin/bash
#
# Arch Linux systemd status check module
# Checks for failed systemd units and reports their status
# Provides educational information about system services

MODULE_TYPE="status"

# Source utils if not already sourced
if ! command -v print_header &>/dev/null; then
    source "$(dirname "$(dirname "$(readlink -f "$0")")")/utils.sh"
fi

check_supported() {
    # Check if systemd is the init system
    if ! command -v systemctl &>/dev/null; then
        return 1
    fi
    return 0
}

run_update() {
    print_header "${SERVICE_ICON} CHECKING SYSTEM SERVICES"
    
    # Educational output about systemd
    print_status "${INFO_ICON}" "systemd manages system services and resources"
    print_status "${INFO_ICON}" "Failed units may indicate system problems"
    print_status "${INFO_ICON}" "Learn more: https://wiki.archlinux.org/title/Systemd"
    
    # Check overall system state
    print_status "${SYNC_ICON}" "Checking system state..."
    if ! systemctl is-system-running &>/dev/null; then
        local system_state=$(systemctl is-system-running)
        print_warning "System state: ${system_state}"
    else
        print_success "System is running normally"
    fi
    
    # Check for failed units
    print_status "${SYNC_ICON}" "Checking for failed services..."
    local failed_units=$(systemctl --failed --no-legend | wc -l)
    
    if [ "$failed_units" -gt 0 ]; then
        print_warning "Found $failed_units failed systemd units"
        print_status "${INFO_ICON}" "Failed services:"
        systemctl --failed
        
        # Provide troubleshooting tips
        print_status "${INFO_ICON}" "Troubleshooting tips:"
        print_status "${INFO_ICON}" "- Check unit status: systemctl status unit-name"
        print_status "${INFO_ICON}" "- View logs: journalctl -u unit-name"
        print_status "${INFO_ICON}" "- Restart unit: sudo systemctl restart unit-name"
        return 1
    fi
    
    # Show system statistics
    print_status "${INFO_ICON}" "System statistics:"
    print_status "${INFO_ICON}" "Total units: $(systemctl list-units --all --no-legend | wc -l)"
    print_status "${INFO_ICON}" "Active units: $(systemctl list-units --state=active --no-legend | wc -l)"
    
    print_success "All system services are running normally"
    return 0
}

# If script is run directly, check support and run
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if check_supported; then
        run_update
    else
        echo "systemd is not available"
        exit 1
    fi
fi
