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

    # pacman -Dk only reads the database. It reports missing dependencies and
    # file conflicts; pacman has no automatic repair for these, so each one
    # is a decision for the reader, and it goes to the run summary.
    print_status "${ICONS[sync]}" "Checking package database integrity..."
    local report
    if report=$(pacman -Dk 2>&1); then
        print_success "Package database verified"
        return 0
    fi

    echo "$report"
    local problems
    problems=$(grep -c '^error:' <<< "$report")
    print_warning "Package database has $problems problem(s)"
    print_info_box "Resolve each by installing the missing package or removing the conflicting one\nRe-check with: pacman -Dk"
    add_run_note "pacman -Dk found $problems problem(s) in the package database — see its output above"
}
