#!/bin/bash
# Rotate /var/log/pacman.log when it exceeds the size threshold.
# Rotations are datestamped (pacman.log.YYYYMMDD-HHMMSS), so every rotation
# is preserved as its own file. Keeps the last N rotations and prunes older
# ones — bounded history, no silent overwrites.

MODULE_TYPE="system"
MODULE_NAME="pacman-log"
MODULE_DESCRIPTION="Rotate pacman.log (datestamped, bounded history)"
MODULE_DRY_RUN_SAFE="true"

# Overridable via environment; defaults are sensible for most systems.
: "${PACMAN_LOG_MAX_SIZE_KB:=10240}"   # 10MB
: "${PACMAN_LOG_KEEP_ROTATIONS:=10}"

check_supported() {
    [[ -f "/var/log/pacman.log" ]]
}

run_update() {
    print_header "${ICONS[sync]} MAINTAINING PACMAN LOG"

    print_section_box \
        "About Pacman Logs" \
        "pacman.log records every package operation. Rotating it keeps\nit manageable while preserving history as dated archive files." \
        "https://wiki.archlinux.org/title/Pacman#Logging"

    local pacman_log="/var/log/pacman.log"
    local log_size_kb
    log_size_kb=$(du -k "$pacman_log" | cut -f1)

    print_status "${ICONS[info]}" "Current size: ${log_size_kb}KB (max ${PACMAN_LOG_MAX_SIZE_KB}KB)"
    print_status "${ICONS[info]}" "Keeping last ${PACMAN_LOG_KEEP_ROTATIONS} rotations"

    if (( log_size_kb <= PACMAN_LOG_MAX_SIZE_KB )); then
        print_success "Log size within limits"
        return 0
    fi

    local ts rotated
    ts=$(date +%Y%m%d-%H%M%S)
    rotated="${pacman_log}.${ts}"

    if [[ -n "$DRY_RUN" ]]; then
        print_status "${ICONS[info]}" "Would rotate: $pacman_log -> $rotated"
        print_status "${ICONS[info]}" "Would prune rotations older than the ${PACMAN_LOG_KEEP_ROTATIONS}th newest"
        return 0
    fi

    print_status "${ICONS[sync]}" "Rotating to $rotated..."
    if ! sudo mv "$pacman_log" "$rotated"; then
        print_error "Failed to rotate log"
        return 1
    fi
    sudo touch "$pacman_log"

    # Prune old rotations beyond the retention limit. Sorted newest-first by
    # filename (timestamps sort lexicographically), then drop the tail.
    local old=()
    mapfile -t old < <(find /var/log -maxdepth 1 -name 'pacman.log.[0-9]*' 2>/dev/null | sort -r)

    local pruned=0 i
    for (( i=PACMAN_LOG_KEEP_ROTATIONS; i<${#old[@]}; i++ )); do
        if sudo rm -f "${old[$i]}"; then
            ((pruned++))
        fi
    done

    print_success "Log rotated to ${rotated##*/}"
    (( pruned > 0 )) && print_status "${ICONS[trash]}" "Pruned $pruned older rotation(s)"
    print_info_box "• View history: ls -lt /var/log/pacman.log.*\n• Search archive: grep 'upgraded' /var/log/pacman.log.*"
}
