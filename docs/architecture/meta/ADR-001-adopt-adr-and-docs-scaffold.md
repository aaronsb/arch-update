---
status: Accepted
date: 2026-06-25
deciders:
  - aaronsb
  - claude
related:
  - ADR-100
---

# ADR-001: Adopt ADR and docs scaffold

## Context

`arch-update` began as a personal, modular Arch Linux maintenance script and grew
organically: numbered shell modules, a deploy/self-update flow, and educational
terminal output. Until now it carried **no recorded design rationale** — decisions
lived only in commit messages and the author's memory. Two pressures made that gap
concrete:

1. A real divergence opened up. The author's working machine sat at `v0.2.0` while
   `origin/main` had moved 25 commits ahead to `v0.4.12` (declarative module
   metadata, a manifest/hash-based self-updater, XDG layout). The *why* behind that
   evolution was nowhere written down — it had to be reverse-engineered from diffs.
2. A substantial re-architecture is now under consideration (see ADR-100). A change
   of that size should not be undertaken — or rejected — without a durable record of
   the decision and the alternatives weighed.

The repository was greenfield with respect to engineering practice: no `docs/`, no
ADRs, no `LICENSE`, no `.github/`, a single contributor (`aaronsb`). The author
already runs an ADR-driven workflow in other projects and wanted this repo brought
up to that standard.

## Decision

Adopt a documentation-and-decision scaffold, sized for a single-maintainer CLI tool:

- **ADR tooling** — vendor `docs/scripts/adr` (copy, not symlink) with a
  full-banded domain scheme in `docs/architecture/adr.yaml`:

  | Band | Domain | Range | Scope |
  |------|--------|-------|-------|
  | 0xx | `meta` | 1–99 | ADR/docs practice, workflow, project-management |
  | 1xx | `core` | 100–199 | Core architecture: executor/frontend/run-store, module system, IPC |
  | 2xx | `modules` | 200–299 | Step contract, manifest schema, discovery, risk classification |
  | 3xx | `sensing` | 300–399 | Update/harm pressure evaluation, diagnostician correlation, MOTD/toast |
  | 4xx | `operations` | 400–499 | systemd, self-update, deploy/install, log retention & rotation |

  The bands were chosen to mirror the tool's natural seams rather than generic
  software layers — "Sensing & Notification" and "Modules & Manifest" exist because
  they are where this tool's hard decisions cluster.

- **Docs catalog** — vendor `docs/scripts/doc` + `doclint.py`, sharing the same
  domain bands, so future prose docs (tutorials, how-tos, reference) are typed and
  linted alongside ADRs. Adoption is gradual; untagged prose is not flagged.

- **License** — `GPL-3.0`, matching the sibling project
  [`Antiz96/arch-update`](https://github.com/Antiz96/arch-update) and the broader
  Arch/Linux tooling tradition. Copyleft also fits the tool's stated ethos (user
  empowerment, "stays free"), and keeps the door open to borrowing from the GPL
  sibling — a one-way door that a permissive license would have closed.

- **Project-local ways** — starter ways under `.claude/ways/` aligned to the ADR
  bands, so future work in each area is steered in-repo.

- **Contributor guide** — a `CONTRIBUTING.md` documenting the module/create-module,
  deploy, and ADR workflow.

- **No CODEOWNERS** — single maintainer; a CODEOWNERS file would be ceremony with
  no reviewer to route to. Revisit if the project gains contributors.

## Consequences

### Positive

- Design decisions become discoverable and durable — the `v0.2.0 → v0.4.12`
  reverse-engineering exercise should not need to happen again.
- The re-architecture (ADR-100) lands with its rationale and rejected alternatives
  on record, not as an unexplained rewrite.
- A `LICENSE` makes the public repo legally reusable (previously "all rights
  reserved" by default — at odds with the tool's spirit).

### Negative

- Ongoing overhead: decisions of consequence now warrant an ADR, and docs carry
  catalog frontmatter to be linted.
- Risk of over-structuring a hobby tool. Mitigated by sizing down (no CODEOWNERS,
  gradual docs adoption) and by treating bands as filing aids, not gates.

### Neutral

- The `meta` domain deliberately occupies the legacy 1–99 range; there are no
  pre-existing ADRs to preserve, so `ADR-001` is the scaffold decision itself.
- Establishes the convention that external references (specs, sibling projects,
  upstream tools) are cited via `related:` and inline links.

## Alternatives Considered

- **Stay undocumented (status quo)** — rejected: the divergence incident and the
  pending re-architecture are exactly the situations a decision record exists to
  serve.
- **Lean 3-domain scheme** — rejected in favor of the full 5-band scheme: the
  author runs an ADR-disciplined practice and the tool's roadmap (sensing,
  notification, manifest) genuinely spans those seams.
- **Permissive license (MIT)** — initially chosen, then reversed to GPL-3.0 to match
  the GPL sibling and preserve copyleft/code-borrowing compatibility.
