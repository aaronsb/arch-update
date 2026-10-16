#!/bin/bash
# Check the local pacman database for consistency problems.

MODULE_TYPE="system"
MODULE_NAME="pacman-db"
MODULE_DESCRIPTION="Check the pacman package database for problems"
MODULE_REQUIRES="pacman"
MODULE_DRY_RUN_SAFE="true"

run_update() {
    print_header "${ICONS[package]} VERIFYING PACKAGE DATABASE"

    print_section_box \
        "About Package Database" \
        "The pacman database tracks installed packages\nDatabase integrity is crucial for system stability" \
        "https://wiki.archlinux.org/title/Pacman#Package_database"

    # pacman -Dk only reads the database. pacman has no automatic repair for
    # what it finds, so each problem is a decision for the reader and goes to
    # the run summary. A non-zero exit with none of the problem lines below
    # means the check itself could not run, and that is a module failure.
    # LC_ALL=C: pacman translates its "error:" prefix.
    print_status "${ICONS[sync]}" "Checking package database integrity..."
    local report rc=0
    report=$(LC_ALL=C pacman -Dk 2>&1) || rc=$?
    if (( rc == 0 )); then
        print_success "Package database verified"
        return 0
    fi

    echo "$report"

    # The problem lines pacman's src/pacman/database.c prints for -Dk.
    local problem_re="^error: (missing '.*' dependency for '.*'"
    problem_re+="|'.*': (description file|file list) is missing"
    problem_re+="|'.*' conflicts with '.*'"
    problem_re+="|file owned by '.*' and '.*': '.*')$"
    local problems
    problems=$(grep -cE "$problem_re" <<< "$report")

    if (( problems == 0 )); then
        print_error "Could not check the package database (pacman -Dk exit $rc)"
        return 1
    fi

    print_warning "Package database has $problems problem(s)"
    print_info_box "Missing dependency: install it, or remove the package that needs it\nConflict or file owned twice: remove one of the two packages\nMissing description or file list: reinstall that package\nRe-check with: pacman -Dk (fixing one problem can reveal more)"
    add_run_note "pacman -Dk found $problems problem(s) in the package database — see its output above"
    return 0
}
