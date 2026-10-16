# Pacman Database Check Module

## Overview
Checks the local pacman database for consistency problems with `pacman -Dk`: missing dependencies, conflicting packages, files owned by more than one package, and database entries missing their description or file list. pacman has no automatic repair for these, so the module reports them and leaves the fix to you.

## Type
System module (00-49 range)

## Dependencies
- pacman

## Operation
1. Runs `pacman -Dk` with `LC_ALL=C`, since pacman translates its message prefix. The check only reads the database, so it runs without sudo and is safe in a dry run.
2. On a clean database, reports it verified.
3. On problems, prints pacman's report and adds a note to the end-of-run summary with the problem count.
4. If pacman exits non-zero without reporting any database problem (no database, unreadable config, a crash), the check could not run, and the module fails.

## Exit status
Problems in the database are a finding about the system, not a failure of this module. They appear in the run summary as a note and do not change the run's exit status. A check that could not run is a failure of this module and fails the run.

## Resolving problems
- **Missing dependency**: install the missing package, or remove the package that needs it.
- **Conflict, or a file owned by two packages**: remove one of the two packages.
- **Missing description or file list**: reinstall that package.
- Re-check with `pacman -Dk`. pacman skips its other checks while entries are missing their files, so fixing those can reveal more problems.

## Related Documentation
- [Arch Wiki - Pacman](https://wiki.archlinux.org/title/Pacman)
- [Pacman Database](https://wiki.archlinux.org/title/Pacman#Package_database)
- [System maintenance - package manager problems](https://wiki.archlinux.org/title/System_maintenance)
