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
INFO_ICON='' # nf-fa-info_circle
SUCCESS_ICON='' # nf-fa-check
WARNING_ICON='' # nf-fa-warning
ERROR_ICON='' # nf-fa-times_circle
PACKAGE_ICON='' # nf-fa-cube
TRASH_ICON='' # nf-fa-trash
CLOCK_ICON='' # nf-fa-clock_o
LOG_ICON='' # nf-fa-file_text
SYNC_ICON='󰁪' # nf-md-sync

# Progress tracking
TOTAL_STAGES=6
CURRENT_STAGE=0

# Helper functions
print_progress() {
    CURRENT_STAGE=$((CURRENT_STAGE + 1))
    PROGRESS=$((CURRENT_STAGE * 100 / TOTAL_STAGES))
    BAR_WIDTH=50
    FILLED_WIDTH=$((BAR_WIDTH * PROGRESS / 100))
    EMPTY_WIDTH=$((BAR_WIDTH - FILLED_WIDTH))
    
    printf "\n${BLUE}[Stage %d/%d]${NC} %s\n" "$CURRENT_STAGE" "$TOTAL_STAGES" "$1"
    printf "${CYAN}[${NC}"
    printf "%${FILLED_WIDTH}s" | tr ' ' '█'
    printf "%${EMPTY_WIDTH}s" | tr ' ' '░'
    printf "${CYAN}]${NC} ${BOLD}%d%%${NC}\n\n" "$PROGRESS"
}

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
}

# Establish sudo rights
sudo -v

# Define the log file location
LOGFILE="/var/log/system_update_$(date +'%Y%m%d_%H%M%S').log"

# Create the log file
print_status "${LOG_ICON}" "Creating new log file: ${BOLD}$LOGFILE${NC}"

sudo touch "$LOGFILE"
if [ $? -ne 0 ]; then
    print_error "Failed to create log file: $LOGFILE"
    exit 1
fi

# Log the entire script's output
exec > >(sudo tee -a "$LOGFILE") 2>&1

# Keep sudo session alive
( while true; do sudo -v; sleep 60; done; ) &
SUDO_REFRESH_PID=$!

print_header "${CLOCK_ICON} SYSTEM UPDATE STARTED AT $(date)"

# System update via yay (handles both official and AUR packages)
print_progress "Updating System Packages"
print_header "${PACKAGE_ICON} UPDATING SYSTEM AND AUR PACKAGES"
print_status "${SYNC_ICON}" "Running system update..."
if yay -Syu --noconfirm --color=always; then
    print_success "System and AUR packages updated successfully"
else
    print_error "Error updating packages"
fi

# Remove orphaned packages
print_progress "Checking Orphaned Packages"
print_header "${TRASH_ICON} CHECKING FOR ORPHANED PACKAGES"
orphans=$(pacman -Qdtq)
if [[ ! -z $orphans ]]; then
    print_warning "Found orphaned packages. Removing..."
    if sudo pacman -Rns $orphans --noconfirm; then
        print_success "Orphaned packages removed successfully"
    else
        print_error "Error removing orphaned packages"
    fi
else
    print_success "No orphaned packages found"
fi

# Clean package cache
print_progress "Cleaning Package Cache"
print_header "${TRASH_ICON} CLEANING PACKAGE CACHE"
print_status "${SYNC_ICON}" "Cleaning package cache (keeping last 3 versions)..."
if sudo paccache -r; then
    print_success "Package cache cleaned successfully"
else
    print_error "Error cleaning package cache"
fi

# Update Flatpak packages
print_progress "Updating Flatpak Packages"
print_header "${PACKAGE_ICON} CHECKING FLATPAK PACKAGES"
flatpaklist=$(flatpak list)
if [[ -n "$flatpaklist" ]]; then
    print_status "${SYNC_ICON}" "Updating Flatpak packages..."
    if flatpak update -y; then
        print_success "Flatpak packages updated successfully"
    else
        print_error "Error updating Flatpak packages"
    fi
else
    print_success "No Flatpak packages installed"
fi

# Vacuum system logs
print_progress "Cleaning System Logs"
print_header "${TRASH_ICON} CLEANING SYSTEM LOGS"
print_status "${SYNC_ICON}" "Removing logs older than 2 weeks..."
if sudo journalctl --vacuum-time=2weeks; then
    print_success "System logs cleaned successfully"
else
    print_error "Error cleaning system logs"
fi

# Update oh-my-posh
print_progress "Updating Oh-My-Posh"
print_header "${SYNC_ICON} UPDATING OH-MY-POSH"
if sudo oh-my-posh upgrade; then
    print_success "oh-my-posh updated successfully"
else
    print_error "Error updating oh-my-posh"
fi

# Run fastfetch
print_header "${INFO_ICON} SYSTEM INFORMATION"
fastfetch

print_header "${CLOCK_ICON} SYSTEM UPDATE COMPLETED AT $(date)"

# Final status
print_status "${LOG_ICON}" "Log saved to: ${BOLD}$LOGFILE${NC}"
print_status "${INFO_ICON}" "Please review the log for any potential issues"

# Kill the background sudo refresh process
kill $SUDO_REFRESH_PID
