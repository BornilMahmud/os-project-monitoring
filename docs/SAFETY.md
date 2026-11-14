# SMD-TUI 2.0 - Strict Read-Only Safety Policy

SMD-TUI 2.0 is designed from the ground up as a **strictly read-only local Linux hardware intelligence and monitoring application**. It adheres to rigorous non-destructive principles to ensure that system stability, user data, and hardware configurations are never modified.

---

## 1. Core Safety Principles

1. **Non-Root Operation**: SMD-TUI runs entirely within normal, unprivileged user space. It never requests, requires, or invokes `sudo` or root privileges.
2. **Read-Only Telemetry**: The application strictly reads system metrics from Linux procfs (`/proc`), sysfs (`/sys`), and read-only standard utilities (`ps`, `df`, `ip`, `uname`).
3. **Zero Hardware Control**: The application never writes to hardware control registers, power governors, thermal trip points, fan curves, or voltage settings.
4. **Zero Process Interference**: The application never sends termination signals (`SIGKILL`, `SIGTERM`), renices processes, or stops system services (`systemctl`).
5. **Sandboxed Application Writes**: File writes are strictly restricted to application-owned user configuration, historical buffers, and user-requested exports within standard XDG directories (`$XDG_CONFIG_HOME`, `$XDG_DATA_HOME`).

---

## 2. Permitted Operations

The following operations are permitted and performed by SMD-TUI:
- Reading `/proc/stat`, `/proc/meminfo`, `/proc/loadavg`, `/proc/cpuinfo`, `/proc/diskstats`, `/proc/net/dev`, `/proc/uptime`.
- Reading `/sys/class/thermal/`, `/sys/class/hwmon/`, `/sys/class/power_supply/`, `/sys/class/net/`.
- Reading `/etc/os-release` for distribution identity.
- Executing read-only user queries: `ps -eo ...` (to display top consuming processes), `df -P -k` (to display disk utilization).
- Calculating mathematical deltas for CPU utilization, RAM usage, disk I/O rates, and network bandwidth.
- Generating live ANSI terminal interfaces, charts, and informational threshold alerts.
- Exporting user-requested text reports and CSV metrics into `$XDG_DATA_HOME/smd-tui/`.

---

## 3. Strictly Prohibited Operations

SMD-TUI 2.0 explicitly prohibits and contains **zero instances** of:
- `sudo`, `su`, or privilege escalation.
- Write redirections (`>`, `>>`) or piped writes (`tee`) to `/proc/` or `/sys/`.
- Destructive process control: `kill`, `pkill`, `killall`, `renice`.
- Destructive disk operations: `mkfs`, `fdisk`, `parted`, `dd`, `mount`, `umount`.
- Service or host modifications: `systemctl stop`, `systemctl disable`, `service stop`.
- System state changes: `reboot`, `shutdown`, `poweroff`, `halt`.
- Modification of network routing, iptables, or firewall rules.
- Writing to system directories (`/etc`, `/usr`, `/bin`, `/var`).

---

## 4. Automated Safety Audit Verification

Compliance with this policy is automatically verified as part of the regression test suite:
- File: [`tests/regression/test_safety_audit.bats`](file:///d:/Programming/Programming/projects/os%20porject/tests/regression/test_safety_audit.bats)
- Audit Checks:
  - Scans all scripts for any occurrence of `sudo`.
  - Scans for any write redirection or pipes targeting `/proc/` or `/sys/`.
  - Scans for any process killing or signaling commands.
  - Scans for destructive system, disk, or shutdown commands.
  - Verifies that directory creation is strictly confined to user XDG and temporary sandbox directories.
