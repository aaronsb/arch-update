#!/bin/bash
# REPLACE_MODULE_DESCRIPTION

MODULE_TYPE="system"
MODULE_NAME="REPLACE_MODULE_NAME"
MODULE_DESCRIPTION="REPLACE_MODULE_DESCRIPTION"
# Space-separated commands that must exist on PATH. Leave empty if you
# override check_supported() below.
MODULE_REQUIRES=""
# Set to "false" if run_update cannot be safely invoked under DRY_RUN.
MODULE_DRY_RUN_SAFE="true"

# Optional: override the default check_supported (which simply verifies that
# every command in MODULE_REQUIRES is on PATH).
# check_supported() {
#     [[ -f "/some/required/file" ]]
# }

run_update() {
    print_header "${ICONS[sync]} REPLACE_HEADER_TEXT"

    if [[ -n "$DRY_RUN" ]]; then
        print_status "${ICONS[info]}" "Would: <describe what this module would do>"
        return 0
    fi

    # Replace with real work. Use sudo only for operations that need it.
    # Example:
    #   if ! sudo some-command; then
    #       print_error "some-command failed"
    #       return 1
    #   fi

    print_success "REPLACE_MODULE_NAME completed"
}
