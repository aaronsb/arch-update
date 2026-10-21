#!/usr/bin/env bats
# modules/10-toolchains-update.sh against stubbed rustup, go, uv, pipx and npm.

load test_helper

setup() {
    common_setup
    MODULE="$(repo_module 10-toolchains-update.sh)"

    # The host's real rustup, go, uv, pipx and npm sit on PATH behind the stubs,
    # and an absent stub would fall through to them. PATH here holds the stubs
    # and the handful of utilities the module itself calls, nothing else.
    local safe="$BATS_TEST_TMPDIR/safe-bin" tool
    mkdir -p "$safe"
    for tool in awk basename cat chmod cut find grep head mkdir mktemp printf rm sed sort wc; do
        ln -s "$(command -v "$tool")" "$safe/$tool"
    done
    export PATH="$STUB_BIN:$safe"

    GOBIN_DIR="$BATS_TEST_TMPDIR/gobin"
    mkdir -p "$GOBIN_DIR"
    start_run_record
}

# go_binary NAME VERSION_LINE PATH MOD_VERSION — a fake binary in GOBIN, plus the
# `go version -m` output the go stub prints for it.
go_binary() {
    local name="$1" built="$2" pkg="$3" ver="$4"
    printf '#!/bin/bash\n' > "$GOBIN_DIR/$name"
    chmod +x "$GOBIN_DIR/$name"
    printf '%s: %s\n\tpath\t%s\n\tmod\t%s\t%s\th1:x=\n' \
        "$GOBIN_DIR/$name" "$built" "$pkg" "${pkg%%/cmd/*}" "$ver" > "$GOBIN_DIR/$name.info"
}

stub_go() {
    stub go '
case "$1 $2" in
    "env GOBIN")     echo "'"$GOBIN_DIR"'" ;;
    "env GOPATH")    echo "/unused" ;;
    "env GOVERSION") echo "go1.27.3-X:nodwarf5" ;;
    "version -m")    cat "$3.info" 2>/dev/null || exit 1 ;;
esac'
}

notes() { cat "$UPDATE_ARCH_RUN_NOTES" 2>/dev/null; }

@test "runs after the pacman module and before the AUR module" {
    # The same listing run_phase sorts, from the real modules directory.
    local order pacman toolchains aur
    order=$(find "$REPO_ROOT/modules" -maxdepth 1 -name '[0-4][0-9]-*.sh' | sort)
    pacman=$(grep -n '/10-pacman-update\.sh$' <<< "$order" | cut -d: -f1)
    toolchains=$(grep -n '/10-toolchains-update\.sh$' <<< "$order" | cut -d: -f1)
    aur=$(grep -n '/11-aur-update\.sh$' <<< "$order" | cut -d: -f1)
    [ -n "$pacman" ] && [ -n "$toolchains" ] && [ -n "$aur" ]
    (( pacman < toolchains && toolchains < aur ))
}

@test "a system with none of the toolchains skips the module" {
    run run_module "$MODULE" system
    [ "$status" -eq 0 ]
    [[ "$output" == *"not supported"* ]]
}

@test "rustup updates its toolchains without self-updating" {
    stub rustup 'exit 0'
    run run_module "$MODULE" system
    [ "$status" -eq 0 ]
    grep -qx 'rustup update --no-self-update' "$STUB_LOG"
}

@test "dry run checks rustup without updating" {
    stub rustup 'exit 0'
    DRY_RUN=1 run run_module "$MODULE" system
    [ "$status" -eq 0 ]
    grep -qx 'rustup check' "$STUB_LOG"
    run ! grep -q '^rustup update' "$STUB_LOG"
}

@test "a rustup failure fails the module after the other steps run" {
    stub rustup '[[ "$1" == update ]] && exit 1; exit 0'
    stub pipx '[[ "$1" == list ]] && echo some-tool; exit 0'
    run run_module "$MODULE" system
    [ "$status" -eq 1 ]
    [[ "$output" == *"rustup update failed"* ]]
    grep -qx 'pipx upgrade-all' "$STUB_LOG"
}

@test "a Go binary built with an older Go is rebuilt at its own version" {
    stub_go
    go_binary gopls "go1.25.1 X:nodwarf5" golang.org/x/tools/gopls v0.20.0
    run run_module "$MODULE" system
    [ "$status" -eq 0 ]
    grep -qx 'go install golang.org/x/tools/gopls@v0.20.0' "$STUB_LOG"
}

@test "a Go binary built with the current Go is left alone" {
    stub_go
    go_binary gopls "go1.27.3-X:nodwarf5" golang.org/x/tools/gopls v0.20.0
    run run_module "$MODULE" system
    [ "$status" -eq 0 ]
    [[ "$output" == *"Go binaries are current"* ]]
    run ! grep -q '^go install' "$STUB_LOG"
}

@test "a Go binary built from a local checkout gets a note, not a rebuild" {
    stub_go
    go_binary mytool "go1.24.5" example.com/mytool '(devel)'
    run run_module "$MODULE" system
    [ "$status" -eq 0 ]
    run ! grep -q '^go install' "$STUB_LOG"
    [[ "$(notes)" == *"mytool"*"local checkout"* ]]
}

@test "dry run names the Go binaries it would rebuild" {
    stub_go
    go_binary gopls "go1.25.1" golang.org/x/tools/gopls v0.20.0
    DRY_RUN=1 run run_module "$MODULE" system
    [ "$status" -eq 0 ]
    [[ "$output" == *"Would rebuild gopls"* ]]
    run ! grep -q '^go install' "$STUB_LOG"
}

@test "a failed Go rebuild fails the module" {
    stub_go
    go_binary gopls "go1.25.1" golang.org/x/tools/gopls v0.20.0
    stub go '
case "$1 $2" in
    "env GOBIN")     echo "'"$GOBIN_DIR"'" ;;
    "env GOVERSION") echo "go1.27.3" ;;
    "version -m")    cat "$3.info" ;;
    install*)        exit 1 ;;
esac'
    run run_module "$MODULE" system
    [ "$status" -eq 1 ]
    [[ "$output" == *"Failed to rebuild gopls"* ]]
}

@test "uv upgrades its tools only when any are installed" {
    stub uv '[[ "$1 $2" == "tool list" ]] && exit 0; exit 0'
    run run_module "$MODULE" system
    run ! grep -q '^uv tool upgrade' "$STUB_LOG"

    stub uv '[[ "$1 $2" == "tool list" ]] && echo "marker-pdf v1.10.2"; exit 0'
    run run_module "$MODULE" system
    [ "$status" -eq 0 ]
    grep -qx 'uv tool upgrade --all' "$STUB_LOG"
}

@test "outdated global npm packages are reported, not updated" {
    stub npm '[[ "$1" == outdated ]] && { echo "/usr/lib/node_modules/a:a@2:a@1:a@2:global"; exit 1; }; exit 0'
    run run_module "$MODULE" system
    [ "$status" -eq 0 ]
    [[ "$(notes)" == *"1 global npm package(s) outdated"* ]]
    run ! grep -qE '^npm (update|install)' "$STUB_LOG"
}
