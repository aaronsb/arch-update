#!/bin/bash

# Source utilities for consistent styling
source utils.sh

# Simulate typing with delays for better readability
type_cmd() {
    echo -n "$1"
    sleep 1
}

# Clear screen and show title
clear
print_header "Arch Linux Update Tool Demo"
sleep 2

# Deploy the update tool
clear
print_header "Deploy the update tool from the cloned repository"
sleep 2
echo
./deploy.sh
sleep 3

# Show help
clear
print_header "Basic usage"
sleep 2
type_cmd "./update.sh --help"
sleep 1
echo
./update.sh --help
sleep 3


# Show dry-run
clear
print_header "Dry-run mode"
sleep 2
echo
type_cmd "./update.sh --dry-run"
sleep 1
echo
./update.sh --dry-run
sleep 3
sudo -k

# Show actual update
clear
print_header "Actual update mode"
sleep 2
echo
type_cmd "./update.sh --run"
sleep 1
echo
./update.sh --run
sleep 3
sudo -k

# Create a new module from a template.
clear
print_header "Create a new module from a template with interactive dialogs"
sleep 2
echo
type_cmd "./update.sh --create-module"
sleep 1
echo
./update.sh --run
