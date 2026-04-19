# update-arch

A modular Arch Linux update script. User-scope, XDG-compliant, with a simple
module contract so adding your own maintenance tasks is a few lines of bash.

## Design

- **User scope.** The tool lives under your `$HOME` per the XDG Base Directory
  spec. Nothing is installed into `/usr` or `/etc`. System-level operations
  inside modules use `sudo` only where needed.
- **Modular.** Each maintenance task is its own file in `modules/`, prefixed
  with a two-digit number that sets its phase and ordering (like udev or
  System V init).
- **Declarative modules.** A module is a short bash file that declares a few
  `MODULE_*` variables and defines `run_update`. The runtime handles
  discovery, phase validation, dry-run, and isolation.

## Installation

One-liner, no git needed on the target:

```bash
curl -fsSL https://raw.githubusercontent.com/aaronsb/arch-update/main/install.sh | bash
```

This fetches the latest release tag as a tarball, extracts to a temp
directory, and runs `deploy.sh --install`. Only `curl` and `tar` are
required at install time.

Prefer to read the script before piping to shell:

```bash
curl -fsSLO https://raw.githubusercontent.com/aaronsb/arch-update/main/install.sh
less install.sh
bash install.sh
```

### From a local clone (for development)

```bash
git clone https://github.com/aaronsb/arch-update.git
cd arch-update
./deploy.sh --install   # or: make install
```

Either path copies the tracked files (minus anything in `.deployignore`)
into `$XDG_DATA_HOME/update-arch`, creates a symlink at
`~/.local/bin/update-arch`, and writes an `INSTALL_MANIFEST` recording the
version, commit, and source (`git` or `tarball`) for `--update` to reason
about later.

### Forking

Upstream repo coordinates live in `update-arch.conf` (ships with the code,
deployed to `$XDG_DATA_HOME/update-arch/`). A fork just edits that file.
Users can also override by creating
`$XDG_CONFIG_HOME/update-arch/update-arch.conf`.

## Usage

```bash
update-arch                     # show help
update-arch --run               # perform updates
update-arch --dry-run           # show what would happen
update-arch --list              # list installed modules with metadata
update-arch --only pacman       # run one module (substring match)
update-arch --create-module -t system
update-arch --configure-terminal
```

## Module phases

Phases run in order. A module's numeric prefix determines its phase.

| Range | Phase  | Scope              | sudo?          |
| ----- | ------ | ------------------ | -------------- |
| 10-49 | system | System maintenance | yes (as needed) |
| 50-89 | user   | User customization | no             |
| 90-99 | status | Post-update status | no             |

## Writing a module

Create a file `modules/NN-my-module.sh` (pick a free number in the right
range) and give it this shape:

```bash
#!/bin/bash
# What this module does.

MODULE_TYPE="system"                      # system | user | status
MODULE_NAME="my-module"
MODULE_DESCRIPTION="One-line summary"
MODULE_REQUIRES="some-cli another-cli"    # commands that must exist
MODULE_DRY_RUN_SAFE="true"                # default true

run_update() {
    print_header "${ICONS[package]} DOING THE THING"

    if [[ -n "$DRY_RUN" ]]; then
        print_status "${ICONS[info]}" "Would do X"
        return 0
    fi

    # real work here
    print_success "Done"
}
```

That's it. No boilerplate, no source guards, no direct-invocation footer.

- `check_supported` is **optional**. By default the runtime derives it from
  `MODULE_REQUIRES` — every command listed must exist on `PATH`. Define your
  own `check_supported` if the check is more involved (e.g., a specific file
  must exist).
- Each module runs in a subshell, so state (variables, functions, traps)
  never leaks into the next module.

Or use the scaffold:

```bash
update-arch --create-module -t system
```

## Paths (XDG)

All paths honor XDG Base Directory environment variables with the standard
fallbacks.

| What                  | Env override       | Default                             |
| --------------------- | ------------------ | ----------------------------------- |
| Code and modules      | `$XDG_DATA_HOME`   | `~/.local/share/update-arch`        |
| Terminal config       | `$XDG_CONFIG_HOME` | `~/.config/update-arch`             |
| Run logs              | `$XDG_STATE_HOME`  | `~/.local/state/update-arch/logs`   |
| Cache / backups       | `$XDG_CACHE_HOME`  | `~/.cache/update-arch`              |
| Lock file             | `$XDG_RUNTIME_DIR` | `/tmp`                              |
| Executable            | —                  | `~/.local/bin/update-arch`          |

Only the last `UPDATE_ARCH_MAX_LOGS` (5) run logs are kept.

## Disabling modules

Rename a module to `.sh.disabled` to skip it:

```bash
mv 20-flatpak-update.sh 20-flatpak-update.sh.disabled
```

## Dependencies

Required: `bash`, `sudo`, `pacman`, `systemctl`, `flock`.

Optional (enables the matching module): `reflector`, `paccache`, `yay` or
`paru`, `flatpak`, `oh-my-posh`, `fastfetch`, `checkupdates`.

Optional (improves output): `glow` renders release notes as formatted
markdown when `--check-update` / `--update` finds a new version. Falls
back to plain indented text if none of `glow` / `mdcat` / `bat` are on
PATH. Only applied when stdout is an interactive terminal — tee'd logs
stay plain.

## Locking and concurrency

`update-arch --run` takes an `flock` on `$XDG_RUNTIME_DIR/update-arch.lock` at
start. A second concurrent invocation exits immediately. `--only <name>` uses
the same lock so a standalone module can't race with a full run.

## Uninstall

```bash
~/.local/share/update-arch/deploy.sh --uninstall
```

Prompts for confirmation; pass `--yes` to skip the prompt. Run logs
(`$XDG_STATE_HOME/update-arch`) and cached backups
(`$XDG_CACHE_HOME/update-arch`) are preserved — remove them manually if you
don't want them kept.

## Version

Current version: 0.3.0. Semantic versioning.

## License

MIT.
