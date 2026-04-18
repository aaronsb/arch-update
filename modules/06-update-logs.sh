#!/bin/bash
# Prune old update-arch run logs beyond the retention limit.

MODULE_TYPE="system"
MODULE_NAME="update-logs"
MODULE_DESCRIPTION="Prune update-arch run logs beyond retention"
MODULE_DRY_RUN_SAFE="true"

check_supported() {
    [[ -d "$UPDATE_ARCH_LOG_DIR" ]]
}

run_update() {
    print_header "${ICONS[sync]} MAINTAINING UPDATE LOGS"

    print_section_box \
        "About Update Logs" \
        "update-arch logs each run under XDG_STATE_HOME.\nOld runs are pruned automatically." \
        "https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html"

    local max_logs="${UPDATE_ARCH_MAX_LOGS:-5}"
    local logs=()
    mapfile -t logs < <(find "$UPDATE_ARCH_LOG_DIR" -maxdepth 1 -name 'update-*.log' | sort -r)

    local total="${#logs[@]}"
    print_status "${ICONS[info]}" "Logs in $UPDATE_ARCH_LOG_DIR: $total (keep $max_logs)"

    if (( total <= max_logs )); then
        print_success "Log count within limits"
        return 0
    fi

    local to_remove=("${logs[@]:$max_logs}")
    if [[ -n "$DRY_RUN" ]]; then
        print_status "${ICONS[info]}" "Would remove ${#to_remove[@]} old log(s)"
        return 0
    fi

    local f
    for f in "${to_remove[@]}"; do
        rm -f "$f" && print_status "${ICONS[trash]}" "Removed $(basename "$f")"
    done
    print_success "Pruned ${#to_remove[@]} old log(s)"
}
