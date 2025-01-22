# Example Update Module

This is a template module demonstrating the module system structure and conventions.

## Priority System (like udev rules)

Modules are executed in order based on their numeric prefix:
- 10-29: System level updates (e.g., system checks, core services)
- 30-49: Package management (e.g., pacman, AUR helpers)
- 50-79: Application updates (e.g., oh-my-posh, flatpak)
- 80-99: Optional/user tools (e.g., custom scripts, user preferences)

## Module Status

Modules use file extensions to indicate status:
- `.sh`: Module is enabled and executable
- Anything else (typically `.disabled`): Module is disabled

## Creating New Modules

1. Copy this example:
```bash
cp 50-example.disabled XX-yourmodule.sh
```
where XX is the appropriate priority number

2. Implement required functions:
- `check_supported()`: Return 0 if module can run
- `run_update()`: Perform the actual update

3. Make it executable:
```bash
chmod +x XX-yourmodule.sh
```

## Enable/Disable

To enable this example:
```bash
mv 50-example.disabled 50-example.sh && chmod +x 50-example.sh
```

To disable any module:
```bash
mv XX-modulename.sh XX-modulename.disabled
