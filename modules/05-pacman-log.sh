#!/bin/bash
# Rotate /var/log/pacman.log when it exceeds the size threshold.

MODULE_TYPE="system"
MODULE_NAME="pacman-log"
MODULE_DESCRIPTION="Rotate pacman.log when it exceeds 10MB"
MODULE_DRY_RUN_SAFE="true"

check_supported() {
    [[ -f "/var/log/pacman.log" ]]
}

run_update() {
    print_header "${ICONS[sync]} MAINTAINING PACMAN LOG"

    print_section_box \
        "About Pacman Logs" \
        "Pacman logs track all package operations\nRegular rotation prevents excessive disk usage" \
        "https://wiki.archlinux.org/title/Pacman#Logging"

    local pacman_log="/var/log/pacman.log"
    local max_size_kb=10240
    local log_size_kb
    log_size_kb=$(du -k "$pacman_log" | cut -f1)

    print_status "${ICONS[info]}" "Current size: ${log_size_kb}KB (max ${max_size_kb}KB)"

    if (( log_size_kb <= max_size_kb )); then
        print_success "Log size within limits"
        return 0
    fi

    if [[ -n "$DRY_RUN" ]]; then
        print_status "${ICONS[info]}" "Would rotate $pacman_log"
        return 0
    fi

    print_status "${ICONS[sync]}" "Rotating pacman log..."
    if [[ -f "${pacman_log}.old" ]]; then
        sudo mv "${pacman_log}.old" "${pacman_log}.old.1" \
            || print_warning "Could not archive previous rotation"
    fi
    if ! sudo mv "$pacman_log" "${pacman_log}.old"; then
        print_error "Failed to rotate log"
        return 1
    fi
    sudo touch "$pacman_log"
    print_success "Log rotated to ${pacman_log}.old"
}
