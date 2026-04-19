#!/bin/bash
#
# Installer for update-arch. User-scope, XDG-compliant.

# shellcheck source=./utils.sh
if [[ -f "./utils.sh" ]]; then
    source ./utils.sh
else
    # Minimal fallback when invoked from somewhere without utils.sh alongside.
    RED="$(tput setaf 1)"; GREEN="$(tput setaf 2)"; YELLOW="$(tput setaf 3)"
    BLUE="$(tput setaf 4)"; NC="$(tput sgr0)"; BOLD="$(tput bold)"
    print_error()   { echo "${RED}ERROR: $1${NC}" >&2; }
    print_success() { echo "${GREEN}SUCCESS: $1${NC}"; }
    print_warning() { echo "${YELLOW}WARNING: $1${NC}"; }
    print_header()  { echo -e "\n${BLUE}${BOLD}=== $1 ===${NC}\n"; }
    print_info_box(){ echo "${BLUE}> $1${NC}"; }
    UPDATE_ARCH_DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/update-arch"
    UPDATE_ARCH_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/update-arch"
    UPDATE_ARCH_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/update-arch"
    UPDATE_ARCH_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/update-arch"
    UPDATE_ARCH_BIN_DIR="$HOME/.local/bin"
    UPDATE_ARCH_UPSTREAM_CONF_NAME="update-arch.conf"
    UPDATE_ARCH_UPSTREAM_CONF_USER="$UPDATE_ARCH_CONFIG_DIR/$UPDATE_ARCH_UPSTREAM_CONF_NAME"
    upsert_conf_value() {
        local file="$1" key="$2" value="$3"
        mkdir -p "$(dirname "$file")"
        if [[ -f "$file" ]] && grep -q "^${key}=" "$file"; then
            sed -i "s|^${key}=.*|${key}=\"${value}\"|" "$file"
        else
            echo "${key}=\"${value}\"" >> "$file"
        fi
    }
fi

SCRIPT_NAME="update-arch"
REQUIRED_DEPS="bash sudo pacman systemctl"

# Install provenance is passed in by the bootstrap (install.sh) or --update
# via env vars; deploy.sh falls back to reading from git if available.
: "${UPDATE_ARCH_INSTALL_FROM:=}"     # "git" | "tarball"
: "${UPDATE_ARCH_INSTALL_REF:=}"      # tag or branch name
: "${UPDATE_ARCH_INSTALL_COMMIT:=}"   # full sha
: "${UPDATE_ARCH_INSTALL_VERSION:=}"  # semver

get_version() {
    local line
    line=$(grep "^VERSION=" "update.sh")
    echo "${line#VERSION=}" | tr -d '"'
}

# Resolve install provenance. Prefers explicit env vars (set by install.sh or
# --update). Falls back to `git` when running from a working tree.
resolve_install_provenance() {
    RESOLVED_FROM="${UPDATE_ARCH_INSTALL_FROM:-}"
    RESOLVED_REF="${UPDATE_ARCH_INSTALL_REF:-}"
    RESOLVED_COMMIT="${UPDATE_ARCH_INSTALL_COMMIT:-}"
    RESOLVED_VERSION="${UPDATE_ARCH_INSTALL_VERSION:-$(get_version)}"

    if [[ -z "$RESOLVED_FROM" ]] && git rev-parse --is-inside-work-tree &>/dev/null; then
        RESOLVED_FROM="git"
        [[ -z "$RESOLVED_COMMIT" ]] && RESOLVED_COMMIT=$(git rev-parse HEAD 2>/dev/null)
        [[ -z "$RESOLVED_REF"    ]] && RESOLVED_REF=$(git describe --tags --exact-match 2>/dev/null \
                                                   || git rev-parse --abbrev-ref HEAD 2>/dev/null)
    fi
    RESOLVED_FROM="${RESOLVED_FROM:-unknown}"
}

write_install_manifest() {
    local manifest="$UPDATE_ARCH_DATA_DIR/INSTALL_MANIFEST"
    local now
    now=$(date -u +'%Y-%m-%dT%H:%M:%SZ')

    cat > "$manifest" << EOF
# Written by deploy.sh on install/update. Source of truth for the version
# banner and the --update flow.
INSTALLED_VERSION="$RESOLVED_VERSION"
INSTALLED_COMMIT="$RESOLVED_COMMIT"
INSTALLED_AT="$now"
INSTALLED_FROM="$RESOLVED_FROM"
INSTALLED_REF="$RESOLVED_REF"
EOF
}

# Record sha256 of every deployed file so uninstall can detect local edits.
write_install_hashes() {
    local hashfile="$UPDATE_ARCH_DATA_DIR/INSTALL_HASHES"
    (
        cd "$UPDATE_ARCH_DATA_DIR" || exit 1
        # Exclude the manifest/hashes files themselves (they're written after).
        find . -type f \
            -not -name INSTALL_MANIFEST \
            -not -name INSTALL_HASHES \
            -printf '%P\n' \
            | sort \
            | xargs -d '\n' sha256sum 2>/dev/null
    ) > "$hashfile"
}

check_dependencies() {
    local missing=()
    for dep in $REQUIRED_DEPS; do
        command -v "$dep" &>/dev/null || missing+=("$dep")
    done
    if (( ${#missing[@]} > 0 )); then
        print_error "Missing required dependencies: ${missing[*]}"
        return 1
    fi
}

DEPLOYIGNORE_FILE=".deployignore"

# Read .deployignore into an array of patterns. Blank lines and # comments skipped.
load_deployignore() {
    DEPLOYIGNORE_PATTERNS=()
    [[ -f "$DEPLOYIGNORE_FILE" ]] || return 0
    local line
    while IFS= read -r line; do
        line="${line%%#*}"
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"
        [[ -n "$line" ]] && DEPLOYIGNORE_PATTERNS+=("$line")
    done < "$DEPLOYIGNORE_FILE"
}

is_deployignored() {
    local path="$1" pattern
    for pattern in "${DEPLOYIGNORE_PATTERNS[@]}"; do
        # shellcheck disable=SC2053
        [[ "$path" == $pattern ]] && return 0
    done
    return 1
}

get_source_files() {
    load_deployignore
    local f
    if git rev-parse --is-inside-work-tree &>/dev/null; then
        # Local clone: authoritative list comes from git.
        while IFS= read -r f; do
            [[ "$f" == .git* ]] && continue
            is_deployignored "$f" && continue
            echo "$f"
        done < <(git ls-files)
    else
        # Tarball extract (install.sh, --update): walk the filesystem.
        while IFS= read -r f; do
            f="${f#./}"
            [[ "$f" == .git* ]] && continue
            is_deployignored "$f" && continue
            echo "$f"
        done < <(find . -type f -not -path './.git/*' | sort)
    fi
}

# Legacy alias — several other helpers still call this name.
get_tracked_files() { get_source_files; }

file_hash() {
    [[ -f "$1" ]] && sha256sum "$1" | cut -d' ' -f1 || echo "missing"
}

list_modified_files() {
    local f deployed
    while IFS= read -r f; do
        deployed="$UPDATE_ARCH_DATA_DIR/$f"
        [[ -f "$deployed" ]] || continue
        if [[ "$(file_hash "$f")" != "$(file_hash "$deployed")" ]]; then
            echo "$f"
        fi
    done < <(get_tracked_files)
}

# Files deploy.sh writes at install time. Not in git, not user extras.
INSTALLER_MANAGED=(INSTALL_MANIFEST INSTALL_HASHES)

is_installer_managed() {
    local path="$1" m
    for m in "${INSTALLER_MANAGED[@]}"; do
        [[ "$path" == "$m" ]] && return 0
    done
    return 1
}

list_extra_files() {
    local tracked
    tracked=$(get_tracked_files)
    [[ -d "$UPDATE_ARCH_DATA_DIR" ]] || return 0

    local deployed rel
    while IFS= read -r deployed; do
        rel="${deployed#"$UPDATE_ARCH_DATA_DIR/"}"
        is_installer_managed "$rel" && continue
        # grep -Fxq: exact whole-line match, so "utils.sh" doesn't match "utils.sh.bak"
        grep -Fxq "$rel" <<< "$tracked" || echo "$rel"
    done < <(find "$UPDATE_ARCH_DATA_DIR" -type f 2>/dev/null)
}

handle_extra_files() {
    local extras="$1" reply
    echo
    print_warning "Files present in $UPDATE_ARCH_DATA_DIR but not tracked in git:"
    sed 's/^/  /' <<< "$extras"
    echo
    echo "Remove these extra files? [y/N]"
    read -r reply < /dev/tty
    case "$reply" in
        [Yy]*)
            while IFS= read -r rel; do
                [[ -z "$rel" ]] && continue
                rm -f "$UPDATE_ARCH_DATA_DIR/$rel" && echo "Removed: $rel"
            done <<< "$extras"
            ;;
        *) print_warning "Keeping extra files — they may cause unexpected behavior" ;;
    esac
}

check_existing_deployment() {
    [[ -d "$UPDATE_ARCH_DATA_DIR" ]] || return 1

    local modified
    modified=$(list_modified_files)

    if [[ -n "$modified" ]]; then
        print_warning "The following deployed files have been modified:"
        sed 's/^/  /' <<< "$modified"
        echo
        print_warning "Proceeding will overwrite these modifications"
        echo "Press Enter to continue or Ctrl+C to abort"
        read -r < /dev/tty
    fi
    return 0
}

create_directories() {
    mkdir -p \
        "$UPDATE_ARCH_DATA_DIR/modules" \
        "$UPDATE_ARCH_CONFIG_DIR" \
        "$UPDATE_ARCH_STATE_DIR/logs" \
        "$UPDATE_ARCH_CACHE_DIR" \
        "$UPDATE_ARCH_BIN_DIR" \
        || { print_error "Failed to create required directories"; return 1; }
}

configure_terminal_preferences() {
    local detected reply preferred conf="$UPDATE_ARCH_UPSTREAM_CONF_USER"

    detected=$(detect_terminal)

    upsert_conf_value "$conf" DETECTED_TERMINAL "$detected"
    upsert_conf_value "$conf" LAST_DETECTION_TIME "$(date +%s)"
    grep -q '^PREFERRED_TERMINAL=' "$conf" 2>/dev/null \
        || upsert_conf_value "$conf" PREFERRED_TERMINAL "auto"
    grep -q '^FORCE_ASCII_ICONS=' "$conf" 2>/dev/null \
        || upsert_conf_value "$conf" FORCE_ASCII_ICONS "false"

    print_success "Terminal detected: $detected"
    echo
    echo "Customize terminal preferences? [y/N]"
    read -r reply < /dev/tty
    case "$reply" in
        [Yy]*)
            echo "Force ASCII icons (no Nerd Font)? [y/N]"
            read -r reply < /dev/tty
            [[ "$reply" =~ ^[Yy] ]] && upsert_conf_value "$conf" FORCE_ASCII_ICONS "true"

            echo "Override detected terminal? [y/N]"
            read -r reply < /dev/tty
            if [[ "$reply" =~ ^[Yy] ]]; then
                echo "Preferred terminal (vscode, kitty, auto, ...):"
                read -r preferred < /dev/tty
                upsert_conf_value "$conf" PREFERRED_TERMINAL "$preferred"
            fi
            ;;
    esac

    print_success "Terminal preferences configured"
    print_info_box "Stored in: $conf\nReconfigure anytime: update-arch --configure-terminal"
}

copy_files() {
    local tracked
    tracked=$(get_tracked_files) || return 1

    local f target_dir target copied=0
    while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        [[ ! -f "$f" ]] && continue

        if [[ "$f" == modules/* ]]; then
            target_dir="$UPDATE_ARCH_DATA_DIR/modules"
            target="$UPDATE_ARCH_DATA_DIR/$f"
        else
            target_dir="$UPDATE_ARCH_DATA_DIR"
            target="$UPDATE_ARCH_DATA_DIR/$f"
        fi

        mkdir -p "$(dirname "$target")"

        if cp "$f" "$target"; then
            ((copied++))
            if [[ "$f" == *.sh && "$f" != *.sh.disabled ]]; then
                chmod +x "$target" || { print_error "chmod +x failed on $f"; return 1; }
            fi
        else
            print_error "Failed to copy $f"
            return 1
        fi
    done <<< "$tracked"

    (( copied == 0 )) && { print_error "No files copied"; return 1; }
    print_success "Copied $copied files"
}

create_symlink() {
    local link="$UPDATE_ARCH_BIN_DIR/$SCRIPT_NAME"

    if [[ -L "$link" ]]; then
        rm "$link"
    elif [[ -e "$link" ]]; then
        print_error "$link exists but is not a symlink"
        return 1
    fi

    ln -s "$UPDATE_ARCH_DATA_DIR/update.sh" "$link" \
        || { print_error "Failed to create symlink"; return 1; }
}

ensure_path() {
    [[ ":$PATH:" == *":$UPDATE_ARCH_BIN_DIR:"* ]] && return 0

    print_warning "$UPDATE_ARCH_BIN_DIR is not in your PATH"
    echo "Add to your shell profile:"
    echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    echo

    local profile=""
    case "$SHELL" in
        */bash) [[ -f "$HOME/.bash_profile" ]] && profile="$HOME/.bash_profile" || profile="$HOME/.bashrc" ;;
        */zsh)  profile="$HOME/.zshrc" ;;
        */fish) profile="$HOME/.config/fish/config.fish" ;;
        *)      profile="" ;;
    esac

    echo "Add to ${profile:-your shell profile} now? [y/N]"
    local reply
    read -r reply < /dev/tty
    if [[ "$reply" =~ ^[Yy] ]]; then
        [[ -z "$profile" ]] && { print_warning "Unknown shell profile; add manually"; return 1; }
        mkdir -p "$(dirname "$profile")"
        if [[ "$profile" == *fish* ]]; then
            echo "set -x PATH \$HOME/.local/bin \$PATH" >> "$profile"
        else
            echo "export PATH=\"\$HOME/.local/bin:\$PATH\"" >> "$profile"
        fi
        print_success "Added $UPDATE_ARCH_BIN_DIR to PATH in $profile"
        print_warning "Run 'source $profile' or restart your shell"
    fi
    return 1
}

uninstall() {
    local assume_yes="$1"
    local uninstaller
    # Prefer the deployed uninstall.sh (which matches what was installed);
    # fall back to the repo copy when running from a working tree.
    if [[ -x "$UPDATE_ARCH_DATA_DIR/uninstall.sh" ]]; then
        uninstaller="$UPDATE_ARCH_DATA_DIR/uninstall.sh"
    elif [[ -x "./uninstall.sh" ]]; then
        uninstaller="./uninstall.sh"
    else
        print_error "uninstall.sh not found"
        return 1
    fi

    local args=(--run)
    [[ "$assume_yes" == "yes" ]] && args+=(--yes)
    exec "$uninstaller" "${args[@]}"
}

install() {
    print_header "Installing update-arch (user scope)"

    check_dependencies || return 1

    print_header "Terminal Detection"
    test_terminal_detection

    if check_existing_deployment; then
        print_warning "Existing deployment detected — updating in place"
        echo

        local extras
        extras=$(list_extra_files)
        [[ -n "$extras" ]] && handle_extra_files "$extras"
    fi

    resolve_install_provenance
    create_directories   || return 1
    copy_files           || return 1
    write_install_hashes
    write_install_manifest
    create_symlink       || return 1
    configure_terminal_preferences

    local path_ok=0
    ensure_path || path_ok=1

    local version
    version=$(get_version)
    print_success "Installed update-arch v${version}"

    if (( path_ok == 0 )); then
        echo "Run: ${GREEN}update-arch${NC}"
    else
        echo "Run: ${GREEN}$UPDATE_ARCH_BIN_DIR/$SCRIPT_NAME${NC}"
    fi

    echo
    echo "XDG paths:"
    echo "  Data:   $UPDATE_ARCH_DATA_DIR"
    echo "  Config: $UPDATE_ARCH_CONFIG_DIR"
    echo "  State:  $UPDATE_ARCH_STATE_DIR"
    echo "  Cache:  $UPDATE_ARCH_CACHE_DIR"
}

show_help() {
    cat << EOF
${CYAN}${BOLD}deploy.sh${NC}: Install / uninstall update-arch (user scope, XDG-compliant)

${BOLD}Usage:${NC} ./deploy.sh <command>

${BOLD}Commands:${NC}
  ${GREEN}--install${NC}       Install or update the deployed copy
  ${GREEN}--uninstall${NC}     Remove the deployed copy (prompts for confirmation)
  ${GREEN}--yes${NC}           With --uninstall, skip the confirmation prompt
  ${GREEN}-h, --help${NC}      Show this help

${BOLD}Paths (XDG):${NC}
  Data:   $UPDATE_ARCH_DATA_DIR
  Config: $UPDATE_ARCH_CONFIG_DIR
  State:  $UPDATE_ARCH_STATE_DIR  (preserved on uninstall)
  Cache:  $UPDATE_ARCH_CACHE_DIR  (preserved on uninstall)
EOF
}

# Only parse args and dispatch when invoked directly. When sourced (e.g.,
# by update-self.sh's post-update subshell to reuse write_install_hashes /
# write_install_manifest), the top-level would otherwise see the caller's
# $@, not match any command, and exit 1 — short-circuiting the caller.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $# -eq 0 ]]; then
        show_help
        exit 0
    fi

    ASSUME_YES="no"
    COMMAND=""
    while (( $# > 0 )); do
        case "$1" in
            -h|--help)   show_help; exit 0 ;;
            --install)   COMMAND="install"; shift ;;
            --uninstall) COMMAND="uninstall"; shift ;;
            --yes|-y)    ASSUME_YES="yes"; shift ;;
            *)           print_error "Unknown option: $1"; show_help; exit 1 ;;
        esac
    done

    case "$COMMAND" in
        install)   install ;;
        uninstall) uninstall "$ASSUME_YES" ;;
        *)         show_help; exit 1 ;;
    esac
fi
