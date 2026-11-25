#!/usr/bin/env bats
# modules/11-nvidia-drivers.sh against a fixture PCI and kernel-modules tree
# and stubbed pacman, modinfo, dkms, systemd-run and depmod.

load test_helper

setup() {
    common_setup
    MODULE="$(repo_module 11-nvidia-drivers.sh)"

    # The host's real pacman, modinfo and dkms sit on PATH behind the stubs,
    # and an absent stub would fall through to them. PATH here holds the stubs
    # and the utilities the module itself calls, nothing else.
    local safe="$BATS_TEST_TMPDIR/safe-bin" tool
    mkdir -p "$safe"
    for tool in awk basename cat chmod cut find grep head mkdir mktemp mv printf rm sed sort tr wc; do
        ln -s "$(command -v "$tool")" "$safe/$tool"
    done
    export PATH="$STUB_BIN:$safe"

    STATE="$BATS_TEST_TMPDIR/state"
    mkdir -p "$STATE/modver"
    export STATE
    export NVIDIA_PCI_ROOT="$BATS_TEST_TMPDIR/pci"
    export NVIDIA_MODULES_ROOT="$BATS_TEST_TMPDIR/modules-root"
    export NVIDIA_LOADED_VERSION_FILE="$BATS_TEST_TMPDIR/loaded-version"
    export NVIDIA_DKMS_SOURCE_ROOT="$BATS_TEST_TMPDIR/usr-src"
    mkdir -p "$NVIDIA_PCI_ROOT" "$NVIDIA_MODULES_ROOT" "$NVIDIA_DKMS_SOURCE_ROOT"

    # Package state the stubs read and write: one name per line.
    : > "$STATE/installed"
    : > "$STATE/repo"
    : > "$STATE/pending"
    : > "$STATE/dkms-status"
    : > "$STATE/provides"
    : > "$STATE/extra-deps"
    echo 0 > "$STATE/systemctl-active"
    export STUB_UTILS_VER="620.73.04-1"

    stub_pacman
    stub_modinfo
    stub_dkms
    stub systemd-run '
while [[ "$1" == -* ]]; do shift; done
exec "'"$STUB_BIN"'/$1" "${@:2}"'
    stub depmod 'exit 0'
    stub sleep 'exit 0'
    # is-active answers "active" as many times as systemctl-active says.
    stub systemctl '
n=$(cat "$STATE/systemctl-active")
(( n > 0 )) || exit 3
echo $((n - 1)) > "$STATE/systemctl-active"'
    start_run_record
}

notes() { cat "$UPDATE_ARCH_RUN_NOTES" 2>/dev/null; }

# pci_device NAME VENDOR CLASS
pci_device() {
    mkdir -p "$NVIDIA_PCI_ROOT/$1"
    echo "$2" > "$NVIDIA_PCI_ROOT/$1/vendor"
    echo "$3" > "$NVIDIA_PCI_ROOT/$1/class"
}

nvidia_gpu() { pci_device 0000:01:00.0 0x10de 0x030000; }

# kernel KVER PKGBASE [MODVER] — an installed kernel, optionally with an
# nvidia module of MODVER already built for it.
kernel() {
    mkdir -p "$NVIDIA_MODULES_ROOT/$1"
    echo "$2" > "$NVIDIA_MODULES_ROOT/$1/pkgbase"
    [[ -n "${3:-}" ]] && echo "$3" > "$STATE/modver/$1"
    return 0
}

installed() { printf '%s\n' "$@" >> "$STATE/installed"; }
in_repo()   { printf '%s\n' "$@" >> "$STATE/repo"; }
# provides PACKAGE NAME — an installed PACKAGE also answers pacman -Q NAME.
provides()  { echo "$1 $2" >> "$STATE/provides"; }
# dkms_source VERSION — a package ships /usr/src/nvidia-VERSION/dkms.conf.
dkms_source() { mkdir -p "$NVIDIA_DKMS_SOURCE_ROOT/nvidia-$1"; : > "$NVIDIA_DKMS_SOURCE_ROOT/nvidia-$1/dkms.conf"; }

# pacman -Q and -Qq answer for a package or for an installed package that
# provides the name, as real pacman does; -Si matches names only. pacman -S
# installs the named packages, drops nvidia-open-dkms (the --ask 4 conflict
# answer), and puts the prebuilt module in place for every kernel.
stub_pacman() {
    stub pacman '
owner() {
    grep -qx "$1" "$STATE/installed" && { echo "$1"; return 0; }
    local pkg name
    while read -r pkg name; do
        [[ "$name" == "$1" ]] && grep -qx "$pkg" "$STATE/installed" && { echo "$pkg"; return 0; }
    done < "$STATE/provides"
    return 1
}
case "$1" in
    -Qq) owner "$2" ;;
    -Q)  o=$(owner "$2") || exit 1; echo "$o $STUB_UTILS_VER" ;;
    -Si) grep -qx "$2" "$STATE/repo" ;;
    -Qu) cat "$STATE/pending" ;;
    -Sp) shift 3; printf "%s\n" "$@"; cat "$STATE/extra-deps" ;;
    -S)
        [[ -n "${STUB_PACMAN_S_RC:-}" ]] && exit "$STUB_PACMAN_S_RC"
        shift
        while [[ "$1" == -* ]]; do [[ "$1" == --ask ]] && shift; shift; done
        grep -vx nvidia-open-dkms "$STATE/installed" > "$STATE/installed.new"
        mv "$STATE/installed.new" "$STATE/installed"
        rm -rf "$NVIDIA_DKMS_SOURCE_ROOT"/nvidia-*
        printf "%s\n" "$@" >> "$STATE/installed"
        for d in "$NVIDIA_MODULES_ROOT"/*/; do
            d="${d%/}"; echo "${STUB_UTILS_VER%-*}" > "$STATE/modver/${d##*/}"
        done ;;
esac'
}

stub_modinfo() {
    stub modinfo '
[[ "$1" == -k ]] || exit 1
cat "$STATE/modver/$2" 2>/dev/null || { echo "modinfo: ERROR: Module nvidia not found." >&2; exit 1; }'
}

stub_dkms() {
    stub dkms '
case "$1" in
    status) cat "$STATE/dkms-status" ;;
    install)
        [[ -n "${STUB_DKMS_RC:-}" ]] && exit "$STUB_DKMS_RC"
        ver="${2#nvidia/}"; echo "$ver" > "$STATE/modver/$4" ;;
    remove)
        [[ -n "${STUB_DKMS_REMOVE_RC:-}" ]] && exit "$STUB_DKMS_REMOVE_RC"
        : > "$STATE/dkms-status" ;;
esac'
}

# --- detection ------------------------------------------------------------

@test "runs after the AUR module" {
    local order aur nvidia
    order=$(find "$REPO_ROOT/modules" -maxdepth 1 -name '[0-4][0-9]-*.sh' | LC_ALL=C sort)
    aur=$(grep -n '/11-aur-update\.sh$' <<< "$order" | cut -d: -f1)
    nvidia=$(grep -n '/11-nvidia-drivers\.sh$' <<< "$order" | cut -d: -f1)
    [ -n "$aur" ] && [ -n "$nvidia" ]
    (( aur < nvidia ))
}

@test "a machine with no NVIDIA device skips the module" {
    pci_device 0000:00:02.0 0x1002 0x030000
    run run_module "$MODULE" system
    [ "$status" -eq 0 ]
    [[ "$output" == *"not supported"* ]]
    run ! grep -q '^pacman' "$STUB_LOG"
}

@test "an NVIDIA audio function alone does not count as a GPU" {
    pci_device 0000:01:00.1 0x10de 0x040300
    run run_module "$MODULE" system
    [[ "$output" == *"not supported"* ]]
}

@test "without nvidia-utils there is nothing to check" {
    nvidia_gpu
    kernel 7.3.5-arch1-1 linux
    run run_module "$MODULE" system
    [ "$status" -eq 0 ]
    [[ "$output" == *"nvidia-utils is not installed"* ]]
}

# --- prebuilt switch ------------------------------------------------------

# A DKMS machine as Arch ships it: nvidia-open-dkms provides nvidia-open, so
# pacman -Q nvidia-open answers with nvidia-open-dkms, and its source sits in
# /usr/src.
dkms_machine() {
    installed nvidia-utils nvidia-open-dkms dkms
    provides nvidia-open-dkms nvidia-open
    dkms_source 620.73.04
}

@test "nvidia-open-dkms switches to prebuilt modules for linux and linux-lts" {
    nvidia_gpu
    kernel 7.3.5-arch1-1 linux
    kernel 6.18.64-1-lts linux-lts
    dkms_machine
    in_repo nvidia-open nvidia-open-lts
    echo "nvidia/620.73.04: added" > "$STATE/dkms-status"
    echo 620.73.04 > "$NVIDIA_LOADED_VERSION_FILE"

    run run_module "$MODULE" system
    [ "$status" -eq 0 ]
    grep -qx 'sudo pacman -S --needed --noconfirm --ask 4 nvidia-open nvidia-open-lts' "$STUB_LOG"
    [[ "$output" == *"7.3.5-arch1-1 (linux): nvidia 620.73.04"* ]]
    [[ "$output" == *"6.18.64-1-lts (linux-lts): nvidia 620.73.04"* ]]
    # The "added" entry outlives the package that shipped its source.
    grep -qx 'sudo dkms remove nvidia/620.73.04 --all' "$STUB_LOG"
    run ! grep -q '^dkms install' "$STUB_LOG"
}

@test "a kernel with no prebuilt package keeps the machine on DKMS" {
    nvidia_gpu
    kernel 7.3.5-arch1-1 linux 620.73.04
    kernel 7.3.5-zen1-1-zen linux-zen 620.73.04
    dkms_machine
    in_repo nvidia-open nvidia-open-lts
    echo "nvidia/620.73.04, 7.3.5-arch1-1, x86_64: installed" > "$STATE/dkms-status"

    run run_module "$MODULE" system
    [ "$status" -eq 0 ]
    [[ "$output" == *"Staying on nvidia-open-dkms: no prebuilt module for linux-zen"* ]]
    run ! grep -qE '^pacman -S |^dkms remove' "$STUB_LOG"
}

@test "pending upgrades postpone the switch" {
    nvidia_gpu
    kernel 7.3.5-arch1-1 linux 620.73.04
    dkms_machine
    in_repo nvidia-open
    echo "linux 7.3.5.arch1-1 -> 7.3.6.arch1-1" > "$STATE/pending"
    echo "nvidia/620.73.04, 7.3.5-arch1-1, x86_64: installed" > "$STATE/dkms-status"

    run run_module "$MODULE" system
    [ "$status" -eq 0 ]
    [[ "$(notes)" == *"prebuilt switch skipped"* ]]
    run ! grep -q '^pacman -S ' "$STUB_LOG"
}

@test "packages held by IgnorePkg do not postpone the switch" {
    nvidia_gpu
    kernel 7.3.5-arch1-1 linux
    dkms_machine
    in_repo nvidia-open
    echo "firefox 140.0-1 -> 141.0-1 [ignored]" > "$STATE/pending"
    echo "nvidia/620.73.04: added" > "$STATE/dkms-status"

    run run_module "$MODULE" system
    [ "$status" -eq 0 ]
    grep -qx 'sudo pacman -S --needed --noconfirm --ask 4 nvidia-open' "$STUB_LOG"
}

@test "a transaction that pulls in other packages is not run" {
    nvidia_gpu
    kernel 7.3.5-arch1-1 linux 620.73.04
    dkms_machine
    in_repo nvidia-open
    echo "egl-wayland" > "$STATE/extra-deps"
    echo "nvidia/620.73.04, 7.3.5-arch1-1, x86_64: installed" > "$STATE/dkms-status"

    run run_module "$MODULE" system
    [ "$status" -eq 0 ]
    [[ "$(notes)" == *"brings in other packages"* ]]
    run ! grep -q '^pacman -S ' "$STUB_LOG"
}

@test "a beta userspace is never swapped for nvidia-utils" {
    nvidia_gpu
    kernel 7.3.5-arch1-1 linux 620.73.04
    installed nvidia-utils-beta nvidia-open-dkms dkms
    provides nvidia-utils-beta nvidia-utils
    provides nvidia-open-dkms nvidia-open
    dkms_source 620.73.04
    in_repo nvidia-open
    echo "nvidia/620.73.04, 7.3.5-arch1-1, x86_64: installed" > "$STATE/dkms-status"

    run run_module "$MODULE" system
    [ "$status" -eq 0 ]
    [[ "$output" == *"userspace is nvidia-utils-beta"* ]]
    run ! grep -q '^pacman -S ' "$STUB_LOG"
}

@test "a prebuilt machine gets the package for a newly added kernel" {
    nvidia_gpu
    kernel 7.3.5-arch1-1 linux 620.73.04
    kernel 6.18.64-1-lts linux-lts
    installed nvidia-utils nvidia-open
    in_repo nvidia-open nvidia-open-lts

    run run_module "$MODULE" system
    [ "$status" -eq 0 ]
    grep -qx 'sudo pacman -S --needed --noconfirm --ask 4 nvidia-open-lts' "$STUB_LOG"
}

@test "a failed prebuilt install fails the module" {
    # The kernel already has its module, so the install is the only failure.
    nvidia_gpu
    kernel 7.3.5-arch1-1 linux 620.73.04
    dkms_machine
    in_repo nvidia-open
    echo "nvidia/620.73.04, 7.3.5-arch1-1, x86_64: installed" > "$STATE/dkms-status"
    export STUB_PACMAN_S_RC=1

    run run_module "$MODULE" system
    [ "$status" -ne 0 ]
    [[ "$output" == *"Could not install nvidia-open"* ]]
    [[ "$output" == *"7.3.5-arch1-1 (linux): nvidia 620.73.04"* ]]
}

@test "dry run names the switch and changes nothing" {
    nvidia_gpu
    kernel 7.3.5-arch1-1 linux
    kernel 6.18.64-1-lts linux-lts
    dkms_machine
    in_repo nvidia-open nvidia-open-lts
    echo "nvidia/620.73.04: added" > "$STATE/dkms-status"

    DRY_RUN=1 run run_module "$MODULE" system
    [ "$status" -eq 0 ]
    [[ "$output" == *"Would install nvidia-open nvidia-open-lts"* ]]
    [[ "$output" == *"Would remove nvidia-open-dkms"* ]]
    run ! grep -qE '^(pacman -S |dkms (install|remove)|systemd-run)' "$STUB_LOG"
}

# --- DKMS entries ---------------------------------------------------------

@test "a DKMS entry whose package still ships the source is kept" {
    # An AUR beta driver: it provides nvidia-open but is not nvidia-open-dkms.
    nvidia_gpu
    kernel 7.3.5-arch1-1 linux 620.73.04
    installed nvidia-utils nvidia-open-beta-dkms dkms
    provides nvidia-open-beta-dkms nvidia-open
    dkms_source 620.73.04
    echo "nvidia/620.73.04, 7.3.5-arch1-1, x86_64: installed" > "$STATE/dkms-status"

    run run_module "$MODULE" system
    [ "$status" -eq 0 ]
    run ! grep -qE '^(dkms remove|pacman -S )' "$STUB_LOG"
}

@test "a stale DKMS entry that will not go away gets a note" {
    nvidia_gpu
    kernel 7.3.5-arch1-1 linux 620.73.04
    installed nvidia-utils nvidia-open dkms
    echo "nvidia/620.73.04: added" > "$STATE/dkms-status"
    export STUB_DKMS_REMOVE_RC=1

    run run_module "$MODULE" system
    [ "$status" -eq 0 ]
    [[ "$(notes)" == *"Stale DKMS entry nvidia/620.73.04 has no source"* ]]
}

# --- verification ---------------------------------------------------------

@test "a missing DKMS build is rebuilt and indexed in a transient unit" {
    nvidia_gpu
    kernel 7.3.5-zen1-1-zen linux-zen
    dkms_machine
    echo "nvidia/620.73.04: added" > "$STATE/dkms-status"

    run run_module "$MODULE" system
    [ "$status" -eq 0 ]
    # Without --no-depmod, dkms runs depmod itself, inside the unit.
    grep -qx 'systemd-run --quiet --wait --pipe --collect --unit=update-arch-dkms-nvidia-7-3-5-zen1-1-zen dkms install nvidia/620.73.04 -k 7.3.5-zen1-1-zen' "$STUB_LOG"
    [[ "$output" == *"nvidia 620.73.04 (rebuilt)"* ]]
    run ! grep -q '^depmod' "$STUB_LOG"
}

@test "a build still running from an earlier run is waited for" {
    nvidia_gpu
    kernel 7.3.5-zen1-1-zen linux-zen
    dkms_machine
    echo "nvidia/620.73.04: added" > "$STATE/dkms-status"
    echo 2 > "$STATE/systemctl-active"

    run run_module "$MODULE" system
    [ "$status" -eq 0 ]
    [[ "$output" == *"Waiting for an earlier build"* ]]
    [ "$(grep -c '^sleep' "$STUB_LOG")" -eq 2 ]
    grep -q '^systemd-run ' "$STUB_LOG"
}

@test "a DKMS build that still fails names the kernel and fails the module" {
    nvidia_gpu
    kernel 7.3.5-zen1-1-zen linux-zen
    dkms_machine
    echo "nvidia/620.73.04: added" > "$STATE/dkms-status"
    export STUB_DKMS_RC=10

    run run_module "$MODULE" system
    [ "$status" -ne 0 ]
    [[ "$(notes)" == *"Kernel 7.3.5-zen1-1-zen has no NVIDIA 620.73.04 module"* ]]
}

@test "a proprietary DKMS driver is verified but never switched" {
    nvidia_gpu
    kernel 7.3.5-arch1-1 linux 620.73.04
    installed nvidia-utils nvidia-dkms dkms
    dkms_source 620.73.04
    in_repo nvidia-open
    echo "nvidia/620.73.04, 7.3.5-arch1-1, x86_64: installed" > "$STATE/dkms-status"

    run run_module "$MODULE" system
    [ "$status" -eq 0 ]
    run ! grep -qE '^(pacman -S |dkms remove)' "$STUB_LOG"
}

@test "a kernel directory with no pkgbase is not checked" {
    nvidia_gpu
    kernel 7.3.5-arch1-1 linux 620.73.04
    mkdir -p "$NVIDIA_MODULES_ROOT/7.2.11-arch1-1"
    installed nvidia-utils nvidia-open

    run run_module "$MODULE" system
    [ "$status" -eq 0 ]
    [[ "$output" != *"7.2.11"* ]]
}

# --- loaded driver --------------------------------------------------------

@test "an older loaded driver asks for a reboot" {
    nvidia_gpu
    kernel 7.3.5-arch1-1 linux 620.73.04
    installed nvidia-utils nvidia-open
    echo 620.70.06 > "$NVIDIA_LOADED_VERSION_FILE"

    run run_module "$MODULE" system
    [ "$status" -eq 0 ]
    [[ "$(notes)" == *"620.70.06 is loaded and 620.73.04 is installed"* ]]
}

@test "no loaded driver asks for a reboot" {
    nvidia_gpu
    kernel 7.3.5-arch1-1 linux 620.73.04
    installed nvidia-utils nvidia-open

    run run_module "$MODULE" system
    [[ "$(notes)" == *"not loaded in this boot"* ]]
}

@test "a current loaded driver adds no note" {
    nvidia_gpu
    kernel 7.3.5-arch1-1 linux 620.73.04
    installed nvidia-utils nvidia-open
    echo 620.73.04 > "$NVIDIA_LOADED_VERSION_FILE"

    run run_module "$MODULE" system
    [ -z "$(notes)" ]
}
