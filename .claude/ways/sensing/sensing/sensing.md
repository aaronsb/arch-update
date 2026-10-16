---
description: update-pressure and system-harm evaluation, the diagnostician correlating observed harm to an available fix, and notification surfaces like MOTD and toast
vocabulary: sensing update pressure harm evaluation diagnostician verdict notification MOTD toast staleness snark hysteresis security login prompt background precomputed surface
refire: 0.15
scope: agent
---
# Sensing

Sensing measures **update pressure** and **system harm**, and surfaces it to the user.

## Cheap readers, expensive thinkers

- Notification surfaces (MOTD, toast) are **dumb readers** of a precomputed verdict — a `stat` of a result file, **never a scan**.
- The expensive evaluation runs in the **background**, never at login or prompt time. The login path must stay instant.

## The diagnostician

Correlate **observed harm** to an **available fix** — don't just report that something is wrong, point at the step that addresses it.

## Voice and restraint

- **Snark scales with staleness** — gentle when fresh, sharper the longer updates are ignored.
- The **security / harm voice stays serious** and must **not cry wolf**. Use **hysteresis**: a threshold to raise an alarm that is higher than the one to clear it, so transient blips don't toggle warnings.

Decisions go in the **sensing (3xx)** ADR band.
