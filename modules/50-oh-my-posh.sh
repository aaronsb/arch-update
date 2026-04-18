#!/bin/bash
# Upgrade the oh-my-posh shell prompt engine.

MODULE_TYPE="user"
MODULE_NAME="oh-my-posh"
MODULE_DESCRIPTION="Upgrade oh-my-posh prompt engine"
MODULE_REQUIRES="oh-my-posh"
MODULE_DRY_RUN_SAFE="true"

run_update() {
    print_header "${ICONS[sync]} UPDATING OH-MY-POSH"

    print_section_box \
        "About Oh My Posh" \
        "oh-my-posh is a custom prompt engine for any shell\nRegular updates ensure latest features and security" \
        "https://ohmyposh.dev/"

    local current_version
    current_version=$(oh-my-posh version 2>/dev/null) \
        || { print_error "Failed to read current version"; return 1; }
    print_info_box "Current version: $current_version"

    if [[ -n "$DRY_RUN" ]]; then
        print_status "${ICONS[info]}" "Would run: oh-my-posh upgrade"
        return 0
    fi

    print_status "${ICONS[sync]}" "Upgrading oh-my-posh..."
    if ! oh-my-posh upgrade; then
        print_error "Failed to update oh-my-posh"
        return 1
    fi

    local new_version
    new_version=$(oh-my-posh version 2>/dev/null)
    if [[ "$current_version" != "$new_version" ]]; then
        print_success "Updated $current_version -> $new_version"
    else
        print_success "Already at latest version ($current_version)"
    fi
}
