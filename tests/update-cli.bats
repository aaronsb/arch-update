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

# A NOPASSWD account that also matches a password rule such as %wheel: under
# sudo's default verifypw=all, sudo -v wants a password and sudo -n true works.
stub_nopasswd_sudo() {
    stub sudo '
if [[ "$*" == *-v* ]]; then
    [[ "$*" == *-n* ]] || echo "sudo: a terminal is required to read the password" >&2
    exit 1
fi
while [[ "$1" == -* ]]; do shift; done
(( $# == 0 )) && exit 0
[[ "$1" == true ]] && exit 0
target="'"$STUB_BIN"'/$1"; shift
[[ -x "$target" ]] || exit 127
exec "$target" "$@"'
}

@test "a NOPASSWD account whose sudo -v wants a password still runs system modules" {
    stub_nopasswd_sudo
    stub checkupdates 'echo "foo 1-1 -> 1-2"'
    stub pacman 'exit 0'
    run "$REPO_ROOT/update.sh" --only pacman-update
    [ "$status" -eq 0 ]
    [[ "$output" != *"Failed to establish sudo session"* ]]
    grep -qx 'pacman -Syu --noconfirm' "$STUB_LOG"
}

@test "an account sudo refuses outright still fails to start" {
    stub sudo 'exit 1'
    stub checkupdates 'exit 2'
    run "$REPO_ROOT/update.sh" --only pacman-update
    [ "$status" -ne 0 ]
    [[ "$output" == *"Failed to establish sudo session"* ]]
}
