#!/bin/bash
#
# Self-update logic for update-arch.
#
# Intentionally separate from update.sh: update.sh runs system maintenance,
# update-self.sh pulls a new copy of the tool and reconciles local edits.
# Invoked either directly or via `update-arch --update` / `--check-update`.
#
# Commands:
#   --check   Query upstream, print version comparison, no changes
#   --run     Download new version, resolve conflicts interactively, apply
#   --yes     With --run, accept-new for every conflict (non-interactive)

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

# shellcheck source=./utils.sh
if [[ -f "$SCRIPT_DIR/utils.sh" ]]; then
    source "$SCRIPT_DIR/utils.sh"
else
    echo "ERROR: cannot find utils.sh next to update-self.sh" >&2
    exit 1
fi

show_help() {
    cat << EOF
${CYAN}${BOLD}update-self.sh${NC}: Self-update for update-arch.

${BOLD}Usage:${NC} ./update-self.sh <command> [--yes]

${BOLD}Commands:${NC}
  ${GREEN}--check${NC}      Check upstream for a newer version (no changes)
  ${GREEN}--run${NC}        Download and apply the update interactively
  ${GREEN}--yes${NC}        With --run, accept upstream for every conflict
  ${GREEN}-h, --help${NC}   Show this help

${BOLD}Conflict prompts:${NC}
  For each locally-modified file that upstream also changed you'll be asked:
    [K]eep local     keep your edit, skip upstream change
    [A]ccept new     overwrite local with upstream
    [D]iff           show unified diff of local vs upstream
    [M]erge          open \$EDITOR on a marked-up merge buffer
    [S]kip           leave file unresolved for this run
    [Q]uit           abort the update

${BOLD}What gets updated:${NC}
  Upstream repo and channel come from update-arch.conf (deployed or
  user-override at \$XDG_CONFIG_HOME/update-arch/update-arch.conf).
EOF
}

have() { command -v "$1" &>/dev/null; }

# ---------------------------------------------------------------------------
# GitHub API (minimal: just tag/commit lookups)
# ---------------------------------------------------------------------------
json_field() {
    local field="$1"
    grep -oE "\"${field}\":[[:space:]]*\"[^\"]+\"" \
        | head -n1 \
        | sed -E "s/.*\"${field}\":[[:space:]]*\"([^\"]+)\".*/\1/"
}

upstream_latest_ref() {
    local api_base="https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}"
    if [[ "$UPDATE_CHANNEL" == "branch" ]]; then
        echo "$UPDATE_BRANCH"
    else
        local tag
        tag=$(curl -fsSL "${api_base}/releases/latest" 2>/dev/null | json_field tag_name)
        echo "${tag:-main}"
    fi
}

upstream_commit() {
    local ref="$1"
    local api_base="https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}"
    curl -fsSL "${api_base}/commits/${ref}" 2>/dev/null | json_field sha
}

# ---------------------------------------------------------------------------
# --check — print comparison, no changes
# ---------------------------------------------------------------------------
do_check() {
    read_upstream_config || { print_error "Upstream config not readable"; return 1; }
    read_install_manifest || { print_error "No INSTALL_MANIFEST — reinstall first"; return 1; }

    have curl || { print_error "curl is required for update checks"; return 1; }

    print_header "${ICONS[sync]} checking for updates"
    print_status "${ICONS[info]}" "Installed: $INSTALLED_VERSION (${INSTALLED_COMMIT:0:7}) ref=$INSTALLED_REF"

    local upstream_ref upstream_sha
    upstream_ref=$(upstream_latest_ref)
    upstream_sha=$(upstream_commit "$upstream_ref")

    if [[ -z "$upstream_ref" || -z "$upstream_sha" ]]; then
        print_error "Failed to query upstream"
        return 1
    fi

    print_status "${ICONS[info]}" "Upstream:  $upstream_ref (${upstream_sha:0:7})"

    if [[ "$upstream_sha" == "$INSTALLED_COMMIT" ]]; then
        print_success "Already up to date"
        return 0
    fi

    print_warning "Update available — run 'update-arch --update' to apply"
    return 0
}

# ---------------------------------------------------------------------------
# Conflict resolution
# ---------------------------------------------------------------------------
resolve_conflict() {
    local rel="$1" local_path="$2" new_path="$3"

    while true; do
        echo
        print_warning "Conflict in $rel"
        echo "  local:    $local_path (modified since install)"
        echo "  upstream: $new_path"
        echo
        echo "  [K]eep local  [A]ccept new  [D]iff  [M]erge  [S]kip  [Q]uit"
        echo -n "  choice: "

        local choice
        read -r choice
        case "$choice" in
            k|K) return 0 ;;                                    # keep local
            a|A) cp "$new_path" "$local_path"; return 0 ;;      # accept new
            d|D) diff -u "$local_path" "$new_path" | ${PAGER:-less} ;;
            m|M)
                local merge_file
                merge_file=$(mktemp --suffix=".${rel##*.}" 2>/dev/null \
                            || mktemp)
                {
                    echo "<<<<<<< LOCAL: $rel"
                    cat "$local_path"
                    echo "======="
                    cat "$new_path"
                    echo ">>>>>>> UPSTREAM"
                } > "$merge_file"

                local editor="${EDITOR:-${VISUAL:-vi}}"
                "$editor" "$merge_file"

                echo "  Use merged result? [y/N] "
                local confirm
                read -r confirm
                if [[ "$confirm" =~ ^[Yy] ]]; then
                    cp "$merge_file" "$local_path"
                    rm -f "$merge_file"
                    return 0
                fi
                rm -f "$merge_file"
                # loop again
                ;;
            s|S) return 2 ;;    # skip (leave as-is, counts as unresolved)
            q|Q) return 3 ;;    # quit the whole update
            *)   echo "  (k/a/d/m/s/q)" ;;
        esac
    done
}

# ---------------------------------------------------------------------------
# --run — fetch, classify, reconcile, apply
# ---------------------------------------------------------------------------
do_run() {
    local assume_yes="${1:-no}"

    read_upstream_config  || { print_error "Upstream config not readable"; return 1; }
    read_install_manifest || { print_error "No INSTALL_MANIFEST — reinstall first"; return 1; }

    have curl || { print_error "curl is required"; return 1; }
    have tar  || { print_error "tar is required";  return 1; }

    local upstream_ref upstream_sha
    upstream_ref=$(upstream_latest_ref)
    upstream_sha=$(upstream_commit "$upstream_ref")

    if [[ -z "$upstream_ref" || -z "$upstream_sha" ]]; then
        print_error "Failed to query upstream"
        return 1
    fi

    print_header "${ICONS[sync]} updating update-arch"
    print_status "${ICONS[info]}" "Installed: $INSTALLED_VERSION (${INSTALLED_COMMIT:0:7})"
    print_status "${ICONS[info]}" "Upstream:  $upstream_ref (${upstream_sha:0:7})"

    if [[ "$upstream_sha" == "$INSTALLED_COMMIT" ]]; then
        print_success "Already up to date"
        return 0
    fi

    # Download
    local tmpdir src
    tmpdir=$(mktemp -d -t update-arch-update.XXXXXX)
    trap 'rm -rf "$tmpdir"' RETURN

    local tarball_url="https://github.com/${REPO_OWNER}/${REPO_NAME}/archive/${upstream_ref}.tar.gz"
    print_status "${ICONS[sync]}" "Fetching $tarball_url"
    if ! curl -fsSL "$tarball_url" | tar -xz -C "$tmpdir"; then
        print_error "Failed to download upstream"
        return 1
    fi
    src=$(find "$tmpdir" -maxdepth 1 -mindepth 1 -type d | head -n1)
    [[ -d "$src" ]] || { print_error "Extracted source not found"; return 1; }

    # Classify + apply
    local hashfile="$UPDATE_ARCH_DATA_DIR/INSTALL_HASHES"
    local installed=0 overwritten=0 new_files=0 kept_local=0 skipped=0

    # Walk upstream files, applying .deployignore from the NEW source so we
    # only consider what would actually be deployed.
    local UPSTREAM_DEPLOYIGNORE=()
    if [[ -f "$src/.deployignore" ]]; then
        local line
        while IFS= read -r line; do
            line="${line%%#*}"
            line="${line#"${line%%[![:space:]]*}"}"
            line="${line%"${line##*[![:space:]]}"}"
            [[ -n "$line" ]] && UPSTREAM_DEPLOYIGNORE+=("$line")
        done < "$src/.deployignore"
    fi
    is_ignored() {
        local path="$1" p
        for p in "${UPSTREAM_DEPLOYIGNORE[@]}"; do
            # shellcheck disable=SC2053
            [[ "$path" == $p ]] && return 0
        done
        return 1
    }

    local rel new_path local_path new_hash base_hash live_hash rc
    while IFS= read -r new_path; do
        rel="${new_path#"$src/"}"
        [[ "$rel" == .git* ]] && continue
        is_ignored "$rel" && continue

        local_path="$UPDATE_ARCH_DATA_DIR/$rel"
        ((installed++))

        # New file (not in installed set)
        if [[ ! -f "$local_path" ]]; then
            mkdir -p "$(dirname "$local_path")"
            cp "$new_path" "$local_path"
            ((new_files++))
            continue
        fi

        new_hash=$(sha256sum "$new_path"  | cut -d' ' -f1)
        live_hash=$(sha256sum "$local_path" | cut -d' ' -f1)
        base_hash=$(grep -E "  ${rel}\$" "$hashfile" 2>/dev/null | awk '{print $1}')

        # No change at all
        [[ "$new_hash" == "$live_hash" ]] && continue

        # Unmodified locally: silent upgrade
        if [[ -n "$base_hash" && "$base_hash" == "$live_hash" ]]; then
            cp "$new_path" "$local_path"
            ((overwritten++))
            continue
        fi

        # Upstream didn't change this file (only we did) — keep local
        if [[ -n "$base_hash" && "$new_hash" == "$base_hash" ]]; then
            ((kept_local++))
            continue
        fi

        # Both changed — conflict
        if [[ "$assume_yes" == "yes" ]]; then
            cp "$new_path" "$local_path"
            ((overwritten++))
            continue
        fi

        resolve_conflict "$rel" "$local_path" "$new_path"
        rc=$?
        case "$rc" in
            0) ((overwritten++)) ;;
            2) ((skipped++)) ;;
            3) print_warning "Update aborted by user"; return 1 ;;
        esac
    done < <(find "$src" -type f | sort)

    # Refresh manifest + hashes from the new layout
    (
        export UPDATE_ARCH_INSTALL_FROM="tarball"
        export UPDATE_ARCH_INSTALL_REF="$upstream_ref"
        export UPDATE_ARCH_INSTALL_COMMIT="$upstream_sha"
        # Parse version from update.sh in the new source
        local new_ver
        new_ver=$(grep '^VERSION=' "$src/update.sh" | sed -E 's/VERSION="([^"]*)".*/\1/')
        export UPDATE_ARCH_INSTALL_VERSION="$new_ver"

        # Run the relevant bits of deploy.sh to rewrite manifest + hashes.
        cd "$src" && source ./deploy.sh >/dev/null 2>&1 || true
        resolve_install_provenance
        write_install_hashes
        write_install_manifest
    )

    echo
    print_success "Update complete"
    print_status "${ICONS[info]}" "Files:        $installed scanned"
    print_status "${ICONS[info]}" "Added:        $new_files"
    print_status "${ICONS[info]}" "Overwritten:  $overwritten"
    print_status "${ICONS[info]}" "Kept local:   $kept_local"
    (( skipped > 0 )) && print_warning "Skipped (unresolved): $skipped"
}

main() {
    local command="" assume_yes="no"
    while (( $# > 0 )); do
        case "$1" in
            -h|--help) show_help; exit 0 ;;
            --check)   command="check"; shift ;;
            --run)     command="run";   shift ;;
            --yes|-y)  assume_yes="yes"; shift ;;
            *)         print_error "Unknown option: $1"; show_help; exit 1 ;;
        esac
    done

    [[ -z "$command" ]] && { show_help; exit 0; }

    case "$command" in
        check) do_check ;;
        run)   do_run "$assume_yes" ;;
    esac
}

main "$@"
