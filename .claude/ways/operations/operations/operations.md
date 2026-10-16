---
description: systemd integration with oneshot units and timers (system vs user), self-update, deploy and install along XDG paths, and log retention and rotation
vocabulary: operations systemd oneshot timer unit system user self-update deploy install XDG paths log retention rotation unattended partial upgrade keyring news stage notify
refire: 0.15
scope: agent
---
# Operations

Systemd integration, self-update, install/deploy, and log lifecycle.

## Unattended Arch updates are hazardous

Arch can break under blind automation:

- **Partial upgrades** when only some packages move
- **Keyring** updates needed before package signatures verify
- **Manual-intervention news** that must be read before upgrading

So: **auto-apply only boring, safe steps**. For anything risky, **stage and notify** — prepare the work, surface it, let the human decide. Never silently apply a step that could need intervention.

## Conventions

- **systemd**: oneshot unit + timer; choose **system vs user** units by whether the step needs privilege or runs per-user.
- **Self-update** the tool deliberately, not as a side effect of a package run.
- Prefer **XDG paths** for deploy/install (config, data, state, cache dirs).
- **Logs**: retain and rotate — bounded history, not unbounded growth.

Decisions go in the **operations (4xx)** ADR band.
