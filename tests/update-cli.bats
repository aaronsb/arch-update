#!/usr/bin/env bats
# update.sh entry points, end to end, against stubbed system commands.

load test_helper

setup() { common_setup; }

@test "--only exits non-zero when the module fails" {
    stub checkupdates 'echo "foo 1-1 -> 1-2"'
    stub pacman 'exit 1'
    run "$REPO_ROOT/update.sh" --only pacman-update
    [ "$status" -eq 1 ]
    [[ "$output" == *"Failed to update system packages"* ]]
}

@test "--only exits zero when the module succeeds" {
    stub checkupdates 'exit 2'
    run "$REPO_ROOT/update.sh" --only pacman-update
    [ "$status" -eq 0 ]
}
