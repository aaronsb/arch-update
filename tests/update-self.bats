#!/usr/bin/env bats
# update-self.sh --maybe-upgrade decision codes. The network and install
# steps are replaced with functions; what is under test is the decision.

load test_helper

setup() {
    common_setup
    # shellcheck source=../update-self.sh
    source "$REPO_ROOT/update-self.sh"
    read_upstream_config()  { :; }
    read_install_manifest() { INSTALLED_VERSION=1.0.0; INSTALLED_COMMIT=aaaaaaa; }
    have()                  { :; }
    upstream_latest_ref()   { echo v1.1.0; }
    upstream_commit()       { echo bbbbbbb; }
}

@test "up to date: proceed (1)" {
    upstream_commit() { echo aaaaaaa; }
    run do_maybe_upgrade yes
    [ "$status" -eq 1 ]
}

@test "update applied: stop (0)" {
    do_run() { echo APPLIED; }
    run do_maybe_upgrade yes
    [ "$status" -eq 0 ]
    [[ "$output" == *APPLIED* ]]
}

@test "update attempted and failed: stop and report (2)" {
    do_run() { return 1; }
    run do_maybe_upgrade yes
    [ "$status" -eq 2 ]
}
