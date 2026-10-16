#!/usr/bin/env bats
# modules/90-systemd-status.sh against a stubbed systemctl.

load test_helper

setup() {
    common_setup
    MODULE="$(repo_module 90-systemd-status.sh)"
}

@test "failed units become a run note, not a module failure" {
    stub systemctl '
case "$1" in
    is-system-running) echo degraded; exit 1 ;;
    --failed) [[ "$2" == --no-legend ]] && echo "foo.service loaded failed failed Foo"; exit 0 ;;
esac'
    start_run_record
    run run_module "$MODULE" status
    [ "$status" -eq 0 ]
    run print_run_summary
    [ "$status" -eq 0 ]
    [[ "$output" == *"1 failed systemd unit(s)"* ]]
}

@test "a healthy system adds no note" {
    stub systemctl '
case "$1" in
    is-system-running) echo running ;;
esac
exit 0'
    start_run_record
    run run_module "$MODULE" status
    [ "$status" -eq 0 ]
    run print_run_summary
    [[ "$output" != *"systemd unit"* ]]
}
