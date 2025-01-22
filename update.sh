#!/bin/bash

source ./utils.sh
source ./system-check.sh
source ./package-update.sh
source ./log-manage.sh

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
    
    # Update packages
    if ! update_packages; then
        print_error "Package updates failed"
        kill $SUDO_REFRESH_PID
        exit 1
    fi
    
    # Update Flatpak if installed
    if command -v flatpak &>/dev/null; then
        print_header "${PACKAGE_ICON} UPDATING FLATPAK PACKAGES"
        if flatpak list | grep -q .; then
            print_status "${SYNC_ICON}" "Updating Flatpak packages..."
            if ! flatpak update -y; then
                print_warning "Failed to update Flatpak packages"
            else
                print_success "Flatpak packages updated successfully"
            fi
        else
            print_success "No Flatpak packages installed"
        fi
    fi
    
    # Update oh-my-posh if installed
    if command -v oh-my-posh &>/dev/null; then
        print_header "${SYNC_ICON} UPDATING OH-MY-POSH"
        if ! sudo oh-my-posh upgrade; then
            print_warning "Failed to update oh-my-posh"
        else
            print_success "oh-my-posh updated successfully"
        fi
    fi
    
    print_header "${CLOCK_ICON} SYSTEM UPDATE COMPLETED AT $(date)"
    
    # Final status
    print_status "${LOG_ICON}" "Log saved to: ${BOLD}$LOGFILE${NC}"
    print_status "${INFO_ICON}" "Please review the log for any potential issues"
    
    # Kill the background sudo refresh process
    kill $SUDO_REFRESH_PID
    
    # Run fastfetch if available
    if command -v fastfetch &>/dev/null; then
        print_header "${INFO_ICON} SYSTEM INFORMATION"
        fastfetch
    fi
    
    return 0
}

# Run main function
main
