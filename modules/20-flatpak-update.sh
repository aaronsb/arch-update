#!/bin/bash
# Update installed Flatpak applications in the system and user installations.
#
# The system installation is updated as root through sudo. Run as the user,
# flatpak routes system changes through its system-helper, and polkit grants
# that without a password only to a local, active session; over SSH, from a
# timer, or with no auth agent, --noninteractive cannot ask and every deploy
# is refused ("Flatpak system operation Deploy not allowed for user"). The
# user installation is updated as the invoking user: under sudo, --user would
# mean root's installation.

MODULE_TYPE="system"
MODULE_NAME="flatpak-update"
MODULE_DESCRIPTION="Update installed Flatpak apps"
MODULE_REQUIRES="flatpak"
MODULE_DRY_RUN_SAFE="true"

run_update() {
    print_header "${ICONS[package]} UPDATING FLATPAK APPLICATIONS"

    print_section_box \
        "About Flatpak" \
        "Flatpak is a universal package format for Linux applications\nUpdates ensure latest features and security fixes" \
        "https://flatpak.org/"

    print_status "${ICONS[sync]}" "Checking for Flatpak updates..."
    local system_updates user_updates
    system_updates=$(flatpak remote-ls --updates --system 2>/dev/null)
    user_updates=$(flatpak remote-ls --updates --user 2>/dev/null)

    if [[ -z "$system_updates" && -z "$user_updates" ]]; then
        print_success "All Flatpak apps up to date"
        return 0
    fi

    print_status "${ICONS[package]}" "Updates available:"
    local n=0 line
    while IFS= read -r line; do
        [[ -n "$line" ]] || continue
        echo "$line"
        n=$((n + 1))
    done <<< "${system_updates}"$'\n'"${user_updates}"

    if [[ -n "$DRY_RUN" ]]; then
        print_status "${ICONS[info]}" "Would update $n Flatpak app(s)"
        return 0
    fi

    local rc=0
    if [[ -n "$system_updates" ]]; then
        print_status "${ICONS[sync]}" "Updating system Flatpak installation..."
        if ! sudo flatpak update --system --noninteractive; then
            print_error "Failed to update the system Flatpak installation"
            rc=1
        fi
    fi
    if [[ -n "$user_updates" ]]; then
        print_status "${ICONS[sync]}" "Updating user Flatpak installation..."
        if ! flatpak update --user --noninteractive; then
            print_error "Failed to update the user Flatpak installation"
            rc=1
        fi
    fi
    (( rc == 0 )) || return 1
    print_success "Updated $n Flatpak app(s)"
}
