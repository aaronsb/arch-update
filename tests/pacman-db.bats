#!/usr/bin/env bats
# modules/02-pacman-db.sh against a stubbed pacman.

load test_helper

setup() {
    common_setup
    MODULE="$(repo_module 02-pacman-db.sh)"
}

@test "a clean database passes with no note" {
    stub pacman 'echo "No database errors have been found!"'
    start_run_record
    run run_module "$MODULE" system
    [ "$status" -eq 0 ]
    [[ "$output" == *"Package database verified"* ]]
    run print_run_summary
    [[ "$output" != *"database"* ]]
}

@test "database problems are shown and become a run note" {
    stub pacman '
echo "error: missing '"'"'libfoo.so=2-64'"'"' dependency for '"'"'bar'"'"'" >&2
echo "error: file owned by '"'"'baz'"'"' and '"'"'qux'"'"': '"'"'usr/lib/x'"'"'" >&2
exit 1'
    start_run_record
    run run_module "$MODULE" system
    [ "$status" -eq 0 ]
    [[ "$output" == *"missing 'libfoo.so=2-64' dependency for 'bar'"* ]]
    run print_run_summary
    [ "$status" -eq 0 ]
    [[ "$output" == *"pacman -Dk found 2 problem(s)"* ]]
}

@test "the check only reads: no sudo, no repair flag" {
    stub pacman 'exit 1'
    run run_module "$MODULE" system
    run ! grep -q '^sudo' "$STUB_LOG"
    [ "$(grep '^pacman' "$STUB_LOG")" = "pacman -Dk" ]
}
