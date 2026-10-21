# Toolchains Update Module

## Overview
This system module updates language toolchains and tools that pacman does not manage: rustup's Rust toolchains, binaries installed with `go install`, and Python tools installed with uv or pipx. It reports outdated global npm packages without changing them.

## Type
System Module (10-19 priority range)

## Ordering
Runs after `10-pacman-update.sh` and before `11-aur-update.sh`. Modules run in file-name order, and `10-toolchains` sorts after `10-pacman`.
- pacman runs first because it upgrades `go`, `npm` and `uv` themselves.
- The AUR runs after because its builds compile with these toolchains. A crate that raises its minimum Rust version fails to build against a stale rustup stable.

`tests/toolchains-update.bats` checks this order.

## Dependencies
Any of the following; each step is skipped when its tool is absent:
- rustup
- go
- uv
- pipx
- npm

## Operation
1. **Rust:** `rustup update --no-self-update` updates the channel toolchains (stable, nightly, a `1.96` channel). Pinned toolchains such as `1.92.0` are left alone.
2. **Go:** each binary in `GOBIN` (or `$GOPATH/bin`) built with an older Go than the system's is rebuilt with `go install <path>@<version>`, at the module version it already has. A Go binary carries the standard library it was built with, so a `crypto/tls` or `crypto/x509` fix reaches it only through a rebuild.
3. **Python:** `uv tool upgrade --all` and `pipx upgrade-all`, each run only when that tool has something installed.
4. **npm:** `npm outdated -g` is reported as a run note. Global packages share `/usr/lib/node_modules` with pacman's own npm, so this module does not update them.

## Dry Run
- `rustup check` lists available toolchain updates.
- Go binaries that would be rebuilt are named with their old and new Go versions.
- The uv and pipx commands that would run are printed.
- The npm report runs as usual.

## Error Handling
- A failed step does not stop the remaining steps.
- The module fails if rustup, a Go rebuild, uv or pipx fails.
- A Go binary built from a local checkout (`(devel)` version) cannot be reinstalled by module path. It gets a run note naming it instead of a rebuild.
- Outdated npm packages produce a run note and leave the exit status alone.

## Notes
- Runs as the invoking user: rustup toolchains, `GOBIN`, and uv/pipx tools are per-user.
- Never rebuilds a Go binary that is already on the current Go or a newer one.

## Related Documentation
- [Arch Wiki - Rust (rustup)](https://wiki.archlinux.org/title/Rust#Rustup)
- [go install](https://go.dev/ref/mod#go-install)
- [uv tools](https://docs.astral.sh/uv/concepts/tools/)
- [pipx](https://pipx.pypa.io/)
