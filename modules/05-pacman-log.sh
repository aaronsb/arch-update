#!/bin/bash
#
# Arch Linux pacman log rotation module
# Rotates pacman log file when it grows too large
# Provides educational information about package management logging

MODULE_TYPE="system"

# Source utils if not already sourced
if ! command -v print_header &>/dev/null; then
    source "$(dirname "$(dirname "$(readlink -f "$0")")")/utils.sh"
fi

check_supported() {
    # Check if pacman log exists
    if [ ! -f "/var/log/pacman.log" ]; then
        return 1
    fi
    return 0
}

run_update() {
    print_header "${SYNC_ICON} MAINTAINING PACMAN LOGS"
    
    # Educational output about pacman logs
    print_section_box \
        "About Pacman Logs" \
        "Pacman logs track all package operations\nRegular rotation prevents excessive disk usage" \
        "https://wiki.archlinux.org/title/Pacman#Logging"
    
    local pacman_log="/var/log/pacman.log"
    local max_size=10240  # 10MB in KB
    
    # Check log permissions
    if [ ! -w "$(dirname "$pacman_log")" ]; then
        print_error "Log directory is not writable"
        print_info_box "Fix permissions: sudo chown -R root:root /var/log"
        return 1
    fi
    
    # Get current log size
    print_status "${SYNC_ICON}" "Checking log size..."
    local log_size=$(du -k "$pacman_log" | cut -f1)
    print_status "${INFO_ICON}" "Current size: ${log_size}KB"
    print_status "${INFO_ICON}" "Maximum size: ${max_size}KB (10MB)"
    
    # Check if rotation needed
    if [ "$log_size" -gt "$max_size" ]; then
        print_status "${SYNC_ICON}" "Log exceeds maximum size, rotating..."
        
        # Backup existing old log if present
        if [ -f "${pacman_log}.old" ]; then
            print_status "${INFO_ICON}" "Archiving previous log rotation..."
            if ! sudo mv "${pacman_log}.old" "${pacman_log}.old.1"; then
                print_warning "Failed to archive old log, continuing anyway"
            fi
        fi
        
        # Rotate current log
        if ! sudo mv "$pacman_log" "${pacman_log}.old"; then
            print_error "Failed to rotate pacman log"
            print_info_box "Common issues:\n- Insufficient permissions\n- Disk space limitations\n- File system errors"
            return 1
        fi
        
        # Create new log file
        if ! sudo touch "$pacman_log"; then
            print_error "Failed to create new log file"
            return 1
        fi
        
        print_success "Log rotated successfully"
        print_status "${INFO_ICON}" "Previous log saved as: ${pacman_log}.old"
    else
        print_success "Log size within limits (${log_size}KB < ${max_size}KB)"
    fi
    
    # Show log statistics
    print_info_box "Log management tips:\n- View recent activity: tail -n 50 $pacman_log\n- Search operations: grep 'upgraded' $pacman_log\n- Check removals: grep 'removed' $pacman_log"
    
    return 0
}

# If script is run directly, check support and run
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if check_supported; then
        run_update
    else
        echo "Pacman log not found"
        exit 1
    fi
fi
