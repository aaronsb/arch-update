#!/bin/bash
#
# Arch Linux system update and maintenance script
# Performs system health checks, package updates, and maintenance tasks

# Constants
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
INSTALL_DIR="$HOME/.local/share/update-arch"
VERSION="0.2.0"

# Source companion scripts
source "$SCRIPT_DIR/utils.sh"
source "$SCRIPT_DIR/system-check.sh"

# Set up error handling
set_error_handlers

# Function to confirm sudo usage in dry-run mode
confirm_dry_run_sudo() {
    echo -e "\n${MAGENTA}${BOLD}${ICONS[warning]} WARNING: Dry Run Mode requires sudo rights${NC}"
    echo -e "${YELLOW}• While dry-run mode should not make any changes"
    echo -e "• Modified or incorrect modules could potentially execute commands with SUDO elevation"
    echo -e "• Review module code if concerned about security${NC}"
    echo
    echo -e "${CYAN}Press 'c' to continue, 'q' to quit${NC}"
    
    # Start countdown
    local timeout=10
    while [ $timeout -gt 0 ]; do
        echo -ne "\r${YELLOW}Defaulting to quit in ${timeout} seconds...${NC}"
        read -t 1 -n 1 input
        if [ $? -eq 0 ]; then
            case "$input" in
                c|C)
                    echo -e "\n\n${GREEN}Proceeding with dry run...${NC}\n"
                    return 0
                    ;;
                q|Q)
                    echo -e "\n\n${YELLOW}Exiting at user request${NC}"
                    exit 0
                    ;;
            esac
        fi
        ((timeout--))
    done
    
    echo -e "\n\n${YELLOW}Timeout reached, exiting${NC}"
    exit 0
}

main() {
    if [[ -n "$DRY_RUN" ]]; then
        echo -e "\n${MAGENTA}${BOLD}════════════════════════════════════════════════════════════════${NC}"
        echo -e "${MAGENTA}${BOLD} ${ICONS[info]} DRY RUN MODE - NO CHANGES WILL BE MADE ${NC}"
        echo -e "${MAGENTA}${BOLD}════════════════════════════════════════════════════════════════${NC}\n"
        
        # Confirm sudo usage in dry-run mode
        confirm_dry_run_sudo
    else
        print_header "${ICONS[clock]} SYSTEM UPDATE STARTED AT $(date)"
    fi
    
    # Establish sudo session
    sudo -v
    if [ $? -ne 0 ]; then
        print_error "Failed to establish sudo session"
        exit 1
    fi
    
    # Keep sudo session alive with proper cleanup
    cleanup_sudo() {
        if [[ -n "$SUDO_REFRESH_PID" ]]; then
            kill $SUDO_REFRESH_PID 2>/dev/null || true
        fi
    }
    trap cleanup_sudo EXIT

    ( while true; do sudo -v; sleep 60; done; ) &
    SUDO_REFRESH_PID=$!
    
    # Perform system health checks
    if ! check_system_health "$INSTALL_DIR"; then
        print_error "System health checks failed"
        cleanup_sudo
        exit 1
    fi
    
    # Phase 1: System Modules (10-49)
    print_header "${ICONS[sudo]} SYSTEM UPDATE MODULES"
    while IFS= read -r module; do
        if [[ ! -x "$module" ]]; then
            continue
        fi
        
        # Check if this is a disabled module
        if [[ "$module" == *.disabled ]]; then
            print_disabled "System module disabled: $(basename "$module")"
            continue
        fi
        
        if [[ -n "$DRY_RUN" ]]; then
            print_status "${ICONS[sudo]}" "Would run system module: $(basename "$module")"
        else
            print_status "${ICONS[sudo]}" "Running system module with elevated privileges: $(basename "$module")"
        fi
        
        if ! source "$module"; then
            print_warning "Module $(basename "$module") failed"
            continue
        fi
        if ! validate_module_type "$module" "$MODULE_TYPE" "system"; then
            print_error "Module validation failed for $(basename "$module")"
            cleanup_sudo
            exit 1
        fi
        if ! check_supported; then
            print_status "${ICONS[info]}" "Module $(basename "$module") not supported on this system"
            continue
        fi
        if ! run_update; then
            print_warning "Module $(basename "$module") update failed"
        fi
    done < <(find "$SCRIPT_DIR/modules" -name "[1-4][0-9]-*.sh*" | sort)
    cleanup_sudo

    # Phase 2: User Modules (50-89)
    print_header "${ICONS[user]} USER UPDATE MODULES"
    while IFS= read -r module; do
        if [[ ! -x "$module" ]]; then
            continue
        fi
        
        # Check if this is a disabled module
        if [[ "$module" == *.disabled ]]; then
            print_disabled "User module disabled: $(basename "$module")"
            continue
        fi
        
        if [[ -n "$DRY_RUN" ]]; then
            print_status "${ICONS[user]}" "Would run user module: $(basename "$module")"
        else
            print_status "${ICONS[user]}" "Running user module: $(basename "$module")"
        fi
        
        if ! source "$module"; then
            print_warning "Module $(basename "$module") failed"
            continue
        fi
        if ! validate_module_type "$module" "$MODULE_TYPE" "user"; then
            print_error "Module validation failed for $(basename "$module")"
            cleanup_sudo
            exit 1
        fi
        if ! check_supported; then
            print_status "${ICONS[info]}" "Module $(basename "$module") not supported on this system"
            continue
        fi
        if ! run_update; then
            print_warning "Module $(basename "$module") update failed"
        fi
    done < <(find "$SCRIPT_DIR/modules" -name "[5-8][0-9]-*.sh*" | sort)
    cleanup_sudo

    # Phase 3: Post-update Status Modules (90+)
    print_header "${ICONS[info]} POST-UPDATE STATUS"
    while IFS= read -r module; do
        if [[ ! -x "$module" ]]; then
            continue
        fi
        
        # Check if this is a disabled module
        if [[ "$module" == *.disabled ]]; then
            print_disabled "Status module disabled: $(basename "$module")"
            continue
        fi
        
        if [[ -n "$DRY_RUN" ]]; then
            print_status "${ICONS[info]}" "Would run status module: $(basename "$module")"
        else
            print_status "${ICONS[info]}" "Running status module: $(basename "$module")"
        fi
        
        if ! source "$module"; then
            print_warning "Module $(basename "$module") failed"
            continue
        fi
        if ! validate_module_type "$module" "$MODULE_TYPE" "status"; then
            print_error "Module validation failed for $(basename "$module")"
            cleanup_sudo
            exit 1
        fi
        if ! check_supported; then
            print_status "${ICONS[info]}" "Module $(basename "$module") not supported on this system"
            continue
        fi
        if ! run_update; then
            print_warning "Module $(basename "$module") update failed"
        fi
    done < <(find "$SCRIPT_DIR/modules" -name "9[0-9]-*.sh*" | sort)
    cleanup_sudo

    if [[ -n "$DRY_RUN" ]]; then
        echo -e "\n${MAGENTA}${BOLD}════════════════════════════════════════════════════════════════${NC}"
        echo -e "${MAGENTA}${BOLD} ${ICONS[info]} DRY RUN COMPLETED - NO CHANGES WERE MADE ${NC}"
        echo -e "${MAGENTA}${BOLD}════════════════════════════════════════════════════════════════${NC}\n"
    else
        print_header "${ICONS[clock]} SYSTEM UPDATE COMPLETED AT $(date)"
    fi
    return 0
}

# Function to configure terminal preferences
configure_terminal() {
    local config_dir="$HOME/.config/update-arch"
    
    # Ensure config directory exists
    mkdir -p "$config_dir"
    
    # Run terminal configuration
    if ! configure_terminal_preferences; then
        print_error "Failed to configure terminal preferences"
        return 1
    fi
    
    # Reinitialize icons with new settings
    setup_icons
    
    return 0
}

# Help text
show_help() {
    cat << EOF
${CYAN}${BOLD}update-arch${NC}: Arch Linux System Update Script

${BOLD}Usage:${NC} update-arch [OPTIONS]

${BOLD}Options:${NC}
    ${GREEN}-h, --help${NC}        Show this help message
    ${GREEN}--version${NC}         Show version information
    ${GREEN}--configure-terminal${NC} Configure terminal preferences
    ${GREEN}--create-module${NC}    Create a new module from template
    ${GREEN}--dry-run${NC}         Show what would be updated without making changes
    ${GREEN}--run${NC}             Run the update process

${BOLD}Description:${NC}
This script performs system updates and maintenance tasks:
${CYAN}•${NC} System health checks
${CYAN}•${NC} Package updates (official repos and AUR)
${CYAN}•${NC} Orphaned package cleanup
${CYAN}•${NC} Optional Flatpak and oh-my-posh updates

For more information, see: ${BLUE}~/.local/share/update-arch/README.md${NC}
EOF
}

# Function to display version information
show_version() {
    echo "update-arch version $VERSION"
}

# Parse command line arguments
# Main execution logic
if [[ $# -eq 0 ]]; then
    show_help
    exit 0
fi

case "$1" in
    -h|--help)
        show_help
        exit 0
        ;;
    --version)
        show_version
        exit 0
        ;;
    --configure-terminal)
        configure_terminal
        exit $?
        ;;
    --create-module)
        shift # Remove --create-module from args
        exec "${SCRIPT_DIR}/create-module.sh" "$@"
        ;;
    --dry-run)
        export DRY_RUN=1
        main
        exit $?
        ;;
    --run)
        main
        ;;
    *)
        print_error "Unknown option: $1"
        echo -e "Use ${GREEN}--help${NC} for usage information"
        exit 1
        ;;
esac
