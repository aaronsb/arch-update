#!/bin/bash
#
# Pre-flight checks run before any module executes.

check_system_health() {
    local script_dir="$1"

    if ! command -v print_header &>/dev/null; then
        # shellcheck disable=SC1091
        source "$script_dir/utils.sh"
    fi

    set_error_handlers
    print_header "${ICONS[info]} PERFORMING SYSTEM HEALTH CHECKS"

    check_network     || return 1
    check_disk_space  || return 1
    check_pacman_lock || return 1
    return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-}" in
        --check)
            check_system_health "$(dirname "$(readlink -f "$0")")"
            ;;
        -h|--help|"")
            cat << 'EOF'
system-check.sh: pre-flight health checks for update-arch.

Usage: ./system-check.sh <command>

Commands:
  --check        Run the health checks (network + disk space)
  -h, --help     Show this help

This script is normally sourced by update-arch and not invoked directly.
EOF
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
fi
