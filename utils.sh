#!/bin/bash
#
# Shared runtime for update-arch: XDG paths, colors, icons, print helpers,
# system checks, and the module lifecycle dispatcher.

# ---------------------------------------------------------------------------
# XDG-compliant paths (user scope)
# ---------------------------------------------------------------------------
UPDATE_ARCH_DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/update-arch"
UPDATE_ARCH_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/update-arch"
UPDATE_ARCH_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/update-arch"
UPDATE_ARCH_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/update-arch"
UPDATE_ARCH_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
UPDATE_ARCH_BIN_DIR="$HOME/.local/bin"
UPDATE_ARCH_LOG_DIR="$UPDATE_ARCH_STATE_DIR/logs"
UPDATE_ARCH_BACKUP_DIR="$UPDATE_ARCH_CACHE_DIR/backups"
UPDATE_ARCH_LOCK_FILE="$UPDATE_ARCH_RUNTIME_DIR/update-arch.lock"
UPDATE_ARCH_TERMINAL_CONF="$UPDATE_ARCH_CONFIG_DIR/terminal.conf"
UPDATE_ARCH_MAX_LOGS=5

# ---------------------------------------------------------------------------
# Colors
# ---------------------------------------------------------------------------
RED="$(tput setaf 1)"
GREEN="$(tput setaf 2)"
YELLOW="$(tput setaf 3)"
BLUE="$(tput setaf 4)"
MAGENTA="$(tput setaf 5)"
CYAN="$(tput setaf 6)"
NC="$(tput sgr0)"
BOLD="$(tput bold)"

# ---------------------------------------------------------------------------
# Icon sets
# ---------------------------------------------------------------------------
declare -A NERDFONT_ICONS=(
    [info]='󰋼'
    [success]='󰗠'
    [warning]='󰀦'
    [error]='󰝤'
    [package]='󰏖'
    [trash]='󰩺'
    [clock]='󰥔'
    [sync]='󰓦'
    [network]='󰤨'
    [disk]='󰋊'
    [key]='󰌋'
    [disabled]='󰜺'
    [sudo]='󰌆'
    [user]='󰀄'
)

declare -A ASCII_ICONS=(
    [info]='(i)'
    [success]='[v]'
    [warning]='[!]'
    [error]='[x]'
    [package]='[#]'
    [trash]='[~]'
    [clock]='[@]'
    [sync]='[S]'
    [network]='[N]'
    [disk]='[D]'
    [key]='[K]'
    [disabled]='[-]'
    [sudo]='[S]'
    [user]='(u)'
)

declare -A ICONS

load_terminal_config() {
    [[ -f "$UPDATE_ARCH_TERMINAL_CONF" ]] || return 1
    source "$UPDATE_ARCH_TERMINAL_CONF"

    if [[ -n "$LAST_DETECTION_TIME" ]]; then
        local now diff
        now=$(date +%s)
        diff=$((now - LAST_DETECTION_TIME))
        (( diff > 2592000 )) && return 1
    fi
    return 0
}

detect_font_support() {
    if load_terminal_config; then
        [[ "$FORCE_ASCII_ICONS" == "true" ]] && return 1
    fi

    if [[ "$PREFERRED_TERMINAL" != "auto" && -n "$PREFERRED_TERMINAL" ]]; then
        case "$PREFERRED_TERMINAL" in
            vscode|iterm2|kitty|alacritty|wezterm) return 0 ;;
            *) return 1 ;;
        esac
    fi

    if [[ "$TERM_PROGRAM" == "vscode" ]] || \
       [[ "$TERM_PROGRAM" == "iTerm.app" ]] || \
       [[ -n "$KITTY_WINDOW_ID" ]] || \
       [[ -n "$ALACRITTY_LOG" ]] || \
       [[ -n "$WEZTERM_PANE" ]]; then
        return 0
    fi

    return 1
}

setup_icons() {
    local key
    if detect_font_support; then
        for key in "${!NERDFONT_ICONS[@]}"; do
            ICONS[$key]="${NERDFONT_ICONS[$key]}"
        done
    else
        for key in "${!ASCII_ICONS[@]}"; do
            ICONS[$key]="${ASCII_ICONS[$key]}"
        done
    fi
}
setup_icons

# ---------------------------------------------------------------------------
# Terminal detection
# ---------------------------------------------------------------------------
detect_terminal() {
    local info=()
    [[ -n "$TMUX" ]] && info+=("tmux")
    [[ -n "$STY" ]] && info+=("screen")

    if [[ "$TERM_PROGRAM" == "vscode" ]]; then
        info+=("vscode")
    elif [[ "$TERM_PROGRAM" == "iTerm.app" ]]; then
        info+=("iterm2")
    elif [[ -n "$KITTY_WINDOW_ID" ]]; then
        info+=("kitty")
    elif [[ -n "$ALACRITTY_LOG" ]]; then
        info+=("alacritty")
    elif [[ -n "$GNOME_TERMINAL_SERVICE" ]]; then
        info+=("gnome-terminal")
    elif [[ -n "$KONSOLE_VERSION" ]]; then
        info+=("konsole")
    elif [[ -n "$TERMINATOR_UUID" ]]; then
        info+=("terminator")
    elif [[ -n "$WEZTERM_PANE" ]]; then
        info+=("wezterm")
    elif [[ -n "$TILIX_ID" ]]; then
        info+=("tilix")
    elif [[ "$TERM" == "xterm"* ]]; then
        info+=("xterm")
    fi

    if [[ ${#info[@]} -eq 1 && "${info[0]}" =~ ^(tmux|screen)$ ]]; then
        info+=("terminal")
    fi
    [[ ${#info[@]} -eq 0 ]] && info+=("unknown")

    local IFS="+"
    echo "${info[*]}"
}

test_terminal_detection() {
    local term_info
    term_info=$(detect_terminal)
    print_status "${ICONS[info]}" "Detected terminal(s): $term_info"

    local terms
    IFS='+' read -ra terms <<< "$term_info"
    for term in "${terms[@]}"; do
        case "$term" in
            tmux)           print_info_box "Running inside tmux multiplexer" ;;
            screen)         print_info_box "Running inside GNU Screen multiplexer" ;;
            vscode)         print_info_box "Running in Visual Studio Code integrated terminal" ;;
            iterm2)         print_info_box "Running in iTerm2 terminal" ;;
            kitty)          print_info_box "Running in Kitty terminal" ;;
            alacritty)      print_info_box "Running in Alacritty terminal" ;;
            gnome-terminal) print_info_box "Running in GNOME Terminal" ;;
            konsole)        print_info_box "Running in KDE Konsole" ;;
            terminator)     print_info_box "Running in Terminator" ;;
            xterm)          print_info_box "Running in XTerm" ;;
            wezterm)        print_info_box "Running in WezTerm" ;;
            tilix)          print_info_box "Running in Tilix" ;;
            terminal)       print_info_box "Running in an unspecified terminal" ;;
            unknown)        print_info_box "Unable to detect specific terminal type" ;;
        esac
    done
}

# ---------------------------------------------------------------------------
# Print helpers
# ---------------------------------------------------------------------------
print_header() {
    local bar="════════════════════════════════════════════════════════════════"
    echo -e "\n${BLUE}${BOLD}${bar}${NC}\n${CYAN}${BOLD} $1 ${NC}\n${BLUE}${BOLD}${bar}${NC}\n"
}

print_status()   { echo -e "${CYAN}${1:+$1 }${NC}$2"; }
print_success()  { echo -e "${GREEN}${ICONS[success]} $1${NC}"; }
print_warning()  { echo -e "${YELLOW}${ICONS[warning]} $1${NC}"; }
print_error()    { echo -e "${RED}${ICONS[error]} $1${NC}" >&2; return 1; }
print_disabled() { echo -e "${MAGENTA}${ICONS[disabled]} $1${NC}"; }

print_education() {
    local title="$1" content="$2" link="$3"
    echo -e "\n${CYAN}${BOLD}${title}${NC}"
    while IFS= read -r line; do
        echo -e " ${GREEN}${ICONS[info]} ${line}${NC}"
    done <<< "$content"
    [[ -n "$link" ]] && echo -e " ${GREEN}Learn more: ${link}${NC}"
    echo
}

print_info_box() {
    local content="$1"
    echo -e "\n${BLUE}> ${NC}${BOLD}Important:${NC}"
    while IFS= read -r line; do
        echo -e "  ${BLUE}•${NC} ${line}"
    done <<< "$content"
    echo
}

# Legacy alias; modules still call this.
print_section_box() { print_education "$1" "$2" "$3"; }

# ---------------------------------------------------------------------------
# System checks
# ---------------------------------------------------------------------------
check_network() {
    print_status "${ICONS[network]}" "Checking network connectivity..."
    local servers=("archlinux.org" "google.com" "cloudflare.com")
    local timeout=5

    for server in "${servers[@]}"; do
        if ping -c 1 -W "$timeout" "$server" &>/dev/null; then
            print_success "Network connectivity verified (via $server)"
            return 0
        fi
    done

    print_error "No network connectivity (tried ${#servers[@]} servers)"
    return 1
}

check_disk_space() {
    print_status "${ICONS[disk]}" "Checking available disk space..."
    local min_space=1000000
    local available
    available=$(df -k / | awk 'NR==2 {print $4}')

    if [ "$available" -lt "$min_space" ]; then
        print_error "Insufficient disk space. At least 1GB required."
        return 1
    fi
    print_success "Sufficient disk space available"
}

check_aur_helper() {
    for helper in yay paru; do
        if command -v "$helper" &>/dev/null; then
            echo "$helper"
            return 0
        fi
    done
    echo "pacman"
    return 1
}

# ---------------------------------------------------------------------------
# Error handling
# ---------------------------------------------------------------------------
handle_error() {
    print_error "$1"
    exit "${2:-1}"
}

set_error_handlers() {
    trap 'handle_error "Script interrupted" 130' INT TERM
}

# ---------------------------------------------------------------------------
# Module lifecycle
# ---------------------------------------------------------------------------
#
# Modules declare metadata and implement `run_update`. The runtime:
#   1. Sources the module in a subshell (isolates state).
#   2. Validates MODULE_TYPE matches the expected phase.
#   3. Auto-derives check_supported from MODULE_REQUIRES if not defined.
#   4. Dispatches check_supported, then run_update.
#
# Metadata fields (declare at top of module):
#   MODULE_TYPE        - "system" | "user" | "status" (required)
#   MODULE_NAME        - display name (default: filename without prefix)
#   MODULE_DESCRIPTION - one-line summary
#   MODULE_REQUIRES    - space-separated commands that must exist on PATH
#   MODULE_DRY_RUN_SAFE - "true" | "false" (default: "true")
#
validate_module_type() {
    local module="$1" declared="$2" expected="$3"
    if [[ "$declared" != "$expected" ]]; then
        print_error "Module $(basename "$module"): MODULE_TYPE='$declared' but placed in '$expected' phase"
        print_error "Move the module to the correct number range or fix MODULE_TYPE"
        return 1
    fi
    return 0
}

run_module() {
    local module="$1" expected_phase="$2"
    local base
    base=$(basename "$module")

    if [[ ! -r "$module" ]]; then
        print_warning "Module not readable: $base"
        return 1
    fi

    (
        set +e
        MODULE_TYPE=""
        MODULE_NAME=""
        MODULE_DESCRIPTION=""
        MODULE_REQUIRES=""
        MODULE_DRY_RUN_SAFE="true"
        unset -f check_supported run_update 2>/dev/null

        # shellcheck disable=SC1090
        if ! source "$module"; then
            print_warning "Module $base failed to load"
            exit 1
        fi

        if [[ -z "$MODULE_TYPE" ]]; then
            print_error "Module $base: missing MODULE_TYPE"
            exit 1
        fi
        validate_module_type "$module" "$MODULE_TYPE" "$expected_phase" || exit 1

        if ! declare -F run_update >/dev/null; then
            print_error "Module $base: no run_update() defined"
            exit 1
        fi

        if ! declare -F check_supported >/dev/null; then
            check_supported() {
                local req
                for req in $MODULE_REQUIRES; do
                    command -v "$req" &>/dev/null || return 1
                done
                return 0
            }
        fi

        if ! check_supported; then
            print_status "${ICONS[info]}" "Module $base not supported on this system"
            exit 0
        fi

        if [[ -n "$DRY_RUN" && "$MODULE_DRY_RUN_SAFE" != "true" ]]; then
            print_status "${ICONS[info]}" "Module $base not dry-run safe; skipping"
            exit 0
        fi

        run_update
    )
    local rc=$?
    [[ $rc -ne 0 ]] && print_warning "Module $base exited with status $rc"
    return 0
}

module_metadata() {
    local module="$1"
    (
        set +e
        MODULE_TYPE=""
        MODULE_NAME=""
        MODULE_DESCRIPTION=""
        MODULE_REQUIRES=""
        # shellcheck disable=SC1090
        source "$module" 2>/dev/null || exit 0
        local base
        base=$(basename "$module" .sh)
        printf '%s\t%s\t%s\t%s\n' \
            "$base" \
            "${MODULE_TYPE:-?}" \
            "${MODULE_DESCRIPTION:-(no description)}" \
            "${MODULE_REQUIRES:-}"
    )
}

list_modules() {
    local modules_dir="$1"
    printf "%-28s %-8s %s\n" "MODULE" "TYPE" "DESCRIPTION"
    printf "%-28s %-8s %s\n" "------" "----" "-----------"
    local f name type desc
    while IFS= read -r f; do
        IFS=$'\t' read -r name type desc _ < <(module_metadata "$f")
        printf "%-28s %-8s %s\n" "$name" "$type" "$desc"
    done < <(find "$modules_dir" -maxdepth 1 -name "*.sh" | sort)
}

# ---------------------------------------------------------------------------
# Run lock
# ---------------------------------------------------------------------------
acquire_run_lock() {
    exec 9>"$UPDATE_ARCH_LOCK_FILE" || {
        print_error "Cannot open lock file: $UPDATE_ARCH_LOCK_FILE"
        return 1
    }
    if ! flock -n 9; then
        print_error "Another update-arch instance is already running"
        print_status "${ICONS[info]}" "Lock: $UPDATE_ARCH_LOCK_FILE"
        return 1
    fi
    return 0
}

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
setup_logging() {
    mkdir -p "$UPDATE_ARCH_LOG_DIR" || return 1
    local ts
    ts=$(date +%Y%m%d-%H%M%S)
    UPDATE_ARCH_CURRENT_LOG="$UPDATE_ARCH_LOG_DIR/update-$ts.log"
    export UPDATE_ARCH_CURRENT_LOG

    local existing
    mapfile -t existing < <(find "$UPDATE_ARCH_LOG_DIR" -maxdepth 1 -name 'update-*.log' | sort -r)
    local i
    for ((i=UPDATE_ARCH_MAX_LOGS; i<${#existing[@]}; i++)); do
        rm -f "${existing[$i]}"
    done
    return 0
}
