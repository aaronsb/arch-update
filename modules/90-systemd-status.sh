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
    print_section_box \
        "About Systemd" \
        "systemd manages system services and resources\nFailed units may indicate system problems" \
        "https://wiki.archlinux.org/title/Systemd"
    
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
        print_info_box "Troubleshooting Tips:\n- Check unit status: systemctl status unit-name\n- View logs: journalctl -u unit-name\n- Restart unit: sudo systemctl restart unit-name"
        return 1
    fi
    
    # Show system statistics
    print_info_box "System Statistics:\n- Total units: $(systemctl list-units --all --no-legend | wc -l)\n- Active units: $(systemctl list-units --state=active --no-legend | wc -l)"
    
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
