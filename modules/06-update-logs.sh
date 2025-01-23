#!/bin/bash
#
# Arch Linux update logs cleanup module
# Manages and rotates system update logs
# Provides educational information about update logging

MODULE_TYPE="system"

# Source utils if not already sourced
if ! command -v print_header &>/dev/null; then
    source "$(dirname "$(dirname "$(readlink -f "$0")")")/utils.sh"
fi

check_supported() {
    # Check if update logs directory exists
    if [ ! -d "/var/log/system_updates" ]; then
        return 1
    fi
    return 0
}

run_update() {
    print_header "${SYNC_ICON} MAINTAINING UPDATE LOGS"
    
    # Educational output about update logs
    print_status "${INFO_ICON}" "Update logs track system maintenance history"
    print_status "${INFO_ICON}" "Regular cleanup ensures efficient disk usage"
    print_status "${INFO_ICON}" "Learn more: https://wiki.archlinux.org/title/System_maintenance#System_log"
    
    local update_logs="/var/log/system_updates"
    local max_logs=5
    
    # Check directory permissions
    if [ ! -w "$update_logs" ]; then
        print_error "Update logs directory is not writable"
        print_status "${INFO_ICON}" "Fix permissions: sudo chown -R root:root $update_logs"
        return 1
    fi
    
    # Get current log count
    print_status "${SYNC_ICON}" "Checking update logs..."
    local total_logs=$(ls -1 "$update_logs" | wc -l)
    print_status "${INFO_ICON}" "Current logs: $total_logs"
    print_status "${INFO_ICON}" "Maximum logs: $max_logs"
    
    # Clean old logs if needed
    if [ "$total_logs" -gt "$max_logs" ]; then
        print_status "${SYNC_ICON}" "Cleaning old update logs..."
        print_status "${INFO_ICON}" "Preserving last $max_logs logs"
        
        # Get list of old logs to remove
        local excess_logs=$(ls -1t "$update_logs" | tail -n +"$((max_logs + 1))")
        if [ ! -z "$excess_logs" ]; then
            # Create archive directory if needed
            local archive_dir="${update_logs}/archive"
            if [ ! -d "$archive_dir" ]; then
                if ! sudo mkdir -p "$archive_dir"; then
                    print_warning "Failed to create archive directory"
                fi
            fi
            
            # Process each old log
            echo "$excess_logs" | while read log; do
                print_status "${INFO_ICON}" "Processing: $log"
                if [ -d "$archive_dir" ]; then
                    # Archive the log if possible
                    if ! sudo mv "$update_logs/$log" "$archive_dir/"; then
                        print_warning "Failed to archive log: $log"
                        # Try to remove if archiving fails
                        sudo rm "$update_logs/$log"
                    fi
                else
                    # Remove directly if no archive
                    if ! sudo rm "$update_logs/$log"; then
                        print_warning "Failed to remove log: $log"
                    fi
                fi
            done
            print_success "Old update logs cleaned"
        fi
    else
        print_success "Log count within limits ($total_logs <= $max_logs)"
    fi
    
    # Show log statistics
    print_status "${INFO_ICON}" "Log management tips:"
    print_status "${INFO_ICON}" "- View latest log: ls -lt $update_logs | head -n 2"
    print_status "${INFO_ICON}" "- Check archived logs: ls -l $update_logs/archive"
    print_status "${INFO_ICON}" "- Search updates: grep 'upgraded' $update_logs/*"
    
    return 0
}

# If script is run directly, check support and run
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if check_supported; then
        run_update
    else
        echo "Update logs directory not found"
        exit 1
    fi
fi
