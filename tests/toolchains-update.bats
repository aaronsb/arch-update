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
    # What the go stub reports; a test overrides these before running.
    export STUB_GOBIN="$GOBIN_DIR" STUB_GOPATH="/unused" STUB_GOVERSION="go1.27.3-X:nodwarf5"
    start_run_record
}

# go_binary NAME BUILT PKG VER [SUM] — a fake binary in GOBIN plus the
# `go version -m` output the go stub prints for it. SUM defaults to the h1:
# checksum a proxy-fetched module carries; pass "" for a local checkout build.
go_binary() {
    local name="$1" built="$2" pkg="$3" ver="$4" sum="${5-h1:abc=}"
    printf '#!/bin/bash\n' > "$GOBIN_DIR/$name"
    chmod +x "$GOBIN_DIR/$name"
    printf '%s: %s\n\tpath\t%s\n\tmod\t%s\t%s\t%s\n' \
        "$GOBIN_DIR/$name" "$built" "$pkg" "${pkg%%/cmd/*}" "$ver" "$sum" > "$GOBIN_DIR/$name.info"
}

# The go stub logs its working directory with every call, as "go-pwd DIR".
stub_go() {
    stub go '
echo "go-pwd $PWD" >> "$STUB_LOG"
case "$1 $2" in
    "env GOBIN")     echo "$STUB_GOBIN" ;;
    "env GOPATH")    echo "$STUB_GOPATH" ;;
    "env GOVERSION") echo "$STUB_GOVERSION" ;;
    "version -m")    cat "$3.info" 2>/dev/null || exit 1 ;;
    install*)        exit "${STUB_GO_INSTALL_RC:-0}" ;;
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

# --- rustup ---------------------------------------------------------------

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

# --- Go binaries ----------------------------------------------------------

@test "a proxy-installed Go binary built with an older Go is rebuilt at its own version" {
    stub_go
    go_binary gopls "go1.25.1 X:nodwarf5" golang.org/x/tools/gopls v0.20.0
    run run_module "$MODULE" system
    [ "$status" -eq 0 ]
    grep -qx 'go install golang.org/x/tools/gopls@v0.20.0' "$STUB_LOG"
}

@test "every go call runs from / so a nearby go.mod cannot switch toolchains" {
    stub_go
    go_binary gopls "go1.25.1" golang.org/x/tools/gopls v0.20.0
    cd "$BATS_TEST_TMPDIR"
    run run_module "$MODULE" system
    [ "$status" -eq 0 ]
    grep -q '^go-pwd ' "$STUB_LOG"
    run ! grep -v '^go-pwd /$' <(grep '^go-pwd ' "$STUB_LOG")
}

@test "a Go binary built with the current Go is left alone" {
    stub_go
    go_binary gopls "go1.27.3-X:nodwarf5" golang.org/x/tools/gopls v0.20.0
    run run_module "$MODULE" system
    [ "$status" -eq 0 ]
    [[ "$output" == *"Go binaries are current"* ]]
    run ! grep -q '^go install' "$STUB_LOG"
}

@test "local checkout builds get a note, not a rebuild" {
    stub_go
    # What go 1.24+ stamps from VCS: a tag, a dirty tree, an untagged commit.
    go_binary tagged "go1.24.5" example.com/tagged v1.2.3 ""
    go_binary dirty "go1.24.5" example.com/dirty v1.2.3+dirty ""
    go_binary pseudo "go1.24.5" example.com/pseudo v0.0.0-20261021041127-c803fb48ed47 ""
    go_binary devel "go1.24.5" example.com/devel '(devel)' ""
    run run_module "$MODULE" system
    [ "$status" -eq 0 ]
    run ! grep -q '^go install' "$STUB_LOG"
    local n
    for n in tagged dirty pseudo devel; do
        [[ "$(notes)" == *"$n in "*"local checkout"* ]]
    done
}

@test "a dirty version is not rebuilt even with a checksum" {
    stub_go
    go_binary mytool "go1.24.5" example.com/mytool v1.2.3+dirty h1:abc=
    run run_module "$MODULE" system
    run ! grep -q '^go install' "$STUB_LOG"
}

@test "a renamed Go binary gets a note, not a rebuild under its package name" {
    stub_go
    go_binary osv "go1.26.1" github.com/google/osv-scanner/v2/cmd/osv-scanner v2.3.3
    run run_module "$MODULE" system
    [ "$status" -eq 0 ]
    run ! grep -q '^go install' "$STUB_LOG"
    [[ "$(notes)" == *"osv in "*"renamed from osv-scanner"* ]]
}

@test "a major-version suffix names the binary after the element before it" {
    stub_go
    go_binary mytool "go1.25.1" example.com/mytool/v2 v2.1.0
    run run_module "$MODULE" system
    [ "$status" -eq 0 ]
    grep -qx 'go install example.com/mytool/v2@v2.1.0' "$STUB_LOG"
}

@test "an empty GOBIN falls back to the first GOPATH entry" {
    stub_go
    local gopath="$BATS_TEST_TMPDIR/gopath"
    mkdir -p "$gopath/bin"
    GOBIN_DIR="$gopath/bin" go_binary gopls "go1.25.1" golang.org/x/tools/gopls v0.20.0
    STUB_GOBIN="" STUB_GOPATH="$gopath:/second" run run_module "$MODULE" system
    [ "$status" -eq 0 ]
    [[ "$output" == *"Go binaries in $gopath/bin"* ]]
    grep -qx 'go install golang.org/x/tools/gopls@v0.20.0' "$STUB_LOG"
}

@test "a non-release Go version is a note, not a failure" {
    stub_go
    go_binary gopls "go1.25.1" golang.org/x/tools/gopls v0.20.0
    STUB_GOVERSION="devel go1.28-abcdef" run run_module "$MODULE" system
    [ "$status" -eq 0 ]
    run ! grep -q '^go install' "$STUB_LOG"
    [[ "$(notes)" == *"not a release version"* ]]
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
    STUB_GO_INSTALL_RC=1 run run_module "$MODULE" system
    [ "$status" -eq 1 ]
    [[ "$output" == *"Failed to rebuild gopls"* ]]
}

# --- Python tools ---------------------------------------------------------

@test "uv upgrades its tools only when any are installed" {
    stub uv 'exit 0'
    run run_module "$MODULE" system
    run ! grep -q '^uv tool upgrade' "$STUB_LOG"

    stub uv '[[ "$1 $2" == "tool list" ]] && echo "marker-pdf v1.10.2"; exit 0'
    run run_module "$MODULE" system
    [ "$status" -eq 0 ]
    grep -qx 'uv tool upgrade --all' "$STUB_LOG"
}

@test "pipx upgrades its tools only when any are installed" {
    stub pipx 'exit 0'
    run run_module "$MODULE" system
    run ! grep -q '^pipx upgrade-all' "$STUB_LOG"

    stub pipx '[[ "$1" == list ]] && echo some-tool; exit 0'
    run run_module "$MODULE" system
    [ "$status" -eq 0 ]
    grep -qx 'pipx upgrade-all' "$STUB_LOG"
}

@test "dry run does not upgrade uv or pipx tools" {
    stub uv '[[ "$1 $2" == "tool list" ]] && echo "marker-pdf v1.10.2"; exit 0'
    stub pipx '[[ "$1" == list ]] && echo some-tool; exit 0'
    DRY_RUN=1 run run_module "$MODULE" system
    [ "$status" -eq 0 ]
    [[ "$output" == *"Would run: uv tool upgrade --all"* ]]
    [[ "$output" == *"Would run: pipx upgrade-all"* ]]
    run ! grep -qE '^(uv tool upgrade|pipx upgrade-all)' "$STUB_LOG"
}

@test "pipx venvs on a removed Python get a reinstall note" {
    stub pipx '
[[ "$1 $2" == "list --short" ]] && { echo some-tool; exit 0; }
[[ "$1" == list ]] && { echo "   package lcp has invalid interpreter /usr/bin/python3.13" >&2; exit 0; }
exit 0'
    run run_module "$MODULE" system
    [[ "$(notes)" == *"pipx reinstall-all"* ]]
}

# --- npm ------------------------------------------------------------------

@test "outdated global npm packages are reported, not updated" {
    stub npm '[[ "$1" == outdated ]] && { echo "/usr/lib/node_modules/a:a@2:a@1:a@2:global"; exit 1; }; exit 0'
    run run_module "$MODULE" system
    [ "$status" -eq 0 ]
    [[ "$(notes)" == *"1 global npm package(s) outdated"* ]]
    run ! grep -qE '^npm (update|install)' "$STUB_LOG"
}

@test "a failed npm check is reported as unchecked, not current" {
    stub npm '[[ "$1" == outdated ]] && exit 1; exit 0'
    run run_module "$MODULE" system
    [ "$status" -eq 0 ]
    [[ "$output" != *"Global npm packages are current"* ]]
    [[ "$(notes)" == *"not checked (npm outdated exit 1)"* ]]
}
