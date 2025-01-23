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

# Icons for privilege levels
SUDO_ICON="🔐"
USER_ICON="👤"

# Set up error handling
set_error_handlers

main() {
    print_header "${CLOCK_ICON} SYSTEM UPDATE STARTED AT $(date)"
    
    # Initialize logging
    local LOGFILE=$(setup_logging)
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
    print_header "${SUDO_ICON} SYSTEM UPDATE MODULES"
    while IFS= read -r module; do
        if [[ ! -x "$module" ]]; then
            continue
        fi
        
        # Check if this is a disabled module
        if [[ "$module" == *.disabled ]]; then
            print_disabled "System module disabled: $(basename "$module")"
            continue
        fi
        
        print_status "${SUDO_ICON}" "Running system module with elevated privileges: $(basename "$module")"
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
            print_status "${INFO_ICON}" "Module $(basename "$module") not supported on this system"
            continue
        fi
        if ! run_update; then
            print_warning "Module $(basename "$module") update failed"
        fi
    done < <(find "$SCRIPT_DIR/modules" -name "[1-4][0-9]-*.sh*" | sort)
    cleanup_sudo

    # Phase 2: User Modules (50-89)
    print_header "${USER_ICON} USER UPDATE MODULES"
    while IFS= read -r module; do
        if [[ ! -x "$module" ]]; then
            continue
        fi
        
        # Check if this is a disabled module
        if [[ "$module" == *.disabled ]]; then
            print_disabled "User module disabled: $(basename "$module")"
            continue
        fi
        
        print_status "${USER_ICON}" "Running user module: $(basename "$module")"
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
            print_status "${INFO_ICON}" "Module $(basename "$module") not supported on this system"
            continue
        fi
        if ! run_update; then
            print_warning "Module $(basename "$module") update failed"
        fi
    done < <(find "$SCRIPT_DIR/modules" -name "[5-8][0-9]-*.sh*" | sort)
    cleanup_sudo

    # Phase 3: Post-update Status Modules (90+)
    print_header "${INFO_ICON} POST-UPDATE STATUS"
    while IFS= read -r module; do
        if [[ ! -x "$module" ]]; then
            continue
        fi
        
        # Check if this is a disabled module
        if [[ "$module" == *.disabled ]]; then
            print_disabled "Status module disabled: $(basename "$module")"
            continue
        fi
        
        print_status "${INFO_ICON}" "Running status module: $(basename "$module")"
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
            print_status "${INFO_ICON}" "Module $(basename "$module") not supported on this system"
            continue
        fi
        if ! run_update; then
            print_warning "Module $(basename "$module") update failed"
        fi
    done < <(find "$SCRIPT_DIR/modules" -name "9[0-9]-*.sh*" | sort)
    cleanup_sudo

    print_header "${CLOCK_ICON} SYSTEM UPDATE COMPLETED AT $(date)"
    # Final status
    echo "$LOGFILE"

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
