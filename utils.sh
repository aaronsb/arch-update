#!/bin/bash

# Color definitions
RED="$(tput setaf 1)"
GREEN="$(tput setaf 2)"
YELLOW="$(tput setaf 3)"
BLUE="$(tput setaf 4)"
MAGENTA="$(tput setaf 5)"
CYAN="$(tput setaf 6)"
NC="$(tput sgr0)" # No Color
BOLD="$(tput bold)"

# Icon Sets
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
    [success]='[√]'
    [warning]='[!]'
    [error]='[×]'
    [package]='[#]'
    [trash]='[~]'
    [clock]='[@]'
    [sync]='[S]'
    [network]='[N]'
    [disk]='[D]'
    [key]='[K]'
    [disabled]='[-]'
    [sudo]='[S]'
    [user]='(☺)'
)

# Active icons array
declare -A ICONS

# Load terminal configuration
load_terminal_config() {
    local config_file="$HOME/.config/update-arch/terminal.conf"
    if [[ -f "$config_file" ]]; then
        # Source the config file
        source "$config_file"
        
        # Check if we should redetect (30 days)
        if [[ -n "$LAST_DETECTION_TIME" ]]; then
            local now current_time last_time diff
            current_time=$(date +%s)
            last_time=$LAST_DETECTION_TIME
            diff=$((current_time - last_time))
            
            # If more than 30 days, trigger redetection
            if [[ $diff -gt 2592000 ]]; then
                return 1
            fi
        fi
        return 0
    fi
    return 1
}

# Font support detection
detect_font_support() {
    # Load config if available
    if load_terminal_config; then
        # Use configured preference if available
        if [[ "$FORCE_ASCII_ICONS" == "true" ]]; then
            return 1
        fi
    fi
    
    # Check for common terminals known to support Nerd Fonts
    if [[ "$PREFERRED_TERMINAL" != "auto" && -n "$PREFERRED_TERMINAL" ]]; then
        # Use preferred terminal setting
        case "$PREFERRED_TERMINAL" in
            "vscode"|"iterm2"|"kitty"|"alacritty"|"wezterm")
                return 0
                ;;
            *)
                return 1
                ;;
        esac
    else
        # Auto-detect support
        if [[ "$TERM_PROGRAM" == "vscode" ]] || \
           [[ "$TERM_PROGRAM" == "iTerm.app" ]] || \
           [[ -n "$KITTY_WINDOW_ID" ]] || \
           [[ -n "$ALACRITTY_LOG" ]] || \
           [[ -n "$WEZTERM_PANE" ]]; then
            return 0
        fi
        
        # Test if terminal can display a Nerd Font character
        if echo -ne "󰋼" | grep -q "󰋼"; then
            return 0
        fi
    fi
    
    return 1
}

# Initialize icons based on detected support
setup_icons() {
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

# Initialize icons immediately
setup_icons

# Terminal detection
detect_terminal() {
    local terminal_info=()
    
    # Check for multiplexers first (they wrap other terminals)
    [[ -n "$TMUX" ]] && terminal_info+=("tmux")
    [[ -n "$STY" ]] && terminal_info+=("screen")
    
    # Check for specific terminal emulators
    if [[ "$TERM_PROGRAM" == "vscode" ]]; then
        terminal_info+=("vscode")
    elif [[ "$TERM_PROGRAM" == "iTerm.app" ]]; then
        terminal_info+=("iterm2")
    elif [[ -n "$KITTY_WINDOW_ID" ]]; then
        terminal_info+=("kitty")
    elif [[ -n "$ALACRITTY_LOG" ]]; then
        terminal_info+=("alacritty")
    elif [[ -n "$GNOME_TERMINAL_SERVICE" ]]; then
        terminal_info+=("gnome-terminal")
    elif [[ -n "$KONSOLE_VERSION" ]]; then
        terminal_info+=("konsole")
    elif [[ -n "$TERMINATOR_UUID" ]]; then
        terminal_info+=("terminator")
    elif [[ "$TERM" == "xterm"* ]]; then
        terminal_info+=("xterm")
    elif [[ -n "$WEZTERM_PANE" ]]; then
        terminal_info+=("wezterm")
    elif [[ -n "$TILIX_ID" ]]; then
        terminal_info+=("tilix")
    fi
    
    # If no specific terminal was detected but we're in a multiplexer
    if [[ ${#terminal_info[@]} -eq 1 ]] && [[ "${terminal_info[0]}" =~ ^(tmux|screen)$ ]]; then
        # Add a generic terminal indicator
        terminal_info+=("terminal")
    fi
    
    # If no terminal was detected at all
    if [[ ${#terminal_info[@]} -eq 0 ]]; then
        terminal_info+=("unknown")
    fi
    
    # Join all detected terminals with '+'
    local IFS="+"
    echo "${terminal_info[*]}"
}

# Test terminal detection
test_terminal_detection() {
    local term_info=$(detect_terminal)
    print_status "${ICONS[info]}" "Detected terminal(s): $term_info"
    
    # Parse the terminal string
    local terms
    IFS='+' read -ra terms <<< "$term_info"
    
    # Print detailed information
    for term in "${terms[@]}"; do
        case "$term" in
            "tmux") print_info_box "Running inside tmux multiplexer" ;;
            "screen") print_info_box "Running inside GNU Screen multiplexer" ;;
            "vscode") print_info_box "Running in Visual Studio Code integrated terminal" ;;
            "iterm2") print_info_box "Running in iTerm2 terminal" ;;
            "kitty") print_info_box "Running in Kitty terminal" ;;
            "alacritty") print_info_box "Running in Alacritty terminal" ;;
            "gnome-terminal") print_info_box "Running in GNOME Terminal" ;;
            "konsole") print_info_box "Running in KDE Konsole" ;;
            "terminator") print_info_box "Running in Terminator" ;;
            "xterm") print_info_box "Running in XTerm" ;;
            "wezterm") print_info_box "Running in WezTerm" ;;
            "tilix") print_info_box "Running in Tilix" ;;
            "terminal") print_info_box "Running in an unspecified terminal" ;;
            "unknown") print_info_box "Unable to detect specific terminal type" ;;
        esac
    done
}

print_header() {
    local message="\n${BLUE}${BOLD}════════════════════════════════════════════════════════════════${NC}\n${CYAN}${BOLD} $1 ${NC}\n${BLUE}${BOLD}════════════════════════════════════════════════════════════════${NC}\n"
    echo -e "$message"
}

print_status() {
    echo -e "${CYAN}${1:+$1 }${NC}$2"
}

print_success() {
    echo -e "${GREEN}${ICONS[success]} $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}${ICONS[warning]} $1${NC}"
}

print_error() {
    echo -e "${RED}${ICONS[error]} $1${NC}"
    return 1
}

print_disabled() {
    echo -e "${MAGENTA}${ICONS[disabled]} $1${NC}"
}

# System check functions
check_network() {
    print_status "${ICONS[network]}" "Checking network connectivity..."
    
    # List of servers to try, in order of preference
    local servers=("archlinux.org" "google.com" "cloudflare.com")
    local timeout=5  # timeout in seconds
    
    for server in "${servers[@]}"; do
        if ping -c 1 -W $timeout "$server" &>/dev/null; then
            print_success "Network connectivity verified (via $server)"
            return 0
        fi
    done
    
    print_error "No network connectivity (tried ${#servers[@]} servers)"
    return 1
}

check_disk_space() {
    print_status "${ICONS[disk]}" "Checking available disk space..."
    local min_space=1000000  # 1GB in KB
    local available=$(df -k / | awk 'NR==2 {print $4}')
    
    if [ "$available" -lt "$min_space" ]; then
        print_error "Insufficient disk space. At least 1GB required."
        return 1
    fi
    print_success "Sufficient disk space available"
    return 0
}

check_aur_helper() {
    local helpers=("yay" "paru")
    for helper in "${helpers[@]}"; do
        if command -v "$helper" &>/dev/null; then
            echo "$helper"
            return 0
        fi
    done
    echo "pacman"
    return 1
}

# Error handling
handle_error() {
    print_error "$1"
    exit "${2:-1}"
}

# Set up error handling
set_error_handlers() {
    trap 'handle_error "Script interrupted" 130' INT TERM
    trap 'handle_error "Script error on line $LINENO" 1' ERR
}

# Educational and informational message functions
print_education() {
    local title="$1"
    local content="$2"
    local link="$3"
    
    # Print title
    echo -e "\n${CYAN}${BOLD}${title}${NC}"
    
    # Print content with indentation
    while IFS= read -r line; do
        echo -e " ${GREEN}${ICONS[info]} ${line}${NC}"
    done <<< "$content"
    
    # Add link if provided
    if [ -n "$link" ]; then
        echo -e " ${GREEN}🔗 Learn more: ${link}${NC}"
    fi
    
    echo
}

print_info_box() {
    local content="$1"
    
    # Print content with subtle formatting
    echo -e "\n${BLUE}> ${NC}${BOLD}Important:${NC}"
    while IFS= read -r line; do
        echo -e "  ${BLUE}•${NC} ${line}"
    done <<< "$content"
    echo
}

print_section_box() {
    # Redirect to new education function for better readability
    print_education "$1" "$2" "$3"
}

# Module type validation
validate_module_type() {
    local module_name="$1"
    local declared_type="$2"
    local expected_type="$3"
    
    if [[ "$declared_type" != "$expected_type" ]]; then
        print_error "Module type mismatch in $(basename "$module_name")"
        print_error "Declared as '$declared_type' but placed in '$expected_type' number range"
        print_error "Please move module to correct number range or fix type declaration"
        return 1
    fi
    return 0
}
