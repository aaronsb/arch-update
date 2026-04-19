#!/bin/bash
#
# Module runtime: discovery, validation, dispatch, and introspection.
# Sourced by utils.sh — relies on its print helpers, ICONS, and UPDATE_ARCH_*
# paths, so this file is never loaded on its own.
#
# Module contract:
#   MODULE_TYPE         - "system" | "user" | "status" (required)
#   MODULE_NAME         - display name (default: filename stem)
#   MODULE_DESCRIPTION  - one-line summary (shown in --list)
#   MODULE_REQUIRES     - space-separated commands that must exist on PATH
#   MODULE_DRY_RUN_SAFE - "true" | "false" (default: "true")
#   run_update()        - required, does the actual work
#   check_supported()   - optional; auto-derived from MODULE_REQUIRES
#
# Lifecycle (run_module):
#   1. Source the module in a subshell (isolates state and traps).
#   2. Validate MODULE_TYPE matches the expected phase.
#   3. Confirm run_update is defined.
#   4. Auto-derive check_supported if the module didn't override it.
#   5. Dispatch check_supported, then run_update.

validate_module_type() {
    local module="$1" declared="$2" expected="$3"
    if [[ "$declared" != "$expected" ]]; then
        print_error "Module $(basename "$module"): MODULE_TYPE='$declared' but placed in '$expected' phase"
        print_error "Move the module to the correct number range or fix MODULE_TYPE"
        return 1
    fi
    return 0
}

# Map the numeric prefix (NN-name.sh) back to the expected phase name.
# Ranges match update.sh's run_phase find patterns — keep them in sync or
# modules become orphaned (probe_module flags this as ORPHAN).
module_expected_phase() {
    local base="$1"
    local num="${base:0:2}"
    [[ "$num" =~ ^[0-9][0-9]$ ]] || { echo ""; return; }
    if   (( 10#$num >= 0  && 10#$num <= 49 )); then echo "system"
    elif (( 10#$num >= 50 && 10#$num <= 89 )); then echo "user"
    elif (( 10#$num >= 90 && 10#$num <= 99 )); then echo "status"
    else echo ""
    fi
}

run_module() {
    local module="$1" expected_phase="$2"
    local base
    base=$(basename "$module")

    if [[ ! -r "$module" ]]; then
        print_warning "Module not readable: $base"
        return 1
    fi

    (
        set +e
        MODULE_TYPE=""
        MODULE_NAME=""
        MODULE_DESCRIPTION=""
        MODULE_REQUIRES=""
        MODULE_DRY_RUN_SAFE="true"
        unset -f check_supported run_update 2>/dev/null

        # shellcheck disable=SC1090
        if ! source "$module"; then
            print_warning "Module $base failed to load"
            exit 1
        fi

        if [[ -z "$MODULE_TYPE" ]]; then
            print_error "Module $base: missing MODULE_TYPE"
            exit 1
        fi
        validate_module_type "$module" "$MODULE_TYPE" "$expected_phase" || exit 1

        if ! declare -F run_update >/dev/null; then
            print_error "Module $base: no run_update() defined"
            exit 1
        fi

        if ! declare -F check_supported >/dev/null; then
            check_supported() {
                local req
                for req in $MODULE_REQUIRES; do
                    command -v "$req" &>/dev/null || return 1
                done
                return 0
            }
        fi

        if ! check_supported; then
            print_status "${ICONS[info]}" "Module $base not supported on this system"
            exit 0
        fi

        if [[ -n "$DRY_RUN" && "$MODULE_DRY_RUN_SAFE" != "true" ]]; then
            print_status "${ICONS[info]}" "Module $base not dry-run safe; skipping"
            exit 0
        fi

        run_update
    )
    local rc=$?
    [[ $rc -ne 0 ]] && print_warning "Module $base exited with status $rc"
    return 0
}

# Emit: base \t type \t desc \t requires
module_metadata() {
    local module="$1"
    (
        set +e
        MODULE_TYPE=""
        MODULE_NAME=""
        MODULE_DESCRIPTION=""
        MODULE_REQUIRES=""
        # shellcheck disable=SC1090
        source "$module" 2>/dev/null || exit 0
        local base
        base=$(basename "$module" .sh)
        printf '%s\t%s\t%s\t%s\n' \
            "$base" \
            "${MODULE_TYPE:-?}" \
            "${MODULE_DESCRIPTION:-(no description)}" \
            "${MODULE_REQUIRES:-}"
    )
}

# Probe a module and emit: base \t type \t desc \t status \t reason
# Status is one of OK | SKIP | INVALID.
probe_module() {
    local module="$1"
    (
        set +e
        MODULE_TYPE=""
        MODULE_NAME=""
        MODULE_DESCRIPTION=""
        MODULE_REQUIRES=""
        unset -f check_supported run_update 2>/dev/null

        local base type desc emit
        base=$(basename "$module" .sh)
        emit() { printf '%s\t%s\t%s\t%s\t%s\n' "$base" "$1" "$2" "$3" "$4"; }

        # shellcheck disable=SC1090
        source "$module" 2>/dev/null || { emit "?" "(failed to source)" "INVALID" "source error"; exit 0; }

        type="${MODULE_TYPE:-?}"
        desc="${MODULE_DESCRIPTION:-(no description)}"

        [[ -z "$MODULE_TYPE" ]] && { emit "?" "$desc" "INVALID" "missing MODULE_TYPE"; exit 0; }

        local expected
        expected=$(module_expected_phase "$base")
        if [[ -z "$expected" ]]; then
            # Unreachable: no phase's find pattern will pick this up.
            emit "$type" "$desc" "ORPHAN" "prefix '${base:0:2}' outside any phase range (00-99)"
            exit 0
        fi
        if [[ "$expected" != "$MODULE_TYPE" ]]; then
            emit "$type" "$desc" "INVALID" "MODULE_TYPE=$MODULE_TYPE but number prefix implies $expected"
            exit 0
        fi

        declare -F run_update >/dev/null \
            || { emit "$type" "$desc" "INVALID" "no run_update() defined"; exit 0; }

        if ! declare -F check_supported >/dev/null; then
            check_supported() {
                local req
                for req in $MODULE_REQUIRES; do
                    command -v "$req" &>/dev/null || return 1
                done
                return 0
            }
        fi

        if check_supported 2>/dev/null; then
            emit "$type" "$desc" "OK" ""
        else
            local missing="" req
            for req in $MODULE_REQUIRES; do
                command -v "$req" &>/dev/null || missing+=" $req"
            done
            missing="${missing# }"
            if [[ -n "$missing" ]]; then
                emit "$type" "$desc" "SKIP" "missing: $missing"
            else
                emit "$type" "$desc" "SKIP" "check_supported returned non-zero"
            fi
        fi
    )
}

list_modules() {
    local modules_dir="$1"
    printf "%-28s %-8s %s\n" "MODULE" "TYPE" "DESCRIPTION"
    printf "%-28s %-8s %s\n" "------" "----" "-----------"
    local f name type desc
    while IFS= read -r f; do
        IFS=$'\t' read -r name type desc _ < <(module_metadata "$f")
        printf "%-28s %-8s %s\n" "$name" "$type" "$desc"
    done < <(find "$modules_dir" -maxdepth 1 -name "*.sh" | sort)
}

# Emit a formatted lamp-check line with status icon.
_lamp_line() {
    local status="$1" msg="$2"
    case "$status" in
        OK)   printf '  %s %s\n' "${GREEN}${ICONS[success]}${NC}" "$msg" ;;
        SKIP) printf '  %s %s\n' "${MAGENTA}${ICONS[disabled]}${NC}" "$msg" ;;
        WARN) printf '  %s %s\n' "${YELLOW}${ICONS[warning]}${NC}" "$msg" ;;
        FAIL) printf '  %s %s\n' "${RED}${ICONS[error]}${NC}" "$msg" ;;
    esac
}

# Lamp-check: like the dashboard indicator test in a vehicle. Lights every
# module and environment check once to show the instrumentation works. Does
# not run any modules and does not perform maintenance.
run_self_test() {
    local modules_dir="$1"
    local failures=0 warnings=0

    print_header "${ICONS[info]} update-arch lamp-check"

    echo "${BOLD}Environment${NC}"

    if [[ ":$PATH:" == *":$UPDATE_ARCH_BIN_DIR:"* ]]; then
        _lamp_line OK "PATH contains $UPDATE_ARCH_BIN_DIR"
    else
        _lamp_line WARN "$UPDATE_ARCH_BIN_DIR not in PATH"
        ((warnings++))
    fi

    local pair label dir
    for pair in "DATA:$UPDATE_ARCH_DATA_DIR" \
                "CONFIG:$UPDATE_ARCH_CONFIG_DIR" \
                "STATE:$UPDATE_ARCH_STATE_DIR" \
                "CACHE:$UPDATE_ARCH_CACHE_DIR"; do
        label="${pair%%:*}"; dir="${pair#*:}"
        if [[ -d "$dir" && -w "$dir" ]]; then
            _lamp_line OK "${label} dir writable: $dir"
        elif [[ ! -d "$dir" ]]; then
            _lamp_line WARN "${label} dir missing (will be created on first use): $dir"
            ((warnings++))
        else
            _lamp_line FAIL "${label} dir exists but is not writable: $dir"
            ((failures++))
        fi
    done

    if ( exec 9>"$UPDATE_ARCH_LOCK_FILE" && flock -n 9 ) 2>/dev/null; then
        _lamp_line OK "lock file acquirable: $UPDATE_ARCH_LOCK_FILE"
    else
        _lamp_line FAIL "cannot acquire lock: $UPDATE_ARCH_LOCK_FILE"
        ((failures++))
    fi

    # git is expected on an Arch system but not required for update-arch
    # itself to install or run. Warn if missing so the user notices.
    if command -v git &>/dev/null; then
        _lamp_line OK "git present: $(git --version | head -n1)"
    else
        _lamp_line WARN "git not installed (recommended: sudo pacman -S git)"
        ((warnings++))
    fi

    # Optional markdown renderer for prettier release notes. Not needed.
    local md_renderer=""
    for candidate in glow mdcat bat; do
        command -v "$candidate" &>/dev/null && { md_renderer="$candidate"; break; }
    done
    if [[ -n "$md_renderer" ]]; then
        _lamp_line OK "markdown renderer: $md_renderer (release notes will be formatted)"
    else
        _lamp_line SKIP "no markdown renderer (release notes print as plain text — optional: glow)"
    fi

    echo
    echo "${BOLD}Modules${NC}"

    local total=0 ok=0 skipped=0 invalid=0 orphan=0
    local base type desc status reason
    while IFS= read -r module; do
        ((total++))
        IFS=$'\t' read -r base type desc status reason < <(probe_module "$module")
        case "$status" in
            OK)
                _lamp_line OK "$(printf '%-28s %-7s %s' "$base" "$type" "$desc")"
                ((ok++))
                ;;
            SKIP)
                _lamp_line SKIP "$(printf '%-28s %-7s %s' "$base" "$type" "$reason")"
                ((skipped++))
                ;;
            ORPHAN)
                # Module is valid but won't run — prefix outside any phase range.
                _lamp_line WARN "$(printf '%-28s %-7s %s' "$base" "$type" "INACTIVE — $reason")"
                ((orphan++))
                ((warnings++))
                ;;
            INVALID)
                _lamp_line FAIL "$(printf '%-28s %-7s %s' "$base" "$type" "$reason")"
                ((invalid++))
                ((failures++))
                ;;
        esac
    done < <(find "$modules_dir" -maxdepth 1 -name '*.sh' | sort)

    echo
    printf '%d module(s): %d supported, %d skipped, %d orphan, %d invalid\n' \
        "$total" "$ok" "$skipped" "$orphan" "$invalid"

    if (( failures > 0 )); then
        print_error "Lamp-check FAILED ($failures failure(s), $warnings warning(s))"
        return 1
    fi
    if (( warnings > 0 )); then
        print_warning "Lamp-check passed with $warnings warning(s)"
        return 0
    fi
    print_success "Lamp-check passed — every indicator lit"
    return 0
}
