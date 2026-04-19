#!/bin/bash
# Report on btrfs snapshot state. Read-only, does not create or delete.
#
# update-arch deliberately does NOT manage snapshots — that's the job of
# snapper/timeshift + pacman hooks (snap-pac, etc.). This module just
# surfaces what's already there so a glance confirms the rollback layer
# is healthy.

MODULE_TYPE="status"
MODULE_NAME="btrfs-snapshots"
MODULE_DESCRIPTION="Report btrfs snapshot count and storage headroom"
MODULE_REQUIRES="btrfs findmnt"
MODULE_DRY_RUN_SAFE="true"

check_supported() {
    command -v btrfs   &>/dev/null || return 1
    command -v findmnt &>/dev/null || return 1
    # At least one btrfs mount must exist.
    [[ -n "$(findmnt -t btrfs -no SOURCE 2>/dev/null)" ]]
}

run_update() {
    print_header "${ICONS[disk]} BTRFS SNAPSHOT STATUS"

    print_section_box \
        "About btrfs snapshots" \
        "btrfs snapshots are copy-on-write rollback points.\nupdate-arch reports on them but does not create or manage them —\nthat belongs to snapper / timeshift / pacman hooks." \
        "https://wiki.archlinux.org/title/Snapper"

    # --- btrfs mounts + space headroom ---
    print_status "${ICONS[info]}" "btrfs filesystems:"
    # Column header + rows, aligned.
    findmnt -t btrfs -o TARGET,SOURCE,FSAVAIL,FSUSE% 2>/dev/null \
        | sed 's/^/  /'
    echo

    # --- snapper (if present and readable) ---
    if command -v snapper &>/dev/null; then
        local configs
        configs=$(snapper list-configs 2>/dev/null | awk 'NR>2 && $1!="" {print $1}')
        if [[ -n "$configs" ]]; then
            print_status "${ICONS[package]}" "snapper configs:"
            local cfg count
            for cfg in $configs; do
                count=$(snapper -c "$cfg" list 2>/dev/null | awk 'NR>3' | grep -c .)
                printf '    %-20s %3d snapshot(s)\n' "$cfg" "$count"
            done
        else
            print_status "${ICONS[info]}" "snapper installed but no configs defined"
        fi
        echo
    fi

    # --- timeshift (if present) ---
    if command -v timeshift &>/dev/null; then
        # timeshift --list requires root; only query if we can.
        if timeshift --list &>/dev/null; then
            local ts_count
            ts_count=$(timeshift --list 2>/dev/null | grep -cE '^[0-9]+\s')
            print_status "${ICONS[package]}" "timeshift: $ts_count snapshot(s)"
            echo
        fi
    fi

    # --- common snapshot directories (no tool required) ---
    local dir found=0
    for dir in /.snapshots /snapshots /snapshots/rootfs /snapshots/projects /snapshots/home; do
        [[ -d "$dir" && -r "$dir" ]] || continue
        local n
        n=$(find "$dir" -maxdepth 2 -mindepth 1 -type d 2>/dev/null | wc -l)
        if (( n > 0 )); then
            if (( found == 0 )); then
                print_status "${ICONS[package]}" "snapshot directories:"
                found=1
            fi
            printf '    %-30s %3d entries\n' "$dir" "$n"
        fi
    done

    print_info_box "Create/manage snapshots via snapper, timeshift, or a pacman hook — update-arch only reports state."
}
