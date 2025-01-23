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

# Icons (nerdfonts)
INFO_ICON='' 
SUCCESS_ICON='' 
WARNING_ICON='' 
ERROR_ICON='' 
PACKAGE_ICON='' 
TRASH_ICON='' 
CLOCK_ICON='' 
SYNC_ICON='󰁪'
NETWORK_ICON=''
DISK_ICON=''
KEY_ICON=''
DISABLED_ICON='󰈉'

print_header() {
    local message="\n${BLUE}${BOLD}════════════════════════════════════════════════════════════════${NC}\n${CYAN}${BOLD} $1 ${NC}\n${BLUE}${BOLD}════════════════════════════════════════════════════════════════${NC}\n"
    echo -e "$message"
}

print_status() {
    echo -e "${CYAN}$1 ${NC}$2"
}

print_success() {
    echo -e "${GREEN}${SUCCESS_ICON} $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}${WARNING_ICON} $1${NC}"
}

print_error() {
    echo -e "${RED}${ERROR_ICON} $1${NC}"
    return 1
}

print_disabled() {
    echo -e "${MAGENTA}${DISABLED_ICON} $1${NC}"
}

# System check functions
check_network() {
    print_status "${NETWORK_ICON}" "Checking network connectivity..."
    
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
    print_status "${DISK_ICON}" "Checking available disk space..."
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

# Educational message functions
print_info_box() {
    local message="\n${BLUE}${BOLD}════════════════════════════════════════════════════════════════${NC}\n${GREEN} ${INFO_ICON} ${message} ${NC}\n${BLUE}${BOLD}════════════════════════════════════════════════════════════════${NC}\n"
    echo -e "$message"
}

print_section_box() {
    local title="$1"
    local content="$2"
    local link="$3"
    
    # Build the complete message
    local message="\n${BLUE}${BOLD}════════════════════════════════════════════════════════════════${NC}\n"
    message+="${CYAN}${BOLD} ${title} ${NC}\n"
    message+="${BLUE}${BOLD}════════════════════════════════════════════════════════════════${NC}\n"
    
    # Add content
    while IFS= read -r line; do
        message+="${GREEN} ${INFO_ICON} ${line} ${NC}\n"
    done <<< "$content"
    
    # Add link if provided
    if [ -n "$link" ]; then
        message+="${GREEN} 🔗 Learn more: ${NC}\n"
        message+="${GREEN}    ${link} ${NC}\n"
    fi
    
    # Add closing line
    message+="${BLUE}${BOLD}════════════════════════════════════════════════════════════════${NC}\n"
    
    echo -e "$message"
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
