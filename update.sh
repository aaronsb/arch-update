#!/bin/bash
#
# Arch Linux system update and maintenance script
# Performs system health checks, package updates, and maintenance tasks

# Source companion scripts
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
source "$SCRIPT_DIR/utils.sh"
source "$SCRIPT_DIR/system-check.sh"
source "$SCRIPT_DIR/log-manage.sh"

# Constants
VERSION="0.1.0"

# Icons for privilege levels
SUDO_ICON="🔐"
USER_ICON="👤"

# Set up error handling
set_error_handlers

main() {
    print_header "${CLOCK_ICON} SYSTEM UPDATE STARTED AT $(date)"
    
    # Initialize logging
    local LOGFILE=$(manage_logs)
    if [ -z "$LOGFILE" ]; then
        print_error "Failed to initialize logging"
        exit 1
    fi
    
    # Establish sudo session
    sudo -v
    if [ $? -ne 0 ]; then
        print_error "Failed to establish sudo session"
        exit 1
    fi
    
    # Keep sudo session alive
    ( while true; do sudo -v; sleep 60; done; ) &
    SUDO_REFRESH_PID=$!
    
    # Redirect output to log file while maintaining console output
    exec &> >(tee -a "$LOGFILE")
    
    # Perform system health checks
    if ! check_system_health; then
        print_error "System health checks failed"
        kill $SUDO_REFRESH_PID
        exit 1
    fi
    
    # Phase 1: System Modules (10-49)
    print_header "${SUDO_ICON} SYSTEM UPDATE MODULES"
    while IFS= read -r module; do
        if [[ -x "$module" ]]; then
            print_status "${SUDO_ICON}" "Running system module with elevated privileges: $(basename "$module")"
            if ! source "$module"; then
                print_warning "Module $(basename "$module") failed"
                continue
            fi
            if ! validate_module_type "$module" "$MODULE_TYPE" "system"; then
                exit 1
            fi
            if ! check_supported; then
                print_status "${INFO_ICON}" "Module $(basename "$module") not supported on this system"
                continue
            fi
            if ! run_update; then
                print_warning "Module $(basename "$module") update failed"
            fi
        fi
    done < <(find "$SCRIPT_DIR/modules" -name "[1-4][0-9]-*.sh" | sort)
    kill $SUDO_REFRESH_PID

    # Phase 2: User Modules (50-89)
    print_header "${USER_ICON} USER UPDATE MODULES"
    while IFS= read -r module; do
        if [[ -x "$module" ]]; then
            print_status "${USER_ICON}" "Running user module: $(basename "$module")"
            if ! source "$module"; then
                print_warning "Module $(basename "$module") failed"
                continue
            fi
            if ! validate_module_type "$module" "$MODULE_TYPE" "user"; then
                exit 1
            fi
            if ! check_supported; then
                print_status "${INFO_ICON}" "Module $(basename "$module") not supported on this system"
                continue
            fi
            if ! run_update; then
                print_warning "Module $(basename "$module") update failed"
            fi
        fi
    done < <(find "$SCRIPT_DIR/modules" -name "[5-8][0-9]-*.sh" | sort)
    kill $SUDO_REFRESH_PID

    # Phase 3: Post-update Status Modules (90+)
    print_header "${INFO_ICON} POST-UPDATE STATUS"
    while IFS= read -r module; do
        if [[ -x "$module" ]]; then
            print_status "${INFO_ICON}" "Running status module: $(basename "$module")"
            if ! source "$module"; then
                print_warning "Module $(basename "$module") failed"
                continue
            fi
            if ! validate_module_type "$module" "$MODULE_TYPE" "status"; then
                exit 1
            fi
            if ! check_supported; then
                print_status "${INFO_ICON}" "Module $(basename "$module") not supported on this system"
                continue
            fi
            if ! run_update; then
                print_warning "Module $(basename "$module") update failed"
            fi
        fi
    done < <(find "$SCRIPT_DIR/modules" -name "9[0-9]-*.sh" | sort)
    kill $SUDO_REFRESH_PID

    print_header "${CLOCK_ICON} SYSTEM UPDATE COMPLETED AT $(date)"
    
    # Final status
    print_status "${LOG_ICON}" "Log saved to: ${BOLD}$LOGFILE${NC}"
    print_status "${INFO_ICON}" "Please review the log for any potential issues"
    
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
    ${GREEN}--dry-run${NC}         Show what would be updated without making changes
    ${GREEN}--run${NC}             Run the update process

${BOLD}Description:${NC}
This script performs system updates and maintenance tasks:
${CYAN}•${NC} System health checks
${CYAN}•${NC} Package updates (official repos and AUR)
${CYAN}•${NC} Orphaned package cleanup
${CYAN}•${NC} Log management
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
    --dry-run)
        # TODO: Implement dry run functionality
        echo "Dry run functionality not yet implemented"
        exit 1
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
