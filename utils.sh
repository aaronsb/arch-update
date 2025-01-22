#!/bin/bash

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Icons (nerdfonts)
INFO_ICON='' 
SUCCESS_ICON='' 
WARNING_ICON='' 
ERROR_ICON='' 
PACKAGE_ICON='' 
TRASH_ICON='' 
CLOCK_ICON='' 
LOG_ICON='' 
SYNC_ICON='󰁪'
NETWORK_ICON=''
DISK_ICON=''
KEY_ICON=''

# Logging functions
print_header() {
    echo -e "\n${BLUE}${BOLD}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}${BOLD} $1 ${NC}"
    echo -e "${BLUE}${BOLD}════════════════════════════════════════════════════════════════${NC}\n"
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

# System check functions
check_network() {
    print_status "${NETWORK_ICON}" "Checking network connectivity..."
    if ! ping -c 1 archlinux.org &>/dev/null; then
        print_error "No network connectivity"
        return 1
    fi
    print_success "Network connectivity verified"
    return 0
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

check_pacman_keyring() {
    print_status "${KEY_ICON}" "Checking pacman keyring..."
    if ! pacman-key --check-trustdb &>/dev/null; then
        print_warning "Pacman keyring needs updating"
        if ! pacman-key --populate archlinux &>/dev/null; then
            print_error "Failed to update pacman keyring"
            return 1
        fi
    fi
    print_success "Pacman keyring verified"
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

# Logging setup
setup_logging() {
    local log_dir="/var/log/system_updates"
    local max_logs=5
    
    # Create log directory if it doesn't exist
    sudo mkdir -p "$log_dir"
    
    # Set up log rotation
    if [ "$(ls -1 "$log_dir" | wc -l)" -ge "$max_logs" ]; then
        oldest_log=$(ls -1t "$log_dir" | tail -n 1)
        sudo rm "$log_dir/$oldest_log"
    fi
    
    # Create new log file
    local logfile="$log_dir/update_$(date +'%Y%m%d_%H%M%S').log"
    sudo touch "$logfile"
    
    echo "$logfile"
}
