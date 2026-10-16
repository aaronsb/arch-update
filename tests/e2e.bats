#!/usr/bin/env bats
# update.sh end to end from an installed copy: self-update decision, the
# module phases, the summary and the exit status. The installed copy carries
# fixture modules only, network calls go to a curl stub, and sudo, ping and
# pacman are stubs, so nothing reaches the host.

load test_helper

setup() {
    common_setup
    stub ping 'exit 0'
    stub pacman 'exit 0'

    # Upstream as the curl stub serves it. UPSTREAM_SHA equal to the
    # installed commit means "no update"; UPSTREAM_TARBALL empty means the
    # download fails.
    export UPSTREAM_SHA=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
    export UPSTREAM_TARBALL=""
    stub curl '
for a; do case "$a" in
    */releases/latest) echo "{\"tag_name\": \"v9.9.9\"}"; exit 0 ;;
    */commits/*)       echo "{\"sha\": \"$UPSTREAM_SHA\"}"; exit 0 ;;
    */releases/tags/*) exit 22 ;;
    */archive/*)       [[ -n "$UPSTREAM_TARBALL" ]] && cat "$UPSTREAM_TARBALL" && exit 0; exit 22 ;;
esac; done
exit 22'

    INSTALL="$XDG_DATA_HOME/update-arch"
    install_copy "$INSTALL"
    printf '%s\n' \
        'INSTALLED_VERSION="1.0.0"' \
        'INSTALLED_COMMIT="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"' \
        'INSTALLED_REF="v1.0.0"' \
        'INSTALLED_FROM="tarball"' > "$INSTALL/INSTALL_MANIFEST"
}

# install_copy DIR — the repo's tracked files, with fixture modules in place
# of the real ones.
install_copy() {
    local dest="$1" f
    mkdir -p "$dest"
    while IFS= read -r f; do
        [[ "$f" == modules/* || "$f" == tests/* || "$f" == docs/* || "$f" == .github/* ]] && continue
        mkdir -p "$dest/$(dirname "$f")"
        cp -p "$REPO_ROOT/$f" "$dest/$f"
    done < <(git -C "$REPO_ROOT" ls-files)
    mkdir -p "$dest/modules"
    printf 'MODULE_TYPE=system\nrun_update() { echo MAINTENANCE-RAN; }\n' > "$dest/modules/10-ok.sh"
}

failing_module() {
    printf 'MODULE_TYPE=system\nrun_update() { echo BROKEN-RAN; return 1; }\n' > "$INSTALL/modules/11-broken.sh"
}

@test "--run with every module passing exits 0 and says so" {
    run "$INSTALL/update.sh" --run --yes < /dev/null
    [ "$status" -eq 0 ]
    [[ "$output" == *MAINTENANCE-RAN* ]]
    [[ "$output" == *"All modules completed successfully"* ]]
}

@test "--run with a failing module runs the rest, names it, and exits 1" {
    failing_module
    printf 'MODULE_TYPE=user\nrun_update() { echo USER-RAN; }\n' > "$INSTALL/modules/50-after.sh"
    run "$INSTALL/update.sh" --run --yes < /dev/null
    [ "$status" -eq 1 ]
    [[ "$output" == *USER-RAN* ]]
    [[ "$output" == *"FINISHED WITH FAILURES"* ]]
    [[ "$output" == *"11-broken.sh (exit 1)"* ]]
}

@test "--dry-run with a failing module exits 1" {
    failing_module
    run "$INSTALL/update.sh" --dry-run --yes <<< c
    [ "$status" -eq 1 ]
    [[ "$output" == *"11-broken.sh (exit 1)"* ]]
}

@test "a run leaves no notes file behind" {
    printf 'MODULE_TYPE=status\nrun_update() { add_run_note "look here"; }\n' > "$INSTALL/modules/90-note.sh"
    run "$INSTALL/update.sh" --run --yes < /dev/null
    [ "$status" -eq 0 ]
    [[ "$output" == *"look here"* ]]
    run ! compgen -G "$XDG_RUNTIME_DIR/update-arch-notes.*"
}

@test "a failed self-update stops the run and exits 1" {
    export UPSTREAM_SHA=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
    run "$INSTALL/update.sh" --run --yes < /dev/null
    [ "$status" -eq 1 ]
    [[ "$output" == *"Failed to download upstream"* ]]
    [[ "$output" == *"Self-update did not complete"* ]]
    [[ "$output" != *MAINTENANCE-RAN* ]]
}

@test "a successful branch-channel self-update stops the run and exits 0" {
    export UPSTREAM_SHA=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
    mkdir -p "$XDG_CONFIG_HOME/update-arch"
    echo 'UPDATE_CHANNEL="branch"' > "$XDG_CONFIG_HOME/update-arch/update-arch.conf"
    install_copy "$BATS_TEST_TMPDIR/upstream/update-arch-main"
    # Shift every byte offset in the upstream update-self.sh. The running
    # copy is overwritten mid-run, and anything it reads after that lands
    # mid-line in the new file.
    local up="$BATS_TEST_TMPDIR/upstream/update-arch-main/update-self.sh"
    { sed -n 1p "$up"; printf '# padding\n%.0s' {1..100}; sed 1d "$up"; } > "$up.new"
    mv "$up.new" "$up" && chmod +x "$up"
    export UPSTREAM_TARBALL="$BATS_TEST_TMPDIR/upstream.tar.gz"
    tar -czf "$UPSTREAM_TARBALL" -C "$BATS_TEST_TMPDIR/upstream" update-arch-main
    run "$INSTALL/update.sh" --run --yes < /dev/null
    [ "$status" -eq 0 ]
    [[ "$output" == *"Update complete"* ]]
    [[ "$output" != *"did not complete"* ]]
    [[ "$output" != *MAINTENANCE-RAN* ]]
}

@test "--only ignores a notes path inherited from the environment" {
    printf 'MODULE_TYPE=status\nrun_update() { add_run_note "look here"; }\n' > "$INSTALL/modules/90-note.sh"
    UPDATE_ARCH_RUN_NOTES="$BATS_TEST_TMPDIR/victim" run "$INSTALL/update.sh" --only note
    [ "$status" -eq 0 ]
    [[ "$output" == *"look here"* ]]
    [ ! -e "$BATS_TEST_TMPDIR/victim" ]
}
