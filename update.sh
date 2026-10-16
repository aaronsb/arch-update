#!/bin/bash
#
# Arch Linux system update and maintenance script
# Performs system health checks, package updates, and maintenance tasks

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
VERSION="0.4.12"

source "$SCRIPT_DIR/utils.sh"
source "$SCRIPT_DIR/system-check.sh"

set_error_handlers

confirm_dry_run_sudo() {
    echo -e "\n${MAGENTA}${BOLD}${ICONS[warning]} WARNING: Dry Run Mode requires sudo rights${NC}"
    echo -e "${YELLOW}• While dry-run mode should not make any changes"
    echo -e "• Modified or incorrect modules could potentially execute commands with SUDO elevation"
    echo -e "• Review module code if concerned about security${NC}"
    echo
    echo -e "${CYAN}Press 'c' to continue, 'q' to quit${NC}"

    local timeout=10 input
    while (( timeout > 0 )); do
        echo -ne "\r${YELLOW}Defaulting to quit in ${timeout} seconds...${NC}"
        if read -t 1 -n 1 input; then
            case "$input" in
                c|C) echo -e "\n\n${GREEN}Proceeding with dry run...${NC}\n"; return 0 ;;
                q|Q) echo -e "\n\n${YELLOW}Exiting at user request${NC}"; exit 0 ;;
            esac
        fi
        ((timeout--))
    done
    echo -e "\n\n${YELLOW}Timeout reached, exiting${NC}"
    exit 0
}

start_sudo_keepalive() {
    sudo -v || {
        print_error "Failed to establish sudo session"
        return 1
    }
    # Detach fds from the parent so the bg loop (and its sleep child) don't
    # hold the parent pipeline's stdout open. Without this redirect, when
    # main runs as `main | tee log`, an orphaned `sleep 60` keeps tee's
    # stdin alive after main returns — script appears to hang up to 60s.
    ( while true; do sudo -v; sleep 60; done ) </dev/null >/dev/null 2>&1 &
    SUDO_REFRESH_PID=$!
    return 0
}

# The one EXIT handler: `trap ... EXIT` replaces any earlier one, so every
# exit-time cleanup goes here.
cleanup_run() {
    stop_sudo_keepalive
    end_run_record
}

stop_sudo_keepalive() {
    [[ -n "$SUDO_REFRESH_PID" ]] || return
    # Kill the subshell's children first (sleep is the long-lived one),
    # then the subshell itself. SIGTERM is enough; sleep responds to it.
    pkill -P "$SUDO_REFRESH_PID" 2>/dev/null
    kill "$SUDO_REFRESH_PID" 2>/dev/null
    SUDO_REFRESH_PID=""
}

main() {
    acquire_run_lock || exit 1

    # Load tunables from update-arch.conf so modules can read them.
    # Failure here only means upstream coordinates are missing — fine for
    # the run flow; --update is what actually needs them.
    read_upstream_config >/dev/null 2>&1 || true

    if [[ -n "$DRY_RUN" ]]; then
        local bar="════════════════════════════════════════════════════════════════"
        echo -e "\n${MAGENTA}${BOLD}${bar}${NC}"
        echo -e "${MAGENTA}${BOLD} ${ICONS[info]} DRY RUN MODE - NO CHANGES WILL BE MADE ${NC}"
        echo -e "${MAGENTA}${BOLD}${bar}${NC}\n"
        confirm_dry_run_sudo
    else
        print_header "${ICONS[clock]} SYSTEM UPDATE STARTED AT $(date)"
        print_status "${ICONS[info]}" "$(show_version_banner "$VERSION")"
        [[ -n "$UPDATE_ARCH_CURRENT_LOG" ]] && \
            print_status "${ICONS[info]}" "Logging to $UPDATE_ARCH_CURRENT_LOG"
    fi

    start_run_record
    trap cleanup_run EXIT
    start_sudo_keepalive || exit 1

    if ! check_system_health "$SCRIPT_DIR"; then
        print_error "System health checks failed"
        exit 1
    fi

    local modules_dir="$SCRIPT_DIR/modules"
    run_phase "SYSTEM UPDATE MODULES" system "${ICONS[sudo]}" "[0-4][0-9]-*.sh" "$modules_dir"
    run_phase "USER UPDATE MODULES"   user   "${ICONS[user]}" "[5-8][0-9]-*.sh" "$modules_dir"
    run_phase "POST-UPDATE STATUS"    status "${ICONS[info]}" "9[0-9]-*.sh"      "$modules_dir"

    local outcome="COMPLETED"
    run_has_failures && outcome="FINISHED WITH FAILURES"

    if [[ -n "$DRY_RUN" ]]; then
        local bar="════════════════════════════════════════════════════════════════"
        echo -e "\n${MAGENTA}${BOLD}${bar}${NC}"
        echo -e "${MAGENTA}${BOLD} ${ICONS[info]} DRY RUN ${outcome} - NO CHANGES WERE MADE ${NC}"
        echo -e "${MAGENTA}${BOLD}${bar}${NC}\n"
    else
        print_header "${ICONS[clock]} SYSTEM UPDATE ${outcome} AT $(date)"
    fi

    print_run_summary
}

run_single_module() {
    local name="$1"
    local path
    path=$(find "$SCRIPT_DIR/modules" -maxdepth 1 -name "*${name}*.sh" | head -n 1)
    if [[ -z "$path" ]]; then
        print_error "No module matching '$name'"
        return 1
    fi

    acquire_run_lock || return 1

    local declared_type
    declared_type=$(module_metadata "$path" | cut -f2)
    if [[ -z "$declared_type" || "$declared_type" == "?" ]]; then
        print_error "Module $(basename "$path") has no MODULE_TYPE"
        return 1
    fi

    # Only system modules need elevation; user/status modules run unprivileged.
    start_run_record
    trap cleanup_run EXIT
    if [[ "$declared_type" == "system" ]]; then
        start_sudo_keepalive || return 1
    fi

    print_header "${ICONS[sync]} RUNNING MODULE: $(basename "$path")"
    local rc=0
    run_module "$path" "$declared_type" || rc=$?
    (( rc != 0 )) && record_failure "$(basename "$path")" "$rc"
    print_run_summary
}

configure_terminal() {
    mkdir -p "$UPDATE_ARCH_CONFIG_DIR"
    if ! configure_terminal_preferences; then
        print_error "Failed to configure terminal preferences"
        return 1
    fi
    setup_icons
}

show_help() {
    cat << EOF
$(show_version_banner "$VERSION")

${CYAN}${BOLD}update-arch${NC}: Arch Linux system update script (user scope)

${BOLD}Usage:${NC} update-arch [OPTIONS]

${BOLD}Options:${NC}
    ${GREEN}-h, --help${NC}              Show this help message
    ${GREEN}--version${NC}               Show version information
    ${GREEN}--run [--yes]${NC}           Run the update process (--yes = auto-accept any self-upgrade)
    ${GREEN}--dry-run [--yes]${NC}       Show what would be updated without making changes
    ${GREEN}--list${NC}                  List installed modules with their metadata
    ${GREEN}--test${NC}                  Lamp-check: verify every module is reachable and valid
    ${GREEN}--only <name>${NC}           Run a single module by name (substring match)
    ${GREEN}--check-update${NC}          Check upstream for a newer update-arch (no changes)
    ${GREEN}--update${NC}                Apply an upstream update (prompts on conflicts)
    ${GREEN}--uninstall${NC}             Remove update-arch (prompts; preserves edited files)
    ${GREEN}--create-module${NC}         Create a new module from template
    ${GREEN}--configure-terminal${NC}    Configure terminal preferences

${BOLD}Paths (XDG):${NC}
    Data    ${BLUE}${UPDATE_ARCH_DATA_DIR}${NC}
    Config  ${BLUE}${UPDATE_ARCH_CONFIG_DIR}${NC}
    Logs    ${BLUE}${UPDATE_ARCH_LOG_DIR}${NC}
    Cache   ${BLUE}${UPDATE_ARCH_CACHE_DIR}${NC}

For more information, see: ${BLUE}${UPDATE_ARCH_DATA_DIR}/README.md${NC}
EOF
}

show_version() { show_version_banner "$VERSION"; }

# -----------------------------------------------------------------------------
# Entry point
# -----------------------------------------------------------------------------
if [[ $# -eq 0 ]]; then
    show_help
    exit 0
fi

case "$1" in
    -h|--help)              show_help; exit 0 ;;
    --version)              show_version; exit 0 ;;
    --configure-terminal)   configure_terminal; exit $? ;;
    --create-module)        shift; exec "${SCRIPT_DIR}/create-module.sh" "$@" ;;
    --list)                 list_modules "$SCRIPT_DIR/modules"; exit 0 ;;
    --test)                 run_self_test "$SCRIPT_DIR/modules"; exit $? ;;
    --check-update)         exec "$SCRIPT_DIR/update-self.sh" --check ;;
    --update)               shift; exec "$SCRIPT_DIR/update-self.sh" --run "$@" ;;
    --uninstall)            shift; exec "$SCRIPT_DIR/uninstall.sh" --run "$@" ;;
    --only)
        shift
        [[ -z "$1" ]] && { print_error "--only requires a module name"; exit 1; }
        # Pipe through tee so output also lands in a log when not dry-run.
        setup_logging
        run_single_module "$1" 2>&1 | tee -a "${UPDATE_ARCH_CURRENT_LOG:-/dev/null}"
        exit "${PIPESTATUS[0]}"
        ;;
    --dry-run|--run)
        action="$1"; shift
        yes_flag=""
        while (( $# > 0 )); do
            case "$1" in
                -y|--yes) yes_flag="--yes"; shift ;;
                *) print_error "Unknown option: $1"; exit 1 ;;
            esac
        done

        # Offer self-update first. If one is applied, stop — don't run
        # maintenance on a freshly-mutated install.
        "$SCRIPT_DIR/update-self.sh" --maybe-upgrade $yes_flag
        case $? in
            0) exit 0 ;;    # update applied → caller should stop
            2)              # update attempted, did not complete
                print_error "Self-update did not complete; maintenance was not run"
                print_status "${ICONS[info]}" "Retry with: update-arch --update"
                exit 1
                ;;
            *) ;;           # no update / declined → proceed
        esac

        if [[ "$action" == "--dry-run" ]]; then
            export DRY_RUN=1
            main
            exit $?
        else
            setup_logging
            main 2>&1 | tee -a "${UPDATE_ARCH_CURRENT_LOG:-/dev/null}"
            exit "${PIPESTATUS[0]}"
        fi
        ;;
    *)
        print_error "Unknown option: $1"
        echo -e "Use ${GREEN}--help${NC} for usage information"
        exit 1
        ;;
esac
