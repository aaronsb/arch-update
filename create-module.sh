#!/bin/bash
#
# Create a new update-arch module from the appropriate template.

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
source "$SCRIPT_DIR/utils.sh"

TEMPLATES_DIR="${SCRIPT_DIR}/templates"
MODULES_DIR="${SCRIPT_DIR}/modules"

show_help() {
    cat << EOF
${CYAN}${BOLD}create-module${NC}: Create a new update-arch module from template

${BOLD}Usage:${NC} create-module -t <type>

${BOLD}Types:${NC}
  ${GREEN}system${NC}  (10-49) — system-level maintenance (may use sudo)
  ${GREEN}user${NC}    (50-89) — user-specific maintenance (no sudo)
  ${GREEN}status${NC}  (90-99) — post-update status display (read-only)

The script interactively prompts for name and description, then creates
both the module script and its .md doc from the matching template.
EOF
}

get_next_module_number() {
    local type="$1" start end
    case "$type" in
        system) start=10; end=49 ;;
        user)   start=50; end=89 ;;
        status) start=90; end=99 ;;
        *)      print_error "Invalid module type: $type"; exit 1 ;;
    esac

    local used
    used=$(find "$MODULES_DIR" -maxdepth 1 -name '[0-9][0-9]-*' \
        | sed -n 's|.*/\([0-9]\{2\}\)-.*|\1|p' | sort -u)

    local n
    for (( n=start; n<=end; n++ )); do
        grep -qx "$(printf '%02d' "$n")" <<< "$used" || { printf '%02d' "$n"; return 0; }
    done
    print_error "No available numbers in range $start-$end"
    exit 1
}

create_module() {
    local type="$1" number="$2" name="$3" description="$4"

    local tdir="${TEMPLATES_DIR}/${type}"
    if [[ ! -d "$tdir" ]]; then
        print_error "Template directory not found: $tdir"
        exit 1
    fi

    local base="${number}-${name}"
    local script="${MODULES_DIR}/${base}.sh"
    local doc="${MODULES_DIR}/${base}.md"

    cp "${tdir}/template.sh" "$script"
    [[ -f "${tdir}/template.md" ]] && cp "${tdir}/template.md" "$doc"

    local upper
    upper=$(tr '[:lower:]' '[:upper:]' <<< "$name")

    sed -i \
        -e "s/REPLACE_MODULE_NAME/${name}/g" \
        -e "s/REPLACE_MODULE_NUMBER/${number}/g" \
        -e "s/REPLACE_MODULE_DESCRIPTION/${description}/g" \
        -e "s/REPLACE_HEADER_TEXT/${upper}/g" \
        "$script"

    [[ -f "$doc" ]] && sed -i \
        -e "s/REPLACE_MODULE_NAME/${name}/g" \
        -e "s/REPLACE_MODULE_NUMBER/${number}/g" \
        "$doc"

    chmod +x "$script"

    print_success "Created ${type} module:"
    print_status "${ICONS[info]}" "Script: $script"
    [[ -f "$doc" ]] && print_status "${ICONS[info]}" "Docs:   $doc"

    cat << EOF

${CYAN}${BOLD}Next steps${NC}
  ${CYAN}•${NC} Edit ${script#"$SCRIPT_DIR/"} — fill in MODULE_REQUIRES and run_update
  ${CYAN}•${NC} Test: ${GREEN}update-arch --only ${name}${NC}
  ${CYAN}•${NC} Commit: ${GREEN}git add ${script#"$SCRIPT_DIR/"} && git commit -m 'feat: add ${name} module'${NC}
  ${CYAN}•${NC} Deploy: ${GREEN}./deploy.sh${NC}
EOF
}

main() {
    if [[ $# -eq 0 ]]; then
        show_help
        exit 0
    fi

    local module_type=""
    while (( $# > 0 )); do
        case "$1" in
            -h|--help) show_help; exit 0 ;;
            -t|--type) module_type="$2"; shift 2 ;;
            *)         print_error "Unknown option: $1"; show_help; exit 1 ;;
        esac
    done

    if [[ ! "$module_type" =~ ^(system|user|status)$ ]]; then
        print_error "Invalid or missing module type"
        show_help
        exit 1
    fi

    local number
    number=$(get_next_module_number "$module_type")

    local upper_type
    upper_type=$(tr '[:lower:]' '[:upper:]' <<< "$module_type")
    print_header "${ICONS[info]} CREATE NEW ${upper_type} MODULE"

    echo -e "\n${CYAN}Module name (e.g., pacman-update):${NC}"
    local name
    read -r name
    [[ -z "$name" ]] && { print_error "Module name cannot be empty"; exit 1; }

    echo -e "\n${CYAN}Module description:${NC}"
    local description
    read -r description
    [[ -z "$description" ]] && { print_error "Module description cannot be empty"; exit 1; }

    create_module "$module_type" "$number" "$name" "$description"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
