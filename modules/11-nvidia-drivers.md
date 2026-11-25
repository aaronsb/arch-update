# NVIDIA Drivers Module

## Overview
This system module keeps the NVIDIA kernel driver in step with every installed kernel. It moves the open driver from DKMS to Arch's prebuilt packages when it can. It then checks that each installed kernel has an `nvidia` module at the version `nvidia-utils` expects, and says when a reboot is needed to load it.

A machine with no NVIDIA display controller skips the module.

## Type
System Module (10-49 priority range)

## Ordering
Runs after `11-aur-update.sh`. Modules run in file-name order, and `11-nvidia` sorts after `11-aur`. By then pacman and the AUR helper have installed every kernel and driver package the run brings in, so the check sees the kernels the next boot can choose.

`tests/nvidia-drivers.bats` checks this order.

## Dependencies
- pacman
- modinfo (kmod)
- An NVIDIA PCI display controller: vendor `0x10de`, class `0x03xxxx`
- dkms and systemd-run, only when a DKMS build has to be rebuilt

## Why prebuilt
`nvidia-open-dkms` compiles the driver on the machine after every kernel or driver upgrade, which takes minutes per kernel. If that compile is cut short, for example by a closed terminal or a Ctrl-C during the upgrade, pacman still finishes and reports success. The next boot has no NVIDIA driver, and on a hybrid laptop that can mean no external displays.

`nvidia-open` (for `linux`) and `nvidia-open-lts` (for `linux-lts`) are the same driver release, built by Arch with each kernel. An upgrade installs the kernel and its matching module in one transaction and compiles nothing.

DKMS is still the right choice for kernels Arch builds no NVIDIA package for, such as `linux-zen` or a custom kernel. The module only switches when every installed kernel has a prebuilt package.

## Operation
1. **Detect:** reads `/sys/bus/pci/devices/*/{vendor,class}`. The NVIDIA audio and USB functions on the same card do not count.
2. **Expected version:** the version of the installed `nvidia-utils`, without the package release. Without `nvidia-utils` the module reports nothing to check.
3. **Kernels:** each `/usr/lib/modules/<version>/pkgbase` names a kernel package. A directory with no `pkgbase`, left behind by a removed kernel, is ignored.
4. **Prebuilt switch** (open driver only): for each kernel, the package `nvidia-open` (`linux`) or `nvidia-open-<suffix>` (`linux-<suffix>`). Missing ones that exist in the repos are installed with `pacman -S --needed --noconfirm --ask 4`, which also removes `nvidia-open-dkms`.
   - If any kernel has no prebuilt package and `nvidia-open-dkms` is installed, the machine stays on DKMS.
   - If `pacman -Qu` lists pending upgrades, the switch waits for a run where the system is current, because installing against a stale sync database is a partial upgrade.
   - A DKMS `nvidia` entry left after the switch (for example one stuck at `added` by a killed build) is removed.
5. **Verify:** `modinfo -k <version> -F version nvidia` for every kernel. A DKMS module that is missing or at the wrong version is rebuilt with `dkms install --no-depmod` inside a transient unit (`systemd-run --wait --pipe`), followed by `depmod -a`. The unit is outside the terminal's session, so a hangup or Ctrl-C cannot stop the compile partway.
6. **Loaded driver:** compares `/sys/module/nvidia/version` with the expected version and adds a reboot note when they differ or no driver is loaded.

The proprietary and legacy drivers (`nvidia-dkms`, AUR `nvidia-580xx-dkms`) are verified and rebuilt but never switched.

## Dry Run
- Names the packages that would be installed, and `nvidia-open-dkms` if it would be removed.
- Names each kernel whose module would be rebuilt, or that lacks one.
- Changes nothing.

## Error Handling
- The module fails when any installed kernel ends the run without an `nvidia` module at the expected version, or when the prebuilt install fails. The summary names the kernel: booting it leaves the GPU without a driver.
- A skipped switch (pending upgrades, a kernel with no prebuilt package) is a run note, not a failure.
- A needed reboot is a run note.

## Related Documentation
- [Arch Wiki - NVIDIA](https://wiki.archlinux.org/title/NVIDIA)
- [Arch Wiki - DKMS](https://wiki.archlinux.org/title/Dynamic_Kernel_Module_Support)
