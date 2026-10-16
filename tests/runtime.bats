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
