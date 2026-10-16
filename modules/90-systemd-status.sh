#!/bin/bash
# Report systemd overall state and any failed units.

MODULE_TYPE="status"
MODULE_NAME="systemd-status"
MODULE_DESCRIPTION="Report systemd state and failed units"
MODULE_REQUIRES="systemctl"
MODULE_DRY_RUN_SAFE="true"

run_update() {
    print_header "${ICONS[info]} CHECKING SYSTEM SERVICES"

    print_section_box \
        "About Systemd" \
        "systemd manages system services and resources\nFailed units may indicate system problems" \
        "https://wiki.archlinux.org/title/Systemd"

    print_status "${ICONS[sync]}" "Checking system state..."
    if systemctl is-system-running &>/dev/null; then
        print_success "System is running normally"
    else
        local state
        state=$(systemctl is-system-running)
        print_warning "System state: $state"
    fi

    print_status "${ICONS[sync]}" "Checking for failed services..."
    local failed
    failed=$(systemctl --failed --no-legend | wc -l)

    # Failed units are a finding about the system, not a failure of this
    # module, so they go to the run summary rather than the exit status.
    if (( failed > 0 )); then
        print_warning "$failed failed systemd unit(s)"
        systemctl --failed
        print_info_box "Investigate: systemctl status <unit> | journalctl -u <unit>"
        add_run_note "$failed failed systemd unit(s) — see systemctl --failed"
        return 0
    fi

    print_success "All system services running normally"
}
