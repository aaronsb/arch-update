#!/bin/bash
# Update language toolchains and tools that live outside pacman.
#
# Runs after 10-pacman-update.sh and before 11-aur-update.sh: phases sort by
# file name, and "10-toolchains" sorts after "10-pacman". pacman has to go first
# because it upgrades go, npm and uv themselves. The AUR has to come after
# because its builds compile with these toolchains; a stale rustup stable fails
# any crate that raised its minimum Rust version. tests/toolchains-update.bats
# pins the order.

MODULE_TYPE="system"
MODULE_NAME="toolchains-update"
MODULE_DESCRIPTION="Update rustup toolchains, Go-installed binaries, and uv/pipx tools"
MODULE_DRY_RUN_SAFE="true"

check_supported() {
    local tool
    for tool in rustup go uv pipx npm; do
        command -v "$tool" &>/dev/null && return 0
    done
    return 1
}

# rustup's channel toolchains (stable, nightly, 1.96) move only when asked.
# Pinned toolchains such as 1.92.0 stay where they are.
update_rustup() {
    command -v rustup &>/dev/null || return 0
    print_status "${ICONS[sync]}" "Rust toolchains (rustup)..."

    if [[ -n "$DRY_RUN" ]]; then
        rustup check
        return 0
    fi
    rustup update --no-self-update || { print_warning "rustup update failed"; return 1; }
}

# go_semver VERSION — "go1.27.3-X:nodwarf5" or "go1.25.1 X:nodwarf5" -> "1.27.3"
go_semver() {
    grep -oE '^go[0-9]+(\.[0-9]+)+' <<< "$1" | sed 's/^go//'
}

# version_older A B — true when version A sorts strictly before version B.
# Release candidates compare without their rc suffix: go_semver reads go1.28rc1
# as 1.28, which sort -V places before the final 1.28.0.
version_older() {
    [[ "$1" != "$2" && "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -1)" == "$1" ]]
}

# go_install_name PKG — the file name `go install PKG@VER` writes: the last path
# element, or the one before it when the last is a major-version suffix (v2).
go_install_name() {
    local name="${1##*/}"
    [[ "$name" =~ ^v[0-9]+$ ]] && { name="${1%/*}"; name="${name##*/}"; }
    echo "$name"
}

# A Go binary carries the standard library it was built with, so a crypto/tls
# or crypto/x509 fix reaches it only through a rebuild. Rebuild each binary in
# GOBIN that an older Go built, at the module version it already has.
#
# Only binaries fetched from the module proxy can be rebuilt by path@version;
# their mod line carries an h1: checksum. A build from a local checkout carries
# a VCS-stamped version (v1.2.3+dirty, a pseudo-version, or the tag of a fork
# that kept the upstream path) and no checksum, and installing that version by
# path would fail or fetch a different program.
update_go_binaries() {
    command -v go &>/dev/null || return 0
    # With GOTOOLCHAIN=auto, go follows the go.mod in the working directory;
    # querying from / pins the toolchain that go install below will use too.
    cd / || return 1

    local gobin system_go
    gobin=$(go env GOBIN)
    [[ -n "$gobin" ]] || gobin="$(go env GOPATH | cut -d: -f1)/bin"
    [[ -d "$gobin" ]] || return 0
    system_go=$(go_semver "$(go env GOVERSION)")
    if [[ -z "$system_go" ]]; then
        print_warning "Could not read a release Go version ($(go env GOVERSION)); skipping Go binaries"
        add_run_note "Go binaries not checked: $(go env GOVERSION) is not a release version"
        return 0
    fi

    print_status "${ICONS[sync]}" "Go binaries in $gobin (Go $system_go)..."

    local bin name buildinfo first built pkg mod ver sum failed=0 stale=0
    for bin in "$gobin"/*; do
        [[ -f "$bin" && -x "$bin" ]] || continue
        buildinfo=$(go version -m "$bin" 2>/dev/null) || continue
        first=$(head -1 <<< "$buildinfo")
        built=$(go_semver "${first##*: }")
        pkg=$(awk '$1 == "path" {print $2; exit}' <<< "$buildinfo")
        read -r mod ver sum < <(awk '$1 == "mod" {print $2, $3, $4; exit}' <<< "$buildinfo")
        [[ -n "$built" && -n "$pkg" ]] || continue
        version_older "$built" "$system_go" || continue
        stale=$((stale + 1))
        name=$(basename "$bin")

        if [[ "$sum" != h1:* || "$ver" == *+dirty ]]; then
            print_warning "$name: built with Go $built from a local checkout; rebuild it from source"
            add_run_note "$name in $gobin was built with Go $built from a local checkout; rebuild it from source"
            continue
        fi
        if [[ "$(go_install_name "$pkg")" != "$name" ]]; then
            print_warning "$name: installed under a different name than $pkg builds; rebuild it by hand"
            add_run_note "$name in $gobin (Go $built) was renamed from $(go_install_name "$pkg"); rebuild it by hand"
            continue
        fi

        if [[ -n "$DRY_RUN" ]]; then
            print_status "${ICONS[info]}" "Would rebuild $name ($pkg@$ver, Go $built -> $system_go)"
            continue
        fi
        print_status "${ICONS[package]}" "Rebuilding $name ($pkg@$ver, Go $built -> $system_go)"
        if ! GOBIN="$gobin" go install "$pkg@$ver"; then
            print_warning "Failed to rebuild $name from $mod@$ver"
            failed=1
        fi
    done

    (( stale == 0 )) && print_success "Go binaries are current"
    return "$failed"
}

update_python_tools() {
    local failed=0

    if command -v uv &>/dev/null && [[ -n "$(uv tool list 2>/dev/null)" ]]; then
        print_status "${ICONS[sync]}" "Python tools (uv)..."
        if [[ -n "$DRY_RUN" ]]; then
            print_status "${ICONS[info]}" "Would run: uv tool upgrade --all"
        elif ! uv tool upgrade --all; then
            print_warning "uv tool upgrade failed"
            failed=1
        fi
    fi

    if command -v pipx &>/dev/null && [[ -n "$(pipx list --short 2>/dev/null)" ]]; then
        print_status "${ICONS[sync]}" "Python tools (pipx)..."
        # A Python minor bump leaves venvs pointing at an interpreter that is
        # gone; upgrade-all fails on them until they are rebuilt.
        if pipx list 2>&1 | grep -q 'invalid interpreter'; then
            print_warning "Some pipx venvs use a removed Python; run: pipx reinstall-all"
            add_run_note "pipx venvs use a removed Python interpreter; run pipx reinstall-all"
        fi
        if [[ -n "$DRY_RUN" ]]; then
            print_status "${ICONS[info]}" "Would run: pipx upgrade-all"
        elif ! pipx upgrade-all; then
            print_warning "pipx upgrade-all failed"
            failed=1
        fi
    fi

    return "$failed"
}

# Report only. Global packages share /usr/lib/node_modules with pacman's own
# npm, and updating them in place can leave files pacman reports as conflicts.
report_npm_globals() {
    command -v npm &>/dev/null || return 0
    print_status "${ICONS[sync]}" "Global npm packages (report only)..."

    local outdated n rc=0
    # npm outdated exits 1 when anything is outdated, and also when the check
    # itself fails; only an empty list with exit 0 means current.
    outdated=$(npm outdated -g --parseable 2>/dev/null) || rc=$?
    if [[ -z "$outdated" ]]; then
        if (( rc == 0 )); then
            print_success "Global npm packages are current"
        else
            print_warning "Could not check global npm packages (npm outdated exit $rc)"
            add_run_note "Global npm packages not checked (npm outdated exit $rc)"
        fi
        return 0
    fi
    n=$(wc -l <<< "$outdated")
    print_warning "$n global npm package(s) outdated; see: npm outdated -g"
    add_run_note "$n global npm package(s) outdated (report only; see npm outdated -g)"
}

run_update() {
    print_header "${ICONS[package]} UPDATING LANGUAGE TOOLCHAINS"

    print_section_box \
        "About Toolchains" \
        "rustup, go install, uv and pipx keep their own toolchains and tools\npacman does not update them, and AUR builds compile with them" \
        "https://wiki.archlinux.org/title/Rust#Rustup"

    local failed=0
    update_rustup || failed=1
    update_go_binaries || failed=1
    update_python_tools || failed=1
    report_npm_globals

    if (( failed )); then
        print_error "Some toolchain updates failed"
        return 1
    fi
    [[ -n "$DRY_RUN" ]] || print_success "Toolchains updated"
}
