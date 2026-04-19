#!/bin/bash
# Refresh the pacman mirrorlist using reflector.
#
# Reflector probes mirror download rates, which is slow and bandwidth-heavy.
# Mirror quality changes on the order of weeks, not hours, so we throttle
# refreshes to UPDATE_ARCH_MIRRORS_INTERVAL_DAYS (default 30). Set
# UPDATE_ARCH_FORCE_MIRRORS=1 to bypass the throttle for a single run.

MODULE_TYPE="system"
MODULE_NAME="mirrors-update"
MODULE_DESCRIPTION="Refresh the mirrorlist with reflector (throttled)"
MODULE_REQUIRES="reflector"
MODULE_DRY_RUN_SAFE="true"

run_update() {
    print_header "${ICONS[sync]} UPDATING MIRROR LIST"

    print_section_box \
        "About Mirrors" \
        "Mirrors are servers that host Arch Linux packages\nUsing fast, reliable mirrors improves download speed" \
        "https://wiki.archlinux.org/title/Mirrors"

    local mirrorlist="/etc/pacman.d/mirrorlist"
    if [[ ! -f "$mirrorlist" ]]; then
        print_error "Mirror list not found: $mirrorlist"
        return 1
    fi

    # Resolution order: per-run env override → conf file → hard default.
    local interval_days="${UPDATE_ARCH_MIRRORS_INTERVAL_DAYS:-${MIRRORS_INTERVAL_DAYS:-30}}"
    local stamp="$UPDATE_ARCH_STATE_DIR/mirrors-last-run"
    if [[ -z "$UPDATE_ARCH_FORCE_MIRRORS" && "$interval_days" -gt 0 && -f "$stamp" ]]; then
        local last_ts now_ts age_days
        last_ts=$(stat -c %Y "$stamp" 2>/dev/null || echo 0)
        now_ts=$(date +%s)
        age_days=$(( (now_ts - last_ts) / 86400 ))
        if (( age_days < interval_days )); then
            local next_in=$(( interval_days - age_days ))
            print_success "Mirror list is current (refreshed ${age_days}d ago, next refresh in ${next_in}d)"
            print_info_box "Override: UPDATE_ARCH_FORCE_MIRRORS=1 update-arch --run\nInterval: UPDATE_ARCH_MIRRORS_INTERVAL_DAYS=${interval_days}"
            return 0
        fi
    fi

    if [[ -n "$DRY_RUN" ]]; then
        print_status "${ICONS[info]}" "Would refresh $mirrorlist (latest 20, HTTPS, sorted by rate)"
        return 0
    fi

    print_status "${ICONS[sync]}" "Backing up current mirror list..."
    if ! sudo cp "$mirrorlist" "${mirrorlist}.backup"; then
        print_error "Failed to backup mirror list"
        return 1
    fi

    print_status "${ICONS[sync]}" "Finding fastest mirrors..."
    print_info_box "Criteria: latest 20, HTTPS, sorted by download rate"

    if ! sudo reflector --latest 20 --protocol https --sort rate --save "$mirrorlist"; then
        print_error "Failed to update mirror list, restoring backup"
        sudo mv "${mirrorlist}.backup" "$mirrorlist"
        return 1
    fi

    if [[ ! -s "$mirrorlist" ]]; then
        print_error "New mirror list is empty, restoring backup"
        sudo mv "${mirrorlist}.backup" "$mirrorlist"
        return 1
    fi

    mkdir -p "$UPDATE_ARCH_STATE_DIR" 2>/dev/null
    touch "$stamp" 2>/dev/null

    print_success "Mirror list updated"
    print_info_box "Backup saved as: ${mirrorlist}.backup\nNext refresh in ${interval_days} days (override: UPDATE_ARCH_FORCE_MIRRORS=1)"
}
