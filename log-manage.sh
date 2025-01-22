#!/bin/bash

source ./utils.sh

# Set up error handling
set_error_handlers

manage_logs() {
    print_header "${LOG_ICON} MANAGING SYSTEM LOGS"
    
    # Set up logging for current session
    local LOGFILE=$(setup_logging)
    if [ -z "$LOGFILE" ]; then
        print_error "Failed to set up logging"
        return 1
    fi
    print_status "${LOG_ICON}" "Created log file: ${BOLD}$LOGFILE${NC}"
    
    # Clean old system journals
    print_status "${TRASH_ICON}" "Cleaning system journals..."
    if ! sudo journalctl --vacuum-time=2weeks --vacuum-size=500M; then
        print_warning "Failed to clean system journals"
    else
        print_success "System journals cleaned"
    fi
    
    # Get current journal disk usage
    local journal_size=$(du -sh /var/log/journal 2>/dev/null | cut -f1)
    if [ ! -z "$journal_size" ]; then
        print_status "${INFO_ICON}" "Current journal size: $journal_size"
    fi
    
    # Check and rotate pacman log if it's too large
    local pacman_log="/var/log/pacman.log"
    if [ -f "$pacman_log" ]; then
        local log_size=$(du -k "$pacman_log" | cut -f1)
        if [ "$log_size" -gt 10240 ]; then  # 10MB in KB
            print_status "${SYNC_ICON}" "Rotating pacman log..."
            if ! sudo mv "$pacman_log" "$pacman_log.old"; then
                print_warning "Failed to rotate pacman log"
            else
                sudo touch "$pacman_log"
                print_success "Pacman log rotated"
            fi
        fi
    fi
    
    # Clean old update logs
    local update_logs="/var/log/system_updates"
    if [ -d "$update_logs" ]; then
        print_status "${SYNC_ICON}" "Cleaning old update logs..."
        # Keep only last 5 logs
        local excess_logs=$(ls -1t "$update_logs" | tail -n +6)
        if [ ! -z "$excess_logs" ]; then
            echo "$excess_logs" | while read log; do
                if ! sudo rm "$update_logs/$log"; then
                    print_warning "Failed to remove old log: $log"
                fi
            done
            print_success "Old update logs cleaned"
        else
            print_success "No old update logs to clean"
        fi
    fi
    
    echo "$LOGFILE"
    return 0
}

# Run log management if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    manage_logs
fi
