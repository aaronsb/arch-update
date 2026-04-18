#!/bin/bash
# Display system information via fastfetch after updates complete.

MODULE_TYPE="status"
MODULE_NAME="fastfetch"
MODULE_DESCRIPTION="Display system info via fastfetch"
MODULE_REQUIRES="fastfetch"
MODULE_DRY_RUN_SAFE="true"

run_update() {
    print_header "${ICONS[info]} SYSTEM INFORMATION"

    if ! fastfetch; then
        print_error "Failed to display system information"
        return 1
    fi
}
