#!/bin/bash
#
# Arch Linux keyring update module
# Initializes and updates the pacman keyring
# Provides educational information about package signing and security

MODULE_TYPE="system"

# Source utils if not already sourced
if ! command -v print_header &>/dev/null; then
    source "$(dirname "$(dirname "$(readlink -f "$0")")")/utils.sh"
fi

check_supported() {
    # This module is supported on all Arch Linux systems
    return 0
}

run_update() {
    print_header "${KEY_ICON} UPDATING PACMAN KEYRING"
    
    # Educational output about package signing
    print_section_box \
        "About Package Signing" \
        "The pacman keyring ensures package authenticity\nPackage signing prevents malicious modifications" \
        "https://wiki.archlinux.org/title/Pacman/Package_signing"
    
    print_status "${KEY_ICON}" "Checking pacman keyring..."
    
    # Check keyring directory with explanation
    if [ ! -d "/etc/pacman.d/gnupg" ]; then
        print_info_box "Keyring directory not found at /etc/pacman.d/gnupg\nThis is normal for new installations"
        print_warning "Initializing new pacman keyring..."
        if ! sudo pacman-key --init; then
            print_error "Failed to initialize pacman keyring"
            print_info_box "Common issues:\n- Insufficient entropy for key generation\n- Disk space limitations\n- Permission problems in /etc/pacman.d"
            return 1
        fi
        print_success "Keyring initialized successfully"
    fi
    
    # Verify trustdb with explanation
    print_status "${SYNC_ICON}" "Verifying trust database..."
    if ! pacman-key --check-trustdb &>/dev/null; then
        print_warning "Trust database needs updating"
        print_info_box "This ensures all trusted keys are properly recorded"
        
        # Update keyring with explanation
        print_status "${SYNC_ICON}" "Populating keyring with official Arch Linux keys..."
        print_info_box "This adds trusted developer keys to your system"
        if ! sudo pacman-key --populate archlinux 2>&1 | sed \
            -e "s/\(.*\[GNUPG:] PROGRESS.*\)/${BLUE}\1${NC}/" \
            -e "s/\(.*\[GNUPG:] IMPORT_OK.*\)/${GREEN}\1${NC}/" \
            -e "s/\(.*\[GNUPG:] IMPORT_RES.*\)/${CYAN}\1${NC}/" \
            -e "s/\(.*gpg: key.*\)/${YELLOW}\1${NC}/" \
            -e "s/\(.*gpg: Total number.*\)/${MAGENTA}\1${NC}/"; then
            print_error "Failed to populate keyring"
            return 1
        fi
        
        # Refresh/update keys with explanation
        print_status "${SYNC_ICON}" "Refreshing keys from keyservers..."
        print_info_box "This updates existing keys with any revisions"
        if ! sudo pacman-key --refresh-keys 2>&1 | sed \
            -e "s/\(.*\[GNUPG:] PROGRESS.*\)/${BLUE}\1${NC}/" \
            -e "s/\(.*gpg: requesting key.*\)/${GREEN}\1${NC}/" \
            -e "s/\(.*gpg: key.*\)/${YELLOW}\1${NC}/" \
            -e "s/\(.*gpg: Total number.*\)/${MAGENTA}\1${NC}/" \
            -e "s/\(.*gpg: error.*\)/${RED}\1${NC}/"; then
            print_warning "Failed to refresh keys from keyservers"
            print_info_box "This is often temporary, will retry next update"
        fi
        
        # Verify trustdb again
        if ! pacman-key --check-trustdb &>/dev/null; then
            print_error "Trust database still invalid after update"
            print_info_box "Manual intervention may be required\nSee: https://wiki.archlinux.org/title/Pacman/Package_signing#Resetting_all_the_keys"
            return 1
        fi
    fi
    
    print_success "Pacman keyring verified and updated"
    return 0
}
