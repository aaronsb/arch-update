#!/bin/bash

# Source utilities
source utils.sh

print_header "Terminal Detection Test"

# Run the detection test
test_terminal_detection

# Example of using terminal detection in a script
term_info=$(detect_terminal)
echo -e "\n${CYAN}${BOLD}Example Usage:${NC}"
case "$term_info" in
    *"vscode"*)
        print_success "VSCode-specific features enabled"
        ;;
    *"tmux"*)
        print_success "tmux-specific features enabled"
        ;;
    *"kitty"* | *"alacritty"*)
        print_success "GPU-accelerated terminal features enabled"
        ;;
esac

# Show all environment variables that helped with detection
echo -e "\n${CYAN}${BOLD}Relevant Environment Variables:${NC}"
echo -e "${GREEN}TERM_PROGRAM=${NC}$TERM_PROGRAM"
echo -e "${GREEN}TERM=${NC}$TERM"
echo -e "${GREEN}TMUX=${NC}$TMUX"
echo -e "${GREEN}STY=${NC}$STY"
echo -e "${GREEN}KITTY_WINDOW_ID=${NC}$KITTY_WINDOW_ID"
echo -e "${GREEN}ALACRITTY_LOG=${NC}$ALACRITTY_LOG"
echo -e "${GREEN}GNOME_TERMINAL_SERVICE=${NC}$GNOME_TERMINAL_SERVICE"
echo -e "${GREEN}KONSOLE_VERSION=${NC}$KONSOLE_VERSION"
echo -e "${GREEN}TERMINATOR_UUID=${NC}$TERMINATOR_UUID"
echo -e "${GREEN}WEZTERM_PANE=${NC}$WEZTERM_PANE"
echo -e "${GREEN}TILIX_ID=${NC}$TILIX_ID"
