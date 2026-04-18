#!/bin/bash
# REPLACE_MODULE_DESCRIPTION

MODULE_TYPE="user"
MODULE_NAME="REPLACE_MODULE_NAME"
MODULE_DESCRIPTION="REPLACE_MODULE_DESCRIPTION"
MODULE_REQUIRES=""
MODULE_DRY_RUN_SAFE="true"

# User modules should not call sudo. Touch only $HOME / XDG paths.
#
# check_supported() {
#     [[ -f "$HOME/.config/REPLACE_MODULE_NAME/config" ]]
# }

run_update() {
    print_header "${ICONS[user]} REPLACE_HEADER_TEXT"

    if [[ -n "$DRY_RUN" ]]; then
        print_status "${ICONS[info]}" "Would: <describe the user-level action>"
        return 0
    fi

    # Replace with real work.
    print_success "REPLACE_MODULE_NAME completed"
}
