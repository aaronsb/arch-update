# Shared setup for the bats suite.
#
# Each test gets a private HOME and XDG tree under $BATS_TEST_TMPDIR, a stub
# bin dir at the front of PATH, and the update-arch runtime sourced from the
# repo. Nothing touches the real system: sudo, pacman and friends resolve to
# stubs the test writes.

REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." && pwd)"

common_setup() {
    export HOME="$BATS_TEST_TMPDIR/home"
    export XDG_DATA_HOME="$HOME/.local/share"
    export XDG_CONFIG_HOME="$HOME/.config"
    export XDG_STATE_HOME="$HOME/.local/state"
    export XDG_CACHE_HOME="$HOME/.cache"
    export XDG_RUNTIME_DIR="$BATS_TEST_TMPDIR/run"
    export TERM=xterm
    unset DRY_RUN TERM_PROGRAM KITTY_WINDOW_ID ALACRITTY_LOG WEZTERM_PANE
    mkdir -p "$HOME" "$XDG_RUNTIME_DIR"

    STUB_BIN="$BATS_TEST_TMPDIR/bin"
    STUB_LOG="$BATS_TEST_TMPDIR/stub-calls.log"
    mkdir -p "$STUB_BIN"
    : > "$STUB_LOG"
    export PATH="$STUB_BIN:$PATH" STUB_LOG

    MODULE_DIR="$BATS_TEST_TMPDIR/modules"
    mkdir -p "$MODULE_DIR"

    # Pass-through sudo: drop its own flags, run the rest unprivileged.
    stub sudo '
while [[ "$1" == -* ]]; do shift; done
(( $# == 0 )) && exit 0
exec "$@"'

    # shellcheck source=../utils.sh
    source "$REPO_ROOT/utils.sh"
}

# stub NAME BODY — write an executable NAME onto PATH. Every call is recorded
# in $STUB_LOG as "NAME args..." before BODY runs.
stub() {
    local name="$1" body="${2:-exit 0}"
    cat > "$STUB_BIN/$name" <<EOF
#!/bin/bash
echo "$name \$*" >> "\$STUB_LOG"
$body
EOF
    chmod +x "$STUB_BIN/$name"
}

# fixture_module FILE BODY — write a module into $MODULE_DIR.
fixture_module() {
    local file="$1" body="$2"
    printf '#!/bin/bash\n%s\n' "$body" > "$MODULE_DIR/$file"
}

# repo_module FILE — path of a real module in the repo.
repo_module() {
    echo "$REPO_ROOT/modules/$1"
}
