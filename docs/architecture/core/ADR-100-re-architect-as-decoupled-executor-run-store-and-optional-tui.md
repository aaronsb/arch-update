---
status: Proposed
date: 2026-06-25
deciders:
  - aaronsb
  - claude
related:
  - ADR-001
---

# ADR-100: Re-architect as decoupled executor, run-store, and optional TUI

## Context

Today `arch-update` is a single bash program that *is* the run: `update.sh`
discovers numbered modules, sources them in three phases, and renders educational
output inline as it executes. Execution, presentation, and state are fused into one
synchronous process. That design has served well, but a design exploration surfaced
several limits and one genuinely novel opportunity that the current shape cannot
host cleanly:

- **The UI is welded to execution.** Richer presentation (a live-updating checklist,
  spinners that survive a resize, a browsable history) is not a bash-vs-Rust language
  question — it is a *library* question, and the libraries that clear that bar
  (`ratatui`, `crossterm`, `indicatif`) want to be a front-end, not interleaved with
  `pacman` calls.
- **There is no passive mode.** The tool only knows how to *run*. It cannot sit
  quietly and answer "do I have update pressure?" — the "you have mail" model — because
  it has no place to write a verdict and nothing to read it. The recent 15-month drift
  on the author's own machine (a box that sat un-updated and un-warned) is the concrete
  cost of having no observe-and-notify path.
- **Error surfacing is a vestigial footer.** `90-systemd-status.sh` already reads a
  genuine *empirical harm* signal (`systemctl --failed`, `is-system-running`), but it
  runs only as a post-update status step and is never correlated to anything.

A survey of existing tools (recorded under "Alternatives") found that the
update-notifier problem is already well solved on Arch, while one capability is
**not** solved by anything packaged: joining *observed system harm* (a crash-looping
unit, an error-rate spike) to *an available fix* (a pending update for that unit's
package), and surfacing a single escalating verdict. That correlation — the
"diagnostician" — is the thing worth building, and it does not fit the current
single-process shape.

## Decision

Re-architect `arch-update` into **four decoupled concerns that communicate only
through a structured state/log store**. The store is the source of truth *and* the
IPC; no concern calls another directly.

```
  ┌─ MANIFEST ──────────┐   declarative, human-readable, traversable
  │ steps: id, phase,   │   the contract: what exists, ordering, what's
  │ requires, risk,     │   safe, what needs a human
  │ dry-run-safe        │
  └─────────┬───────────┘
            │ reads
  ┌─────────▼───────────┐
  │ EXECUTOR (headless) │   systemd oneshot + timer. knows nothing about UI.
  │ runs steps, emits   │   modes: execute · observe · notify
  │ structured events   │
  └─────────┬───────────┘
            │ writes JSONL events
  ┌─────────▼───────────┐
  │ RUN STORE / LOG     │  ← SOURCE OF TRUTH and IPC
  │ $XDG_STATE/runs/    │    rotatable, retainable, per-run tree
  └─────────┬───────────┘
            │ follows (live) / browses (history)
  ┌─────────▼───────────┐
  │ TUI (ratatui)       │   a consumer. OPTIONAL. system runs fine headless.
  └─────────────────────┘
```

The load-bearing commitments:

1. **Modules stay external, manifest-indexed scripts.** A human-readable manifest
   (continuation of the already-declarative `MODULE_TYPE` / `MODULE_REQUIRES` /
   `MODULE_DRY_RUN_SAFE` headers in `v0.4.12`) is the index; each step still points at
   an owned script run in a slot the author chose. The frontend is *not* compiled
   against the step set. This is the explicit guard against the topgrade failure mode
   (see Alternatives): the user must never recompile to change or reorder a step.

2. **Compose existing Arch sensors; do not reimplement notifiers.** The tool wraps
   `checkupdates`, `arch-audit`, `informant`, `journalctl`, and `systemctl` as data
   sources. It does **not** rebuild update-checking, the news feed, or a systray
   applet — those exist and are mature. The tool owns the *synthesis*, not the sensors.
   This is the most Arch-philosophy framing available: compose small tools, own the
   opinionated layer.

3. **Three operating modes over one substrate.**
   - *execute* — run the steps (the current behavior, made headless).
   - *observe* — read-only: evaluate update + harm pressure, write a verdict.
   - *notify* — surface the verdict cheaply (MOTD via `/run/motd.d`, desktop toast
     via `notify-send`, prompt segments). Surfaces are dumb readers: a `stat`, never a
     scan.

4. **The diagnostician is the novel kernel.** The observe mode joins empirical harm
   (failed/crash-looping units, journal error rate, OOM/coredumps) to the pending
   update set, so the strongest signal becomes *"unit X is crash-looping and there is
   a pending update for X — this is probably your fix."* No surveyed tool does this.

This ADR decides the **foundational structure and the compose-don't-reimplement
stance only.** It deliberately defers the following to follow-on ADRs in their bands,
so each is decided on its own merits:

- Frontend technology and the event-stream schema → `core` (1xx).
- Step/manifest schema and risk classification → `modules` (2xx).
- Pressure scoring, the harm→fix correlation, and notification/fatigue policy →
  `sensing` (3xx).
- Log substrate (journald vs. `$XDG_STATE` run-store), retention/rotation, and the
  systemd unit topology (system vs. user) → `operations` (4xx).
- The unattended-safety policy (which steps a timer may auto-apply vs. stage-and-notify
  — Arch partial-upgrade and keyring hazards make this non-optional) → `sensing`/`modules`.

Implementation language is expected to be Rust (for the front-end and executor) given
the library argument above, but this ADR does not *bind* the language — it binds the
**decoupling and the contracts**. A bash executor against the same run-store would
satisfy this decision.

## Consequences

### Positive

- Presentation can advance independently of execution; a flashy TUI becomes a
  swappable consumer, not a rewrite of the engine.
- The tool gains passive value: it can warn between runs ("you have updates") and,
  uniquely, diagnose ("…and your crash loop has a fix") without a human invoking it.
- A `Persistent=true` timer makes the maintenance half self-healing after downtime —
  directly addressing the 15-month-drift scenario.
- The author keeps full ownership of the step set and ordering — the property that
  motivated building this instead of adopting topgrade.

### Negative

- Substantially more moving parts than one script: a manifest format, an event
  schema, retention policy, and systemd units to maintain.
- A likely language shift (bash → Rust) raises the contribution and build bar, and is
  a real rewrite cost for a working tool.
- Unattended operation introduces genuine Arch-specific risk (partial upgrades,
  keyring, manual-intervention news) that the safety-policy ADR must contain before
  any auto-apply ships.

### Neutral

- Existing modules become manifest entries plus their scripts; the migration is
  incremental, not a clean-room rewrite.
- The current `90-systemd-status` harm check is the embryo of observe-mode and is
  retained and extended (NRestarts, error-rate, coredumps) rather than discarded.

## Alternatives Considered

- **Adopt topgrade** — reviewed its sources; underwhelming for this purpose. Its
  built-in step catalog and ordering are compiled into the binary; extension is
  disable-plus-bolt-on (`[commands]`/`pre_commands`), with no way to interleave a
  custom step at a chosen position. It would trade "I own everything" for "I accept
  their spine and decorate the edges" — the exact loss of control this project exists
  to avoid.
- **Adopt / defer to `Antiz96/arch-update`** — the mature sibling (also bash, also
  named `arch-update`). It already nails the notifier surface: update checking, Arch
  news, orphans, pacnew/pacsave, a systray applet. We explicitly **reuse its category
  of function by composition** (and may borrow code — hence the GPL-3.0 match in
  ADR-001) rather than re-implement it. But it stops at notification; it has no
  harm→fix diagnostician and no live TUI. It covers the solved half, not the novel one.
- **Full Rust rewrite with compiled-in modules** — rejected: making steps Rust
  functions recreates topgrade's lock-in (recompile to change a step). Avoiding it
  requires a plugin/external-script model, which is just this ADR's decision with extra
  steps.
- **Stay bash, evolve incrementally** — partially adopted as the *migration path*: the
  manifest, observe-mode, and harm signals can each land in the existing bash tool
  before any language shift. Rejected as the *end state* because the live-TUI ceiling
  is real and the decoupling is cleaner to establish deliberately than to retrofit.
- **`gum`-level bash flash** — a cheap near-term win (styled boxes, spinners via
  Charmbracelet `gum`) that requires no architecture change. Noted as a viable interim
  step, not a substitute for the decoupling.
