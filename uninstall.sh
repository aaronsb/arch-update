#!/bin/bash
#
# update-arch uninstaller.
#
# Kept out of deploy.sh so the install and removal paths don't share state.
# Run either from the deployed copy:
#   ~/.local/share/update-arch/uninstall.sh
# or from a local working tree:
#   ./uninstall.sh
#
# Behaviour:
#   1. Explicit friction prompt ("this will remove…")
#   2. Compares live deployed files against INSTALL_HASHES (written by
#      deploy.sh at install time) to detect local edits.
#   3. If anything was modified, the unchanged files are removed and the
#      modified ones are left in place with a list — the user can then
#      decide whether to keep the edits or rm them manually.
#   4. User data (logs under $XDG_STATE_HOME, backups under $XDG_CACHE_HOME)
#      is always preserved.

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

# Load shared helpers (colors, icons, XDG paths). Try adjacent utils.sh first
# (deployed layout), then the development checkout.
if [[ -f "$SCRIPT_DIR/utils.sh" ]]; then
    # shellcheck source=./utils.sh
    source "$SCRIPT_DIR/utils.sh"
else
    echo "ERROR: cannot find utils.sh next to uninstall.sh" >&2
    exit 1
fi

SCRIPT_NAME="update-arch"
HASHFILE="$UPDATE_ARCH_DATA_DIR/INSTALL_HASHES"
MANIFEST="$UPDATE_ARCH_DATA_DIR/INSTALL_MANIFEST"
LINK="$UPDATE_ARCH_BIN_DIR/$SCRIPT_NAME"

show_help() {
    cat << EOF
${CYAN}${BOLD}uninstall.sh${NC}: Remove update-arch from this user account.

${BOLD}Usage:${NC} ./uninstall.sh <command>

${BOLD}Commands:${NC}
  ${GREEN}--run${NC}       Perform uninstallation (prompts for confirmation)
  ${GREEN}--yes${NC}       With --run, skip the confirmation prompt
  ${GREEN}-h, --help${NC}  Show this help

${BOLD}Preserved across uninstall:${NC}
  $UPDATE_ARCH_STATE_DIR  (run logs)
  $UPDATE_ARCH_CACHE_DIR  (cached backups)
EOF
}

classify_files() {
    CLEAN_FILES=()
    DIRTY_FILES=()
    MISSING_FILES=()

    if [[ ! -r "$HASHFILE" ]]; then
        # No recorded hashes (old install). Treat everything as clean.
        local f
        while IFS= read -r f; do
            CLEAN_FILES+=("${f#"$UPDATE_ARCH_DATA_DIR/"}")
        done < <(find "$UPDATE_ARCH_DATA_DIR" -type f 2>/dev/null | sort)
        return 0
    fi

    local line expected rel live_hash
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        expected="${line%% *}"
        rel="${line#* }"
        rel="${rel# }"
        rel="${rel#./}"
        if [[ ! -f "$UPDATE_ARCH_DATA_DIR/$rel" ]]; then
            MISSING_FILES+=("$rel")
            continue
        fi
        live_hash=$(sha256sum "$UPDATE_ARCH_DATA_DIR/$rel" | cut -d' ' -f1)
        if [[ "$expected" == "$live_hash" ]]; then
            CLEAN_FILES+=("$rel")
        else
            DIRTY_FILES+=("$rel")
        fi
    done < "$HASHFILE"
}

remove_deployed() {
    # Remove each clean file, then prune empty dirs.
    local rel
    for rel in "${CLEAN_FILES[@]}"; do
        rm -f "$UPDATE_ARCH_DATA_DIR/$rel"
    done
    # Manifest + hashes were excluded from the hash record — remove them too
    # when the install is fully clean. If it's not, leave them so the user
    # can re-run uninstall after reviewing.
    if (( ${#DIRTY_FILES[@]} == 0 )); then
        rm -f "$MANIFEST" "$HASHFILE"
        # Prune empty directories from deepest to shallowest.
        find "$UPDATE_ARCH_DATA_DIR" -type d -empty -delete 2>/dev/null
    else
        # Prune empty subdirectories (e.g., templates/status if all its files
        # were clean and removed) but keep the data dir itself.
        find "$UPDATE_ARCH_DATA_DIR" -mindepth 1 -type d -empty -delete 2>/dev/null
    fi
}

perform_uninstall() {
    if [[ ! -d "$UPDATE_ARCH_DATA_DIR" && ! -L "$LINK" ]]; then
        print_warning "update-arch does not appear to be installed."
        return 0
    fi

    classify_files

    # Symlink goes regardless.
    [[ -L "$LINK" ]] && { rm "$LINK"; print_success "Removed symlink: $LINK"; }

    if [[ -d "$UPDATE_ARCH_DATA_DIR" ]]; then
        remove_deployed
        if (( ${#DIRTY_FILES[@]} == 0 )); then
            rmdir "$UPDATE_ARCH_DATA_DIR" 2>/dev/null
            print_success "Removed $UPDATE_ARCH_DATA_DIR"
        else
            print_warning "Removed unmodified files. Modified files were kept:"
            local rel
            for rel in "${DIRTY_FILES[@]}"; do
                echo "    $UPDATE_ARCH_DATA_DIR/$rel"
            done
            echo
            echo "Review them and remove manually when ready:"
            echo "    rm -rf $UPDATE_ARCH_DATA_DIR"
        fi
    fi

    if [[ -f "$UPDATE_ARCH_TERMINAL_CONF" ]]; then
        rm -f "$UPDATE_ARCH_TERMINAL_CONF"
        rmdir "$UPDATE_ARCH_CONFIG_DIR" 2>/dev/null || true
        print_success "Removed terminal configuration"
    fi

    echo
    echo "Preserved (contain user data — remove manually if desired):"
    echo "    $UPDATE_ARCH_STATE_DIR  (run logs)"
    echo "    $UPDATE_ARCH_CACHE_DIR  (cached backups)"
    print_success "Uninstallation complete"
}

confirm() {
    cat << EOF

${YELLOW}${BOLD}This will remove the update-arch scripts from your user account.${NC}

Files to be removed or reviewed:
    $UPDATE_ARCH_DATA_DIR          (scripts, modules, manifest)
    $UPDATE_ARCH_TERMINAL_CONF     (terminal preferences)
    $LINK         (command symlink)

Preserved:
    $UPDATE_ARCH_STATE_DIR         (run logs)
    $UPDATE_ARCH_CACHE_DIR         (cached backups)

Locally-modified files will be kept in place with a list so you can review
them before removing anything yourself.

Continue? [y/N] ${NC}
EOF
    local reply
    read -r reply < /dev/tty
    [[ "$reply" =~ ^[Yy] ]]
}

main() {
    local command="" assume_yes="no"
    while (( $# > 0 )); do
        case "$1" in
            -h|--help) show_help; exit 0 ;;
            --run)     command="run"; shift ;;
            --yes|-y)  assume_yes="yes"; shift ;;
            *)         print_error "Unknown option: $1"; show_help; exit 1 ;;
        esac
    done

    if [[ -z "$command" ]]; then
        show_help
        exit 0
    fi

    if [[ "$assume_yes" != "yes" ]]; then
        confirm || { echo "Aborted."; exit 1; }
    fi

    perform_uninstall
}

main "$@"
