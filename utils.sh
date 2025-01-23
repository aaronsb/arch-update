#!/bin/bash

# Global variables
LOG_FILE=""

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
LOG_ICON='' 
SYNC_ICON='󰁪'
NETWORK_ICON=''
DISK_ICON=''
KEY_ICON=''
DISABLED_ICON='󰈉'

# Logging functions
log_message() {
    local message="$1"
    local level="${2:-INFO}"  # Default level is INFO
    local timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    
    # Output to console with colors
    echo -e "$message"
    
    # If LOG_FILE is set, write to log without colors
    if [[ -n "$LOG_FILE" ]]; then
        # Strip ANSI codes and prepend timestamp
        echo -e "$message" | sed -E 's/\x1B\[[0-9;]*[mGKH]//g' | \
            sed "s/^/$timestamp [$level] /" | \
            sudo tee -a "$LOG_FILE" >/dev/null
    fi
}

print_header() {
    local message="\n${BLUE}${BOLD}════════════════════════════════════════════════════════════════${NC}\n${CYAN}${BOLD} $1 ${NC}\n${BLUE}${BOLD}════════════════════════════════════════════════════════════════${NC}\n"
    log_message "$message" "HEADER"
}

print_status() {
    log_message "${CYAN}$1 ${NC}$2" "STATUS"
}

print_success() {
    log_message "${GREEN}${SUCCESS_ICON} $1${NC}" "SUCCESS"
}

print_warning() {
    log_message "${YELLOW}${WARNING_ICON} $1${NC}" "WARNING"
}

print_error() {
    log_message "${RED}${ERROR_ICON} $1${NC}" "ERROR"
    return 1
}

print_disabled() {
    log_message "${MAGENTA}${DISABLED_ICON} $1${NC}" "DISABLED"
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

# Strip ANSI color codes
strip_ansi() {
    # Remove ANSI escape sequences while preserving actual content
    sed -E 's/\x1B\[[0-9;]*[mGKH]//g'
}

# Educational message functions
print_info_box() {
    local message="\n${BLUE}${BOLD}════════════════════════════════════════════════════════════════${NC}\n${GREEN} ${INFO_ICON} ${message} ${NC}\n${BLUE}${BOLD}════════════════════════════════════════════════════════════════${NC}\n"
    log_message "$message" "INFO"
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
    
    log_message "$message" "SECTION"
}

# Initialize logging for the current session
setup_logging() {
    local log_dir="/var/log/system_updates"
    local max_logs=5
    
    # Create log directory if it doesn't exist
    if [ ! -d "$log_dir" ]; then
        sudo mkdir -p "$log_dir"
        sudo chown root:root "$log_dir"
        sudo chmod 755 "$log_dir"
    fi
    
    # Create new log file with timestamp
    local timestamp=$(date +'%Y-%m-%d')
    LOG_FILE="$log_dir/$timestamp.log"
    
    # Create and set permissions for new log file
    sudo touch "$LOG_FILE"
    sudo chown root:root "$LOG_FILE"
    sudo chmod 644 "$LOG_FILE"
    
    # Initialize the log file with a header
    {
        echo "System Update Log - $(date)"
        echo "----------------------------------------"
    } | sudo tee "$LOG_FILE" >/dev/null

    # Print initial message
    log_message "${CYAN}${LOG_ICON} Log file created: ${BOLD}$LOG_FILE${NC}" "INFO"
    
    # Return the logfile path
    echo "$LOG_FILE"
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
