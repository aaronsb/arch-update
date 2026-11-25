#!/bin/bash
# Keep the NVIDIA kernel driver in step with every installed kernel.
#
# Runs after 11-aur-update.sh: "11-nvidia" sorts after "11-aur", so every
# kernel and driver package the run is going to install is already in place.
# tests/nvidia-drivers.bats pins the order.
#
# Three jobs, in order:
#   1. Move nvidia-open-dkms to Arch's prebuilt modules (nvidia-open for linux,
#      nvidia-open-lts for linux-lts) when every installed kernel has one. The
#      prebuilt packages are the same driver release, built by Arch alongside
#      each kernel, so an upgrade copies files instead of compiling for
#      minutes; a compile cut short by a signal leaves the next boot with no
#      driver and nothing in the update's output to say so.
#   2. Check that every installed kernel, not only the running one, has an
#      nvidia module at the version nvidia-utils expects. A DKMS build that is
#      missing is rebuilt outside the terminal's session, so a hangup cannot
#      stop it the same way.
#   3. Say when the loaded driver is not the installed one: a reboot is due.

MODULE_TYPE="system"
MODULE_NAME="nvidia-drivers"
MODULE_DESCRIPTION="Prefer prebuilt NVIDIA modules and verify one exists for every kernel"
MODULE_REQUIRES="pacman modinfo"
MODULE_DRY_RUN_SAFE="true"

# Overridable so the tests can point them at a fixture tree.
NVIDIA_PCI_ROOT="${NVIDIA_PCI_ROOT:-/sys/bus/pci/devices}"
NVIDIA_MODULES_ROOT="${NVIDIA_MODULES_ROOT:-/usr/lib/modules}"
NVIDIA_LOADED_VERSION_FILE="${NVIDIA_LOADED_VERSION_FILE:-/sys/module/nvidia/version}"
NVIDIA_DKMS_SOURCE_ROOT="${NVIDIA_DKMS_SOURCE_ROOT:-/usr/src}"
NVIDIA_BUILD_WAIT_LIMIT="${NVIDIA_BUILD_WAIT_LIMIT:-1800}"

# An NVIDIA display controller: vendor 0x10de, PCI class 0x03xxxx (VGA, 3D,
# display). The vendor's audio and USB functions on the same card do not count.
nvidia_gpu_present() {
    local dev vendor class
    for dev in "$NVIDIA_PCI_ROOT"/*; do
        [[ -r "$dev/vendor" && -r "$dev/class" ]] || continue
        vendor=$(<"$dev/vendor")
        class=$(<"$dev/class")
        [[ "$vendor" == "0x10de" && "$class" == 0x03* ]] && return 0
    done
    return 1
}

check_supported() {
    command -v pacman &>/dev/null && command -v modinfo &>/dev/null && nvidia_gpu_present
}

# installed_kernels — "KVER PKGBASE" for each kernel a package installed. The
# pkgbase file is package-owned, so a directory a removed kernel left behind
# (holding only DKMS output) is not listed.
installed_kernels() {
    local dir
    for dir in "$NVIDIA_MODULES_ROOT"/*/; do
        dir="${dir%/}"
        [[ -r "$dir/pkgbase" ]] || continue
        printf '%s %s\n' "${dir##*/}" "$(<"$dir/pkgbase")"
    done
}

# prebuilt_name PKGBASE — the repo package carrying the open module built for
# that kernel: linux -> nvidia-open, linux-lts -> nvidia-open-lts.
prebuilt_name() {
    if [[ "$1" == "linux" ]]; then
        echo "nvidia-open"
    else
        echo "nvidia-open-${1#linux-}"
    fi
}

# pkg_installed NAME — NAME itself is installed. pacman -Q also answers for a
# package that only provides NAME (nvidia-open-dkms provides nvidia-open), so
# compare the name it prints.
pkg_installed() { [[ "$(pacman -Qq "$1" 2>/dev/null)" == "$1" ]]; }
pkg_in_repos()  { pacman -Si "$1" &>/dev/null; }

# expected_version — the driver version the installed userspace ships, without
# pkgrel. Answers for nvidia-utils or a package providing it (a beta build).
expected_version() {
    local ver
    ver=$(pacman -Q nvidia-utils 2>/dev/null | awk '{print $2}')
    [[ -n "$ver" ]] || return 1
    ver="${ver#*:}"
    echo "${ver%-*}"
}

# module_version KVER — the version of the nvidia module that kernel would load.
module_version() {
    modinfo -k "$1" -F version nvidia 2>/dev/null
}

# Install the prebuilt package for each kernel that lacks it. --ask 4 answers
# yes to removing nvidia-open-dkms, which conflicts with them; with
# --noconfirm alone pacman declines and the transaction fails.
use_prebuilt_modules() {
    local -a kernels=("$@") wanted=() missing=()
    local line pkgbase name

    for line in "${kernels[@]}"; do
        pkgbase="${line#* }"
        name=$(prebuilt_name "$pkgbase")
        if pkg_installed "$name"; then
            continue
        elif pkg_in_repos "$name"; then
            wanted+=("$name")
        else
            missing+=("$pkgbase")
        fi
    done

    (( ${#wanted[@]} > 0 )) || return 0
    mapfile -t wanted < <(printf '%s\n' "${wanted[@]}" | LC_ALL=C sort)

    if (( ${#missing[@]} > 0 )); then
        if pkg_installed nvidia-open-dkms; then
            print_status "${ICONS[info]}" "Staying on nvidia-open-dkms: no prebuilt module for ${missing[*]}"
            return 0
        fi
        print_warning "No prebuilt NVIDIA module for ${missing[*]}; those kernels need nvidia-open-dkms"
        add_run_note "No prebuilt NVIDIA module for ${missing[*]}; switch to nvidia-open-dkms to run them"
    fi

    # The prebuilt packages require the repo's nvidia-utils. With a beta or
    # other replacement userspace installed, installing them would swap it out.
    if ! pkg_installed nvidia-utils; then
        print_status "${ICONS[info]}" "Leaving NVIDIA packages alone: userspace is $(pacman -Qq nvidia-utils 2>/dev/null), not nvidia-utils"
        return 0
    fi

    # Installing new packages against a sync database that has updates pending
    # is a partial upgrade. Leave the switch for a run where pacman is current.
    # Packages held back by IgnorePkg stay pending on purpose and do not count.
    if [[ -n "$(pacman -Qu 2>/dev/null | grep -v '\[ignored\]$')" ]]; then
        print_warning "System has pending upgrades; not switching NVIDIA packages this run"
        add_run_note "NVIDIA prebuilt switch skipped: upgrade the system first (pacman -Syu)"
        return 0
    fi

    # --ask 4 accepts every conflict in the transaction, not only
    # nvidia-open-dkms. Go ahead only when the transaction installs exactly the
    # wanted packages, so no dependency can pull in a conflict of its own.
    local planned
    planned=$(pacman -Sp --print-format '%n' "${wanted[@]}" 2>/dev/null | LC_ALL=C sort)
    if [[ "$planned" != "$(printf '%s\n' "${wanted[@]}")" ]]; then
        print_warning "Installing ${wanted[*]} would also change other packages; not switching"
        add_run_note "NVIDIA prebuilt switch skipped: installing ${wanted[*]} brings in other packages; review with pacman -Sp ${wanted[*]}"
        return 0
    fi

    if [[ -n "$DRY_RUN" ]]; then
        print_status "${ICONS[info]}" "Would install ${wanted[*]}"
        pkg_installed nvidia-open-dkms && print_status "${ICONS[info]}" "Would remove nvidia-open-dkms"
        return 0
    fi

    print_status "${ICONS[package]}" "Installing prebuilt NVIDIA modules: ${wanted[*]}"
    if ! sudo pacman -S --needed --noconfirm --ask 4 "${wanted[@]}"; then
        print_warning "Could not install ${wanted[*]}"
        return 1
    fi
    print_success "Prebuilt NVIDIA modules installed"
}

# dkms_nvidia_version — the version of the DKMS nvidia entry, if any.
# dkms status prints "nvidia/620.73.04: added" or
# "nvidia/620.73.04, 7.3.5-arch1-1, x86_64: installed".
dkms_nvidia_version() {
    command -v dkms &>/dev/null || return 0
    dkms status nvidia 2>/dev/null | head -1 | sed -E 's|^nvidia/([^,:]+).*|\1|'
}

dkms_source_present() {
    [[ -e "$NVIDIA_DKMS_SOURCE_ROOT/nvidia-$1/dkms.conf" ]]
}

uses_dkms() {
    local ver
    ver=$(dkms_nvidia_version)
    [[ -n "$ver" ]] && dkms_source_present "$ver"
}

# A DKMS nvidia entry whose source is gone, for instance one left "added" by a
# killed build after nvidia-open-dkms was removed, names a module nothing can
# build. An entry whose package still ships the source is in use and stays.
clear_stale_dkms_entry() {
    local ver
    ver=$(dkms_nvidia_version)
    [[ -n "$ver" ]] || return 0
    dkms_source_present "$ver" && return 0

    if [[ -n "$DRY_RUN" ]]; then
        print_status "${ICONS[info]}" "Would remove stale DKMS entry nvidia/$ver"
        return 0
    fi
    sudo dkms remove "nvidia/$ver" --all &>/dev/null
    if [[ -n "$(dkms_nvidia_version)" ]]; then
        print_warning "Could not remove stale DKMS entry nvidia/$ver"
        add_run_note "Stale DKMS entry nvidia/$ver has no source; remove it with: sudo dkms remove nvidia/$ver --all"
    fi
}

# rebuild_dkms VERSION KVER — build the DKMS module in a transient systemd
# unit. The unit is not in the terminal's session, so closing the terminal or
# a Ctrl-C does not stop the compile partway, and it finishes even if this
# run is killed. dkms runs depmod itself when it is not given --no-depmod, so
# the module is indexed inside the same unit.
rebuild_dkms() {
    local ver="$1" kver="$2" waited=0
    local unit="update-arch-dkms-nvidia-${kver//[^A-Za-z0-9]/-}"

    # A unit started by an earlier run that was killed may still be compiling.
    while systemctl is-active --quiet "$unit"; do
        (( waited == 0 )) && print_status "${ICONS[info]}" "Waiting for an earlier build ($unit) to finish..."
        if (( waited >= NVIDIA_BUILD_WAIT_LIMIT )); then
            print_warning "$unit is still running after ${NVIDIA_BUILD_WAIT_LIMIT}s"
            return 1
        fi
        sleep 10
        waited=$((waited + 10))
    done

    print_status "${ICONS[package]}" "Building nvidia/$ver for $kver (DKMS)..."
    sudo systemd-run --quiet --wait --pipe --collect --unit="$unit" \
        dkms install "nvidia/$ver" -k "$kver"
}

# verify_kernels VERSION KERNEL... — every kernel has an nvidia module at
# VERSION, rebuilding a DKMS one that is missing. Returns 1 if any kernel
# still lacks one.
verify_kernels() {
    local ver="$1"; shift
    local line kver pkgbase have failed=0
    for line in "$@"; do
        kver="${line%% *}"
        pkgbase="${line#* }"
        have=$(module_version "$kver")
        if [[ "$have" == "$ver" ]]; then
            print_success "$kver ($pkgbase): nvidia $ver"
            continue
        fi

        if uses_dkms; then
            if [[ -n "$DRY_RUN" ]]; then
                print_status "${ICONS[info]}" "Would build nvidia/$ver for $kver (has: ${have:-none})"
                continue
            fi
            rebuild_dkms "$ver" "$kver"
            have=$(module_version "$kver")
            if [[ "$have" == "$ver" ]]; then
                print_success "$kver ($pkgbase): nvidia $ver (rebuilt)"
                continue
            fi
        elif [[ -n "$DRY_RUN" ]]; then
            print_status "${ICONS[info]}" "$kver ($pkgbase) has nvidia ${have:-none}, expected $ver"
            continue
        fi

        print_warning "$kver ($pkgbase): no nvidia $ver module (has: ${have:-none})"
        add_run_note "Kernel $kver has no NVIDIA $ver module: booting it leaves the NVIDIA GPU without a driver"
        failed=1
    done
    return "$failed"
}

report_loaded_driver() {
    local ver="$1" loaded=""
    [[ -r "$NVIDIA_LOADED_VERSION_FILE" ]] && loaded=$(<"$NVIDIA_LOADED_VERSION_FILE")
    if [[ -z "$loaded" ]]; then
        add_run_note "NVIDIA driver is not loaded in this boot; reboot to load $ver"
    elif [[ "$loaded" != "$ver" ]]; then
        add_run_note "NVIDIA driver $loaded is loaded and $ver is installed; reboot to use $ver"
    fi
}

run_update() {
    print_header "${ICONS[package]} NVIDIA DRIVERS"

    print_section_box \
        "About NVIDIA Drivers" \
        "The NVIDIA kernel module must match each installed kernel\nArch builds nvidia-open and nvidia-open-lts with the kernels; DKMS compiles on this machine instead" \
        "https://wiki.archlinux.org/title/NVIDIA"

    local ver
    if ! ver=$(expected_version); then
        print_status "${ICONS[info]}" "nvidia-utils is not installed; nothing to check"
        return 0
    fi

    local -a kernels
    mapfile -t kernels < <(installed_kernels)
    if (( ${#kernels[@]} == 0 )); then
        print_warning "No installed kernels found under $NVIDIA_MODULES_ROOT"
        return 1
    fi

    local failed=0
    # Only the open driver has prebuilt packages; proprietary and legacy
    # builds (nvidia-dkms, nvidia-580xx-dkms) are verified but left alone.
    if pkg_installed nvidia-open-dkms || pkg_installed nvidia-open || pkg_installed nvidia-open-lts; then
        use_prebuilt_modules "${kernels[@]}" || failed=1
    fi
    clear_stale_dkms_entry

    verify_kernels "$ver" "${kernels[@]}" || failed=1
    report_loaded_driver "$ver"

    if (( failed )); then
        print_error "NVIDIA driver is missing for at least one kernel"
        return 1
    fi
    [[ -n "$DRY_RUN" ]] || print_success "NVIDIA driver present for every installed kernel"
}
