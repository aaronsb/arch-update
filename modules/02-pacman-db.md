# Pacman Database Check Module

## Overview
Checks the local pacman database for consistency problems with `pacman -Dk`: missing dependencies and files owned by more than one package. pacman has no automatic repair for these, so the module reports them and leaves the fix to you.

## Type
System module (00-49 range)

## Dependencies
- pacman

## Operation
1. Runs `pacman -Dk`. The check only reads the database, so it runs without sudo and is safe in a dry run.
2. On a clean database, reports it verified.
3. On problems, prints pacman's report and adds a note to the end-of-run summary with the problem count.

## Exit status
Problems in the database are a finding about the system, not a failure of this module. They appear in the run summary as a note and do not change the run's exit status. If the database is broken badly enough to stop an upgrade, `10-pacman-update` fails with pacman's own error.

## Resolving problems
- **Missing dependency**: install the missing package, or remove the package that needs it.
- **File owned by two packages**: remove one of the conflicting packages.
- Re-check with `pacman -Dk`.

## Related Documentation
- [Arch Wiki - Pacman](https://wiki.archlinux.org/title/Pacman)
- [Pacman Database](https://wiki.archlinux.org/title/Pacman#Package_database)
- [System maintenance - package manager problems](https://wiki.archlinux.org/title/System_maintenance)
