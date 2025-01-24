#!/bin/bash

# Source utils for common functions
source "$(dirname "$(readlink -f "$0")")/utils.sh"

# Constants
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
TEMPLATES_DIR="${SCRIPT_DIR}/templates"
MODULES_DIR="${SCRIPT_DIR}/modules"

# Help text
show_help() {
    cat << EOF
${CYAN}${BOLD}create-module${NC}: Create a new update-arch module from template

${BOLD}Usage:${NC} create-module [OPTIONS]

${BOLD}Options:${NC}
    ${GREEN}-h, --help${NC}        Show this help message
    ${GREEN}-t, --type${NC}        Module type (system|user|status)

${BOLD}Description:${NC}
Creates a new module from the appropriate template based on type:
${CYAN}•${NC} system  (10-49 range) - System-level maintenance tasks
${CYAN}•${NC} user    (50-89 range) - User-specific maintenance tasks
${CYAN}•${NC} status  (90+ range)   - System status display tasks

The script will interactively prompt for:
${CYAN}•${NC} Module name
${CYAN}•${NC} Module description
${CYAN}•${NC} Additional configuration options
EOF
}

# Function to get the next available number for a module type
get_next_module_number() {
    local type="$1"
    local pattern
    local start
    local end
    
    case "$type" in
        system)
            pattern="[1-4][0-9]"
            start=10
            end=49
            ;;
        user)
            pattern="[5-8][0-9]"
            start=50
            end=89
            ;;
        status)
            pattern="9[0-9]"
            start=90
            end=99
            ;;
        *)
            print_error "Invalid module type: $type"
            exit 1
            ;;
    esac
    
    # Get existing module numbers
    local existing_numbers=($(find "$MODULES_DIR" -maxdepth 1 -name "${pattern}-*.sh*" | sed -n "s/.*\/\([0-9]\+\).*/\1/p" | sort -n))
    
    # Find first available number in range
    local num=$start
    while [[ $num -le $end ]]; do
        if [[ ! " ${existing_numbers[@]} " =~ " ${num} " ]]; then
            echo "$num"
            return 0
        fi
        ((num++))
    done
    
    print_error "No available numbers in range $start-$end"
    exit 1
}

# Function to create module files from template
create_module() {
    local type="$1"
    local number="$2"
    local name="$3"
    local description="$4"
    
    # Validate inputs
    if [[ ! -d "${TEMPLATES_DIR}/${type}" ]]; then
        print_error "Template directory not found: ${TEMPLATES_DIR}/${type}"
        exit 1
    fi
    
    # Create module name with number prefix
    local module_base="${number}-${name}"
    local module_script="${MODULES_DIR}/${module_base}.sh"
    local module_doc="${MODULES_DIR}/${module_base}.md"
    
    # Copy templates
    cp "${TEMPLATES_DIR}/${type}/template.sh" "$module_script"
    cp "${TEMPLATES_DIR}/${type}/template.md" "$module_doc"
    
    # Replace placeholders in script
    sed -i "s/REPLACE_MODULE_NAME/${name}/g" "$module_script"
    sed -i "s/REPLACE_MODULE_NUMBER/${number}/g" "$module_script"
    sed -i "s/REPLACE_MODULE_DESCRIPTION/${description}/g" "$module_script"
    sed -i "s/REPLACE_HEADER_TEXT/${name^^}/g" "$module_script"
    
    # Replace placeholders in documentation
    sed -i "s/REPLACE_MODULE_NAME/${name}/g" "$module_doc"
    sed -i "s/REPLACE_MODULE_NUMBER/${number}/g" "$module_doc"
    
    # Make script executable
    chmod +x "$module_script"
    
    print_success "Created new ${type} module:"
    print_status "${INFO_ICON}" "Script: ${module_script}"
    print_status "${INFO_ICON}" "Documentation: ${module_doc}"
    
    # Git commit reminder
    echo -e "\n${CYAN}${BOLD}Next Steps:${NC}"
    echo -e "${CYAN}•${NC} Review and customize the module files"
    echo -e "${CYAN}•${NC} Test the module functionality"
    echo -e "${CYAN}•${NC} Commit your changes using semantic commit messages:"
    echo -e "  ${GREEN}git add ${module_script} ${module_doc}${NC}"
    echo -e "  ${GREEN}git commit -m 'feat: add ${name} module'${NC}"
    echo -e "\nCommit Message Prefixes:"
    echo -e "${YELLOW}• feat:${NC}     (new feature)"
    echo -e "${YELLOW}• fix:${NC}      (bug fix)"
    echo -e "${YELLOW}• docs:${NC}     (documentation changes)"
    echo -e "${YELLOW}• style:${NC}    (formatting, etc; no code change)"
    echo -e "${YELLOW}• refactor:${NC} (refactoring code)"
    echo -e "${YELLOW}• test:${NC}     (adding tests)"
    echo -e "${YELLOW}• chore:${NC}    (maintenance)"
    echo -e "${YELLOW}• stable:${NC}   (marking a functional stopping point)"
    
    # Deployment reminder
    echo -e "\n${CYAN}${BOLD}Deployment:${NC}"
    echo -e "${CYAN}•${NC} After testing and committing your changes, deploy your module using:"
    echo -e "  ${GREEN}./deploy.sh${NC}"
    echo -e "${CYAN}•${NC} This will properly install your module to the system-wide location"
}

# Main execution
main() {
    local module_type=""
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            -t|--type)
                module_type="$2"
                shift 2
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Validate module type
    if [[ ! "$module_type" =~ ^(system|user|status)$ ]]; then
        print_error "Invalid or missing module type"
        show_help
        exit 1
    fi
    
    # Get next available number
    local number=$(get_next_module_number "$module_type")
    
    # Interactive prompts
    print_header "${INFO_ICON} CREATE NEW ${module_type^^} MODULE"
    
    # Get module name
    echo -e "\n${CYAN}Enter module name (e.g., pacman-update):${NC}"
    read -r name
    if [[ -z "$name" ]]; then
        print_error "Module name cannot be empty"
        exit 1
    fi
    
    # Get module description
    echo -e "\n${CYAN}Enter module description:${NC}"
    read -r description
    if [[ -z "$description" ]]; then
        print_error "Module description cannot be empty"
        exit 1
    fi
    
    # Create the module
    create_module "$module_type" "$number" "$name" "$description"
}

# If script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
