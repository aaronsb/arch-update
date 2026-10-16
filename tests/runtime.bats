#!/usr/bin/env bats
# Module dispatch: run_module and module_expected_phase in runtime.sh.

load test_helper

setup() { common_setup; }

@test "the sudo stub refuses a target the test did not stub" {
    run -127 sudo definitely-not-stubbed
    [[ "$output" == *"not stubbed"* ]]
}

@test "phase ranges map number prefixes to module types" {
    [ "$(module_expected_phase 00-x.sh)" = system ]
    [ "$(module_expected_phase 49-x.sh)" = system ]
    [ "$(module_expected_phase 50-x.sh)" = user ]
    [ "$(module_expected_phase 89-x.sh)" = user ]
    [ "$(module_expected_phase 90-x.sh)" = status ]
    [ "$(module_expected_phase x-x.sh)" = "" ]
}

@test "run_module runs run_update for a supported module" {
    fixture_module 10-ok.sh '
MODULE_TYPE=system
run_update() { echo RAN; }'
    run run_module "$MODULE_DIR/10-ok.sh" system
    [ "$status" -eq 0 ]
    [[ "$output" == *RAN* ]]
}

@test "run_module skips a module whose MODULE_REQUIRES is missing" {
    fixture_module 10-req.sh '
MODULE_TYPE=system
MODULE_REQUIRES="definitely-not-a-command-xyz"
run_update() { echo RAN; }'
    run run_module "$MODULE_DIR/10-req.sh" system
    [ "$status" -eq 0 ]
    [[ "$output" != *RAN* ]]
    [[ "$output" == *"not supported"* ]]
}

@test "run_module skips a dry-run-unsafe module under DRY_RUN" {
    fixture_module 10-unsafe.sh '
MODULE_TYPE=system
MODULE_DRY_RUN_SAFE=false
run_update() { echo RAN; }'
    DRY_RUN=1 run run_module "$MODULE_DIR/10-unsafe.sh" system
    [ "$status" -eq 0 ]
    [[ "$output" != *RAN* ]]
    [[ "$output" == *"not dry-run safe"* ]]
}

@test "run_module refuses a module placed in the wrong phase" {
    fixture_module 10-wrong.sh '
MODULE_TYPE=user
run_update() { echo RAN; }'
    run run_module "$MODULE_DIR/10-wrong.sh" system
    [[ "$output" != *RAN* ]]
    [[ "$output" == *"MODULE_TYPE='user' but placed in 'system' phase"* ]]
}

@test "run_module reports a failing module's exit status" {
    fixture_module 10-fail.sh '
MODULE_TYPE=system
run_update() { return 3; }'
    run run_module "$MODULE_DIR/10-fail.sh" system
    [ "$status" -eq 3 ]
    [[ "$output" == *"exited with status 3"* ]]
}

@test "run_module isolates module state from the caller" {
    fixture_module 10-leak.sh '
MODULE_TYPE=system
run_update() { LEAKED=yes; echo RAN; }'
    # Run in this shell, not via run or $(...), which would isolate it anyway.
    run_module "$MODULE_DIR/10-leak.sh" system > "$BATS_TEST_TMPDIR/out"
    # A leak would include run_module's own `set +e`, which silences bats
    # assertions; restore errexit before asserting.
    set -e
    grep -q RAN "$BATS_TEST_TMPDIR/out"
    [ -z "${LEAKED:-}" ]
}

@test "run_phase runs every module in order and records each failure" {
    fixture_module 10-a.sh 'MODULE_TYPE=system
run_update() { echo A; return 1; }'
    fixture_module 11-b.sh 'MODULE_TYPE=system
run_update() { echo B; }'
    fixture_module 12-c.sh 'MODULE_TYPE=system
run_update() { echo C; return 4; }'
    fixture_module 50-user.sh 'MODULE_TYPE=user
run_update() { echo USER; }'
    start_run_record
    run_phase "SYSTEM" system "" "[0-4][0-9]-*.sh" "$MODULE_DIR" > "$BATS_TEST_TMPDIR/out"
    set -e
    [ "$(grep -E '^(A|B|C|USER)$' "$BATS_TEST_TMPDIR/out" | tr '\n' ' ')" = "A B C " ]
    [ "${RUN_FAILURES[*]}" = "10-a.sh (exit 1) 12-c.sh (exit 4)" ]
}

@test "run summary on a clean run succeeds and says so" {
    start_run_record
    run print_run_summary
    [ "$status" -eq 0 ]
    [[ "$output" == *"All modules completed successfully"* ]]
    [[ "$output" != *failed* ]]
}

@test "run summary names failed modules and fails the run" {
    start_run_record
    record_failure 10-pacman-update.sh 1
    record_failure 20-flatpak-update.sh 2
    run print_run_summary
    [ "$status" -eq 1 ]
    [[ "$output" == *"2 module(s) failed"* ]]
    [[ "$output" == *"10-pacman-update.sh (exit 1)"* ]]
    [[ "$output" == *"20-flatpak-update.sh (exit 2)"* ]]
    [[ "$output" != *"completed successfully"* ]]
}

@test "notes added by a module reach the summary without failing the run" {
    fixture_module 90-note.sh 'MODULE_TYPE=status
run_update() { add_run_note "something to look at"; }'
    start_run_record
    run_phase "STATUS" status "" "9[0-9]-*.sh" "$MODULE_DIR" >/dev/null
    run print_run_summary
    [ "$status" -eq 0 ]
    [[ "$output" == *"something to look at"* ]]
}

@test "a skipped module is not a failure" {
    fixture_module 10-skip.sh 'MODULE_TYPE=system
MODULE_REQUIRES="definitely-not-a-command-xyz"
run_update() { return 1; }'
    start_run_record
    run_phase "SYSTEM" system "" "[0-4][0-9]-*.sh" "$MODULE_DIR" >/dev/null
    [ "${#RUN_FAILURES[@]}" -eq 0 ]
}
