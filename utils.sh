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
)

# Active icons array
declare -A ICONS

# Font support detection
detect_font_support() {
    # Check if user has explicitly set preference
    if [[ -n "$FORCE_ASCII_ICONS" ]]; then
        return 1
    fi
    
    # Check for common terminals known to support Nerd Fonts
    if [[ "$TERM_PROGRAM" == "vscode" ]] || \
       [[ "$TERM_PROGRAM" == "iTerm.app" ]] || \
       [[ -n "$KITTY_WINDOW_ID" ]] || \
       [[ -n "$ALACRITTY_LOG" ]]; then
        return 0
    fi
    
    # Test if terminal can display a Nerd Font character
    if echo -ne "󰋼" | grep -q "󰋼"; then
        return 0
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
