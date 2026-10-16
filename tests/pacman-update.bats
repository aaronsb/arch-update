#!/usr/bin/env bats
# modules/10-pacman-update.sh against stubbed checkupdates and pacman.

load test_helper

setup() {
    common_setup
    MODULE="$(repo_module 10-pacman-update.sh)"
}

@test "up-to-date system does not invoke pacman" {
    stub checkupdates 'exit 2'
    stub pacman 'exit 0'
    run run_module "$MODULE" system
    [ "$status" -eq 0 ]
    [[ "$output" == *"System is up to date"* ]]
    run ! grep -q '^pacman' "$STUB_LOG"
}

@test "dry run counts pending updates without invoking pacman" {
    stub checkupdates 'printf "foo 1-1 -> 1-2\nbar 2-1 -> 2-2\n"'
    stub pacman 'exit 0'
    DRY_RUN=1 run run_module "$MODULE" system
    [[ "$output" == *"Would update 2 package(s)"* ]]
    run ! grep -q '^pacman' "$STUB_LOG"
}

@test "pending updates run pacman -Syu --noconfirm" {
    stub checkupdates 'echo "foo 1-1 -> 1-2"'
    stub pacman 'exit 0'
    run run_module "$MODULE" system
    grep -qx 'sudo pacman -Syu --noconfirm' "$STUB_LOG"
    [[ "$output" == *"System packages updated"* ]]
}

@test "a pacman failure is reported as a module failure" {
    stub checkupdates 'echo "foo 1-1 -> 1-2"'
    stub pacman 'exit 1'
    run run_module "$MODULE" system
    [[ "$output" == *"Failed to update system packages"* ]]
    [[ "$output" == *"exited with status 1"* ]]
}

@test "a failed update check warns and proceeds to pacman" {
    stub checkupdates 'exit 1'
    stub pacman 'exit 0'
    run run_module "$MODULE" system
    [[ "$output" == *"Update check failed; proceeding anyway"* ]]
    grep -qx 'sudo pacman -Syu --noconfirm' "$STUB_LOG"
}

@test "dry run with a failed update check does not proceed" {
    stub checkupdates 'exit 1'
    stub pacman 'exit 0'
    DRY_RUN=1 run run_module "$MODULE" system
    [[ "$output" == *"Update check failed (checkupdates exit 1)"* ]]
    [[ "$output" != *"proceeding anyway"* ]]
    run ! grep -q '^pacman' "$STUB_LOG"
}

@test "a held pacman db lock fails the module without invoking pacman" {
    stub checkupdates 'echo "foo 1-1 -> 1-2"'
    stub pacman 'exit 0'
    touch "$PACMAN_DB_LOCK"
    run run_module "$MODULE" system
    [[ "$output" == *"Package manager is locked"* ]]
    [[ "$output" == *"exited with status 1"* ]]
    run ! grep -q '^pacman' "$STUB_LOG"
}
