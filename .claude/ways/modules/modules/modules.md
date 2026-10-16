---
description: the module and step contract and manifest — numbered external scripts declaring MODULE_TYPE, MODULE_REQUIRES, MODULE_DRY_RUN_SAFE; system/user/status phases; honoring DRY_RUN and check_supported gating
vocabulary: module step script manifest MODULE_TYPE MODULE_REQUIRES MODULE_DRY_RUN_SAFE phase system user status check_supported dry-run idempotent risk classification numbered
refire: 0.15
scope: agent
---
# Modules

Modules are numbered external scripts indexed by the manifest. Each declares a header contract.

## Declarative header

| Field | Meaning |
|---|---|
| `MODULE_TYPE` | Which concern / category the module serves |
| `MODULE_REQUIRES` | Tools that must exist for it to run |
| `MODULE_DRY_RUN_SAFE` | Whether it is safe under `$DRY_RUN` |

## Phases (by number)

- **system** `10-49` — privileged, system-wide steps
- **user** `50-89` — per-user steps
- **status** `90-99` — read-only reporting, runs last

## When adding or editing a module

- Follow the declarative-header contract — keep the fields accurate.
- Stay **idempotent**: re-running must be safe and converge, not double-apply.
- Honor `$DRY_RUN` — print intent, change nothing, when set.
- **Degrade gracefully**: if a `MODULE_REQUIRES` tool is absent, skip cleanly via `check_supported()`, never crash the run.
- `check_supported()` is the gate — if it returns false the step does not execute.

Decisions about the **manifest schema** or **risk classification** go in the **modules (2xx)** ADR band.
