#!/bin/bash
#
# Dev helper: show what update-arch detects about the current terminal.
# Not deployed — listed in .deployignore.

source "$(dirname "$(readlink -f "$0")")/utils.sh"

show_help() {
    cat << EOF
test-terminal.sh: report detected terminal and relevant env vars.

Usage: ./test-terminal.sh <command>

Commands:
  --run         Run the terminal detection report
  -h, --help    Show this help
EOF
}

run_report() {
    print_header "Terminal Detection Test"

    test_terminal_detection

    local term_info
    term_info=$(detect_terminal)
    echo -e "\n${CYAN}${BOLD}Example Usage:${NC}"
    case "$term_info" in
        *vscode*)              print_success "VSCode-specific features enabled" ;;
        *tmux*)                print_success "tmux-specific features enabled" ;;
        *kitty*|*alacritty*)   print_success "GPU-accelerated terminal features enabled" ;;
    esac

    echo -e "\n${CYAN}${BOLD}Relevant Environment Variables:${NC}"
    local var
    for var in TERM_PROGRAM TERM TMUX STY KITTY_WINDOW_ID ALACRITTY_LOG \
               GNOME_TERMINAL_SERVICE KONSOLE_VERSION TERMINATOR_UUID \
               WEZTERM_PANE TILIX_ID; do
        echo -e "${GREEN}${var}=${NC}${!var}"
    done
}

case "${1:-}" in
    --run)       run_report ;;
    -h|--help|"") show_help ;;
    *)           echo "Unknown option: $1" >&2; exit 1 ;;
esac
