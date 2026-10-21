#!/usr/bin/env bats
# Drop-in modules: $XDG_CONFIG_HOME/update-arch/modules.d joins module discovery.

load test_helper

setup() {
    common_setup
    mkdir -p "$UPDATE_ARCH_DROPIN_DIR"
}

# dropin_module FILE BODY — write a module into the drop-in directory.
dropin_module() {
    printf '#!/bin/bash\n%s\n' "$2" > "$UPDATE_ARCH_DROPIN_DIR/$1"
}

@test "the drop-in directory lives under the user config directory" {
    [ "$UPDATE_ARCH_DROPIN_DIR" = "$XDG_CONFIG_HOME/update-arch/modules.d" ]
}

@test "a drop-in runs in its phase, ordered by number among shipped modules" {
    fixture_module 50-first.sh 'MODULE_TYPE=user
run_update() { echo RAN-50; }'
    fixture_module 60-third.sh 'MODULE_TYPE=user
run_update() { echo RAN-60; }'
    dropin_module 55-dropin.sh 'MODULE_TYPE=user
run_update() { echo RAN-55; }'
    run run_phase "USER" user "" "[5-8][0-9]-*.sh" "$MODULE_DIR"
    [ "$status" -eq 0 ]
    [[ "$output" == *RAN-50*RAN-55*RAN-60* ]]
}

@test "a drop-in outside the phase's number range does not run in it" {
    dropin_module 15-sys.sh 'MODULE_TYPE=system
run_update() { echo RAN-15; }'
    run run_phase "USER" user "" "[5-8][0-9]-*.sh" "$MODULE_DIR"
    [[ "$output" != *RAN-15* ]]
}

@test "a drop-in whose MODULE_TYPE contradicts its number is refused" {
    dropin_module 55-liar.sh 'MODULE_TYPE=system
run_update() { echo RAN; }'
    start_run_record
    run_phase "USER" user "" "[5-8][0-9]-*.sh" "$MODULE_DIR" >/dev/null 2>&1
    [ "${#RUN_FAILURES[@]}" -eq 1 ]
}

@test "a failing drop-in is recorded like any module" {
    dropin_module 55-bad.sh 'MODULE_TYPE=user
run_update() { return 1; }'
    start_run_record
    run_phase "USER" user "" "[5-8][0-9]-*.sh" "$MODULE_DIR" >/dev/null 2>&1
    run print_run_summary
    [ "$status" -eq 1 ]
    [[ "$output" == *55-bad.sh* ]]
}

@test "symlinked drop-ins and a symlinked drop-in directory are both followed" {
    local real="$BATS_TEST_TMPDIR/store"
    mkdir -p "$real/modules.d"
    printf '#!/bin/bash\nMODULE_TYPE=user\nrun_update() { echo RAN-LINKED; }\n' > "$real/56-linked.sh"
    ln -s "$real/56-linked.sh" "$UPDATE_ARCH_DROPIN_DIR/56-linked.sh"
    run run_phase "USER" user "" "[5-8][0-9]-*.sh" "$MODULE_DIR"
    [[ "$output" == *RAN-LINKED* ]]

    rm -rf "$UPDATE_ARCH_DROPIN_DIR"
    printf '#!/bin/bash\nMODULE_TYPE=user\nrun_update() { echo RAN-DIRLINK; }\n' > "$real/modules.d/57-dir.sh"
    ln -s "$real/modules.d" "$UPDATE_ARCH_DROPIN_DIR"
    run run_phase "USER" user "" "[5-8][0-9]-*.sh" "$MODULE_DIR"
    [[ "$output" == *RAN-DIRLINK* ]]
}

@test "a missing drop-in directory changes nothing" {
    rm -rf "$UPDATE_ARCH_DROPIN_DIR"
    fixture_module 50-only.sh 'MODULE_TYPE=user
run_update() { echo RAN-50; }'
    run run_phase "USER" user "" "[5-8][0-9]-*.sh" "$MODULE_DIR"
    [ "$status" -eq 0 ]
    [[ "$output" == *RAN-50* ]]
}

@test "--list marks drop-in modules" {
    fixture_module 50-shipped.sh 'MODULE_TYPE=user
MODULE_DESCRIPTION="Shipped"
run_update() { :; }'
    dropin_module 55-dropin.sh 'MODULE_TYPE=user
MODULE_DESCRIPTION="Claimed by another tool"
run_update() { :; }'
    run list_modules "$MODULE_DIR"
    [[ "$output" == *"(drop-in) Claimed by another tool"* ]]
    [[ "$output" != *"(drop-in) Shipped"* ]]
}
