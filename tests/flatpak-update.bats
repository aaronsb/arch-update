#!/usr/bin/env bats
# modules/20-flatpak-update.sh against a stubbed flatpak.
#
# The flatpak stub models the failure seen on hosts updated without a local,
# active session: changing the system installation as an ordinary user is
# refused, the way polkit refuses flatpak's system-helper when there is no one
# to authenticate. The sudo stub marks its child as root so the flatpak stub
# can tell the two apart. Updates pending per installation come from
# SYSTEM_UPDATES and USER_UPDATES. SYSTEM_UPDATE_RC and USER_UPDATE_RC set the
# exit status of each installation's update, SYSTEM_LS_RC and USER_LS_RC that
# of each installation's update check.

load test_helper

setup() {
    common_setup
    MODULE="$(repo_module 20-flatpak-update.sh)"

    # PATH holds the stubs and the few host tools the module, stub(), these
    # tests and bats' own cleanup use, so the host's real flatpak can never
    # run from here.
    local tools="$BATS_TEST_TMPDIR/tools" tool
    mkdir -p "$tools"
    for tool in basename cat chmod grep rm; do
        ln -s "$(command -v "$tool")" "$tools/$tool"
    done
    export PATH="$STUB_BIN:$tools"

    stub sudo '
while [[ "$1" == -* ]]; do shift; done
(( $# == 0 )) && exit 0
target="'"$STUB_BIN"'/$1"; shift
[[ -x "$target" ]] || { echo "sudo stub: ${target##*/} is not stubbed" >&2; exit 127; }
FAKE_ROOT=1 exec "$target" "$@"'

    stub flatpak '
args=" $* "
case "$1" in
    remote-ls)
        if [[ "$args" == *" --user "* ]]; then
            [[ "${USER_LS_RC:-0}" == 0 ]] || { echo "error: offline" >&2; exit "$USER_LS_RC"; }
            printf "%s" "$USER_UPDATES"
        else
            [[ "${SYSTEM_LS_RC:-0}" == 0 ]] || { echo "error: offline" >&2; exit "$SYSTEM_LS_RC"; }
            printf "%s" "$SYSTEM_UPDATES"
        fi
        ;;
    update)
        if [[ "$args" == *" --user "* ]]; then
            [[ -z "$FAKE_ROOT" ]] || { echo "error: updated root'"'"'s user installation" >&2; exit 1; }
            exit "${USER_UPDATE_RC:-0}"
        elif [[ -z "$FAKE_ROOT" && -n "$SYSTEM_UPDATES" ]]; then
            echo "Error: Flatpak system operation Deploy not allowed for user" >&2
            exit 1
        fi
        exit "${SYSTEM_UPDATE_RC:-0}"
        ;;
esac
exit 0'

    export SYSTEM_UPDATES="" USER_UPDATES="" SYSTEM_UPDATE_RC="" USER_UPDATE_RC="" SYSTEM_LS_RC="" USER_LS_RC=""
}

@test "no pending updates does not invoke flatpak update" {
    run run_module "$MODULE" system
    [ "$status" -eq 0 ]
    [[ "$output" == *"All Flatpak apps up to date"* ]]
    run ! grep -q '^flatpak update' "$STUB_LOG"
}

@test "dry run counts updates in both installations without updating" {
    SYSTEM_UPDATES=$'Slack\tcom.slack.Slack\t4.52.155\tstable\tx86_64\nZoom\tus.zoom.Zoom\t7.1.5\tstable\tx86_64\n'
    USER_UPDATES=$'Signal\torg.signal.Signal\t8.29.0\tstable\tx86_64\n'
    DRY_RUN=1 run run_module "$MODULE" system
    [ "$status" -eq 0 ]
    [[ "$output" == *"Would update 3 Flatpak app(s)"* ]]
    run ! grep -qE '^(sudo )?flatpak update' "$STUB_LOG"
}

@test "system updates run as root so they need no polkit agent" {
    SYSTEM_UPDATES=$'Slack\tcom.slack.Slack\t4.52.155\tstable\tx86_64\n'
    run run_module "$MODULE" system
    [ "$status" -eq 0 ]
    [[ "$output" == *"Updated 1 Flatpak app(s)"* ]]
    grep -qx 'sudo flatpak update --system --noninteractive' "$STUB_LOG"
    run ! grep -q 'flatpak update --user' "$STUB_LOG"
}

@test "user updates run as the invoking user, not through sudo" {
    USER_UPDATES=$'Signal\torg.signal.Signal\t8.29.0\tstable\tx86_64\n'
    run run_module "$MODULE" system
    [ "$status" -eq 0 ]
    grep -qx 'flatpak update --user --noninteractive' "$STUB_LOG"
    run ! grep -q '^sudo' "$STUB_LOG"
}

@test "updates in both installations update each one" {
    SYSTEM_UPDATES=$'Slack\tcom.slack.Slack\t4.52.155\tstable\tx86_64\n'
    USER_UPDATES=$'Signal\torg.signal.Signal\t8.29.0\tstable\tx86_64\n'
    run run_module "$MODULE" system
    [ "$status" -eq 0 ]
    [[ "$output" == *"Updated 2 Flatpak app(s)"* ]]
    grep -qx 'sudo flatpak update --system --noninteractive' "$STUB_LOG"
    grep -qx 'flatpak update --user --noninteractive' "$STUB_LOG"
}

@test "a flatpak update failure is reported as a module failure" {
    SYSTEM_UPDATES=$'Slack\tcom.slack.Slack\t4.52.155\tstable\tx86_64\n'
    SYSTEM_UPDATE_RC=1
    run run_module "$MODULE" system
    [[ "$output" == *"Failed to update the system Flatpak installation"* ]]
    [[ "$output" == *"exited with status 1"* ]]
}

@test "a system update failure still updates the user installation" {
    SYSTEM_UPDATES=$'Slack\tcom.slack.Slack\t4.52.155\tstable\tx86_64\n'
    USER_UPDATES=$'Signal\torg.signal.Signal\t8.29.0\tstable\tx86_64\n'
    SYSTEM_UPDATE_RC=1
    run run_module "$MODULE" system
    [ "$status" -eq 1 ]
    [[ "$output" == *"Failed to update the system Flatpak installation"* ]]
    grep -qx 'flatpak update --user --noninteractive' "$STUB_LOG"
}

@test "a user update failure is reported after the system installation updated" {
    SYSTEM_UPDATES=$'Slack\tcom.slack.Slack\t4.52.155\tstable\tx86_64\n'
    USER_UPDATES=$'Signal\torg.signal.Signal\t8.29.0\tstable\tx86_64\n'
    USER_UPDATE_RC=1
    run run_module "$MODULE" system
    [ "$status" -eq 1 ]
    [[ "$output" == *"Failed to update the user Flatpak installation"* ]]
    [[ "$output" != *"Failed to update the system Flatpak installation"* ]]
    grep -qx 'sudo flatpak update --system --noninteractive' "$STUB_LOG"
}

@test "a failed update check is noted, not reported as up to date, and is not a module failure" {
    SYSTEM_LS_RC=2
    export UPDATE_ARCH_RUN_NOTES="$BATS_TEST_TMPDIR/notes"
    run run_module "$MODULE" system
    [ "$status" -eq 0 ]
    [[ "$(cat "$UPDATE_ARCH_RUN_NOTES")" == *"Flatpak system updates not checked (remote-ls exit 2)"* ]]
    [[ "$output" != *"up to date"* ]]
    run ! grep -q 'flatpak update' "$STUB_LOG"
}

@test "a failed system check still checks and updates the user installation" {
    SYSTEM_LS_RC=2
    USER_UPDATES=$'Signal\torg.signal.Signal\t8.29.0\tstable\tx86_64\n'
    export UPDATE_ARCH_RUN_NOTES="$BATS_TEST_TMPDIR/notes"
    run run_module "$MODULE" system
    [ "$status" -eq 0 ]
    [[ "$(cat "$UPDATE_ARCH_RUN_NOTES")" == *"not checked (remote-ls exit 2)"* ]]
    grep -qx 'flatpak update --user --noninteractive' "$STUB_LOG"
    run ! grep -q 'flatpak update --system' "$STUB_LOG"
}

@test "dry run labels the listed updates by installation" {
    SYSTEM_UPDATES=$'Slack\tcom.slack.Slack\t4.52.155\tstable\tx86_64\n'
    USER_UPDATES=$'Signal\torg.signal.Signal\t8.29.0\tstable\tx86_64\n'
    DRY_RUN=1 run run_module "$MODULE" system
    [[ "$output" == *"system (via sudo):"*"Slack"*"user:"*"Signal"* ]]
}
