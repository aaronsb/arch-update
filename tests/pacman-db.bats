#!/usr/bin/env bats
# modules/02-pacman-db.sh against a stubbed pacman. Problem lines follow the
# messages in pacman's src/pacman/database.c.

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

@test "each kind of database problem is counted, other lines are not" {
    stub pacman '
cat >&2 <<OUT
warning: config file /etc/pacman.conf, line 9: directive is deprecated
error: could not open file /var/lib/pacman/local/x-1-1/mtree: Permission denied
error: missing '"'"'libfoo.so=2-64'"'"' dependency for '"'"'bar'"'"'
error: '"'"'old-1-1'"'"': description file is missing
error: '"'"'old-1-1'"'"': file list is missing
error: '"'"'a'"'"' conflicts with '"'"'b'"'"'
error: file owned by '"'"'baz'"'"' and '"'"'qux'"'"': '"'"'usr/lib/x'"'"'
OUT
exit 3'
    start_run_record
    run run_module "$MODULE" system
    [ "$status" -eq 0 ]
    [[ "$output" == *"missing 'libfoo.so=2-64' dependency for 'bar'"* ]]
    run print_run_summary
    [ "$status" -eq 0 ]
    [[ "$output" == *"pacman -Dk found 5 problem(s)"* ]]
}

@test "problems are counted whatever the user's locale" {
    stub pacman '
if [[ "$LC_ALL" == C ]]; then p="error:"; else p="Fehler:"; fi
echo "$p '"'"'a'"'"' conflicts with '"'"'b'"'"'" >&2
exit 1'
    start_run_record
    LANG=de_DE.UTF-8 LC_ALL=de_DE.UTF-8 run run_module "$MODULE" system
    [ "$status" -eq 0 ]
    run print_run_summary
    [[ "$output" == *"pacman -Dk found 1 problem(s)"* ]]
}

@test "a check that could not run fails the module" {
    stub pacman 'echo "error: failed to initialize alpm library" >&2; exit 255'
    start_run_record
    run run_module "$MODULE" system
    [ "$status" -eq 1 ]
    [[ "$output" == *"Could not check the package database (pacman -Dk exit 255)"* ]]
    [[ "$output" == *"failed to initialize alpm library"* ]]
    run print_run_summary
    [[ "$output" != *"problem(s)"* ]]
}

@test "a check that dies silently fails the module" {
    stub pacman 'exit 139'
    run run_module "$MODULE" system
    [ "$status" -eq 1 ]
    [[ "$output" == *"pacman -Dk exit 139"* ]]
}

@test "the check only reads: no sudo, no repair flag" {
    stub pacman 'exit 0'
    run run_module "$MODULE" system
    run ! grep -q '^sudo' "$STUB_LOG"
    [ "$(grep '^pacman' "$STUB_LOG")" = "pacman -Dk" ]
}
