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

# Show help
type_cmd "./update.sh --help"
sleep 1
echo
./update.sh --help
sleep 3

# Show dry-run
echo
type_cmd "./update.sh --dry-run"
sleep 1
echo
./update.sh --dry-run
sleep 3

# Show actual update
echo
type_cmd "./update.sh --run --confirm"
sleep 1
echo
./update.sh --run --confirm
