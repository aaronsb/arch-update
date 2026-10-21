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
    # A failed check (offline, remote unreachable) says nothing about whether
    # updates exist, so it is reported as unchecked rather than as up to date.
    # It is not a module failure: the other installation is still checked and
    # updated, and the run summary carries the note.
    local system_updates user_updates check_rc unchecked=0
    check_rc=0
    system_updates=$(flatpak remote-ls --updates --system 2>/dev/null) || check_rc=$?
    if (( check_rc != 0 )); then
        system_updates=""
        unchecked=1
        print_warning "Could not check Flatpak system updates (remote-ls exit $check_rc)"
        add_run_note "Flatpak system updates not checked (remote-ls exit $check_rc)"
    fi
    check_rc=0
    user_updates=$(flatpak remote-ls --updates --user 2>/dev/null) || check_rc=$?
    if (( check_rc != 0 )); then
        user_updates=""
        unchecked=1
        print_warning "Could not check Flatpak user updates (remote-ls exit $check_rc)"
        add_run_note "Flatpak user updates not checked (remote-ls exit $check_rc)"
    fi

    if [[ -z "$system_updates" && -z "$user_updates" ]]; then
        (( unchecked )) || print_success "All Flatpak apps up to date"
        return 0
    fi

    print_status "${ICONS[package]}" "Updates available:"
    local n=0 line
    if [[ -n "$system_updates" ]]; then
        echo "system (via sudo):"
        while IFS= read -r line; do
            [[ -n "$line" ]] || continue
            echo "  $line"
            n=$((n + 1))
        done <<< "$system_updates"
    fi
    if [[ -n "$user_updates" ]]; then
        echo "user:"
        while IFS= read -r line; do
            [[ -n "$line" ]] || continue
            echo "  $line"
            n=$((n + 1))
        done <<< "$user_updates"
    fi

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
