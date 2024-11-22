#!/bin/bash

# Color definitions
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Icons (nerdfonts)
INSTALL_ICON='' # nf-fa-download
SUCCESS_ICON='' # nf-fa-check
INFO_ICON='' # nf-fa-info_circle

# Header
echo -e "\n${BLUE}${BOLD}════════════════════════════════════════════════${NC}"
echo -e "${CYAN}${BOLD} ${INSTALL_ICON} INSTALLING SYSTEM UPDATE SCRIPT ${NC}"
echo -e "${BLUE}${BOLD}════════════════════════════════════════════════${NC}\n"

# Installation of update-arch script
echo -e "${CYAN}${INSTALL_ICON} Installing ${BOLD}update-arch${NC} to ${BOLD}/usr/local/bin${NC}..."
if sudo cp ./update.sh /usr/local/bin/update-arch && sudo chmod +x /usr/local/bin/update-arch; then
    echo -e "${GREEN}${SUCCESS_ICON} Installation successful${NC}"
    echo -e "${CYAN}${INFO_ICON} Use ${BOLD}update-arch${NC} command to update your system"
else
    echo -e "${RED}${ERROR_ICON} Installation failed${NC}"
    exit 1
fi
