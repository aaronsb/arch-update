---
description: core structure decisions — the decoupled executor, run-store as state-as-IPC, and optional TUI frontend split; modules stay external manifest-indexed scripts; compose existing tools rather than reimplement
vocabulary: architecture core structure executor run-store state IPC TUI frontend manifest decoupled concerns compose refactor module-index design boundary
refire: 0.15
scope: agent
---
# Architecture

The system is four decoupled concerns. Keep them separate.

| Concern | Role |
|---|---|
| **manifest** | Indexes external module scripts; the catalog, not a runner |
| **executor** | Runs steps; owns no UI and no policy beyond ordering |
| **run-store** | Structured record of a run — the single channel of IPC |
| **frontend** | Optional TUI / MOTD; reads the run-store, drives nothing else directly |

## When touching core structure

- Respect the four-way split. A concern **communicates only through the run-store** — never by calling another concern directly. State-as-IPC is the contract; honor it.
- The frontend is optional and replaceable. Nothing core may assume a TUI exists.
- **Compose existing tools** (pacman, paccache, systemd, checkupdates) rather than reimplementing their behavior.
- Modules stay **external scripts** discovered via the manifest — not inlined into the executor.

File an ADR in the **core (1xx)** band for any structural decision (reference ADR-100). If a change blurs the boundary between two concerns, that is the signal an ADR is owed before you write the code.
