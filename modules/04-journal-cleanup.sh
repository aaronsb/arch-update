#!/bin/bash
# Vacuum the systemd journal to reclaim disk space.

MODULE_TYPE="system"
MODULE_NAME="journal-cleanup"
MODULE_DESCRIPTION="Vacuum systemd journal entries older than 30 days"
MODULE_REQUIRES="journalctl"
MODULE_DRY_RUN_SAFE="true"

run_update() {
    print_header "${ICONS[trash]} CLEANING SYSTEM JOURNALS"

    print_section_box \
        "About System Journals" \
        "systemd journals store system logs and events\nRegular cleanup prevents excessive disk usage" \
        "https://wiki.archlinux.org/title/Systemd/Journal"

    print_status "${ICONS[sync]}" "Analyzing journal status..."
    local current_size
    current_size=$(journalctl --disk-usage 2>/dev/null | awk -F'take up ' '{print $2}')
    local journal_files
    journal_files=$(journalctl --list-boots 2>/dev/null | wc -l)

    print_info_box "Current: ${current_size:-unknown}\nBoots recorded: $journal_files"

    if [[ -n "$DRY_RUN" ]]; then
        print_status "${ICONS[info]}" "Would vacuum entries older than 30 days"
        return 0
    fi

    print_status "${ICONS[trash]}" "Cleaning old journal entries..."
    if ! sudo journalctl --vacuum-time=30d; then
        print_error "Failed to clean journal entries"
        return 1
    fi

    local new_size
    new_size=$(journalctl --disk-usage 2>/dev/null | awk -F'take up ' '{print $2}')
    print_success "Journal cleaned"
    print_info_box "Previous: ${current_size:-unknown}\nCurrent: ${new_size:-unknown}"
}
