#!/bin/bash

# Establish sudo rights.
sudo -v

# Define the log file location
LOGFILE="/var/log/system_update_$(date +'%Y%m%d_%H%M%S').log"

# Create the log file explicitly to ensure it exists and has correct permissions
echo "Creating new log file: $LOGFILE"

sudo touch "$LOGFILE"
if [ $? -ne 0 ]; then
    echo "Failed to create log file: $LOGFILE"
    exit
fi

# Log the entire script's output to a log file, while displaying it in real time
exec > >(sudo tee -a "$LOGFILE") 2>&1

# Keep the sudo session alive by refreshing it every minute in the background
# This prevents the sudo session from timing out during long operations
( while true; do sudo -v; sleep 60; done; ) &

# Store the PID of the background sudo refresh process to kill it later
SUDO_REFRESH_PID=$!

# Inform the user that the process is starting
echo "Starting system update at $(date)..."

# System update via pacman and yay
sudo pacman -Syu --noconfirm

# Remove orphaned packages if they exist
orphans=$(pacman -Qdtq)
if [[ ! -z $orphans ]]; then
    echo "Removing orphaned packages..."
    sudo pacman -Rns $orphans --noconfirm
else
    echo "No orphaned packages to remove."
fi

# Clean package cache with paccache, keeping last 3 versions
echo "Cleaning package cache (keeping last 3 versions of each package)..."
sudo paccache -r

# Optional: Skipping cache clearing with pacman -Scc (see concerns about package recovery)
# sudo pacman -Scc --noconfirm

# Update Flatpak packages
flatpaklist=$(flatpak list)
if [[ -n "$flatpaklist" ]]; then
    echo "Flatpak packages are installed. Proceeding with update..."
    flatpak update -y
else
    echo "No Flatpak packages are installed."
fi

# Update AUR packages via yay
echo "Updating AUR packages..."
yay -Syu --noconfirm

# Vacuum system logs older than 2 weeks
echo "Cleaning system logs older than 2 weeks..."
sudo journalctl --vacuum-time=2weeks

#update oh-my-posh
sudo oh-my-posh upgrade

# Run fastfetch (replacing `fafe`)
echo "Running fastfetch to display system info..."
fastfetch

# Notify the user that the process is complete
echo "System update complete at $(date)."

# Instructions to review the log
echo "Log saved to $LOGFILE. Please review for any potential issues."

# Kill the background sudo refresh process
kill $SUDO_REFRESH_PID
