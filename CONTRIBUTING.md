# Contributing to arch-update

Thanks for your interest. This is a modular Arch Linux maintenance tool that
follows the Unix philosophy: small, focused steps that compose. The notes below
cover how the pieces fit and the conventions to follow.

## Project layout

| Path | Purpose |
|------|---------|
| `update.sh` | Orchestrator — discovers and runs modules in phases |
| `update-self.sh` | Self-update engine (`--check-update` / `--update`) |
| `modules/` | Numbered, drop-in step modules |
| `utils.sh` | Shared output helpers, icons, validation |
| `deploy.sh` | Installer (XDG paths, copies tracked files) |
| `docs/architecture/` | Architecture Decision Records (ADRs) |
| `docs/scripts/` | Vendored `adr` / `doc` tooling |

## Modules

Modules are independent scripts discovered by number range and run in three phases:

| Range | Phase | Privilege |
|-------|-------|-----------|
| `10-49` | system | sudo |
| `50-89` | user | none |
| `90-99` | status | none (read-only) |

Each module declares its contract in header variables and implements two functions:

```bash
MODULE_TYPE="system"          # must match its number range
MODULE_REQUIRES="pacman"      # space-separated commands that must exist
MODULE_DRY_RUN_SAFE="true"    # set false if run_update can't be dry-run

check_supported() { ... }     # return 0 if the module can run here
run_update()      { ... }     # the work; must honor $DRY_RUN; return 0/1
```

Conventions:

- **Honor `$DRY_RUN`** — show what *would* happen, change nothing.
- **Degrade gracefully** — if a required tool is absent, `check_supported` returns
  non-zero and the module is skipped, not failed.
- **Be idempotent** — running twice should be safe.
- **Disable** a module by renaming it `*.sh.disabled`.

Scaffold a new module from a template:

```bash
update-arch --create-module -t [system|user|status]
```

## Install / deploy

The tool installs to XDG paths under `~/.local`:

```bash
./deploy.sh --install      # or: make install
```

Once installed, it self-updates:

```bash
update-arch --check-update   # report whether upstream is newer
update-arch --update         # apply (interactive conflict resolution)
```

## Architecture Decision Records

Decisions of consequence are recorded as ADRs. Use the vendored CLI — never create
`ADR-*.md` files by hand:

```bash
docs/scripts/adr domains              # show the domain bands
docs/scripts/adr new <domain> "Title" # create from template
docs/scripts/adr lint                 # validate before committing
docs/scripts/adr index -y             # regenerate the index
```

Domain bands: `meta` (0xx), `core` (1xx), `modules` (2xx), `sensing` (3xx),
`operations` (4xx). See `docs/architecture/INDEX.md`.

## Commits & PRs

- Use [Conventional Commits](https://www.conventionalcommits.org/): `feat:`, `fix:`,
  `docs:`, `refactor:`, `chore:`, etc.
- Branch off `main`; open a PR rather than pushing to `main` directly.
- For changes with design impact, link or include the relevant ADR.

## License

By contributing you agree your contributions are licensed under the project's
[GPL-3.0](LICENSE) license.
