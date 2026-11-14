# SMD-TUI 2.0 User Manual & Architecture Guide

## 1. Overview

**SMD-TUI 2.0** is an interactive, lightweight, modular terminal hardware monitor and system intelligence tool written in pure Bash 5.x. It delivers real-time continuous hardware monitoring, live trend charts, informational threshold alerts, and instant export capabilities across standard Linux distributions, bare metal systems, and virtualized environments (including WSL2, Docker, and Cloud VMs).

---

## 2. Interactive Navigation & Keyboard Shortcuts

| Key | Action | Description |
| :--- | :--- | :--- |
| **`1` – `9`, `0`** | Direct Tab Selection | Instantly switch between views (1:Overview, 2:CPU, 3:RAM ... 0:Settings). |
| **`Tab`** | Next Tab | Cycles forward through tabs in order. |
| **`Left` / `Right`** | Previous / Next Tab | Navigates to the adjacent tab. |
| **`Up` / `Down`** | Scroll Table | Scrolls through top process tables or alert logs. |
| **`j` / `k`** | Vim-style Scroll | Alternative scroll navigation (`j` down, `k` up). |
| **`P`** | Pause / Resume | Freezes live data updates (indicator shows `[PAUSED]`). |
| **`R`** | Force Refresh | Immediately updates all hardware metrics without waiting for the timer. |
| **`E`** | Export Report | Generates a complete text report and appends to CSV log under XDG data. |
| **`H` or `?`** | Help Screen | Toggles the keyboard shortcut reference modal overlay. |
| **`Q` or `Esc`** | Clean Exit | Restores screen buffer, cursor, and terminal state cleanly. |

---

## 3. The 10 Monitoring Views

### View 1: System Overview
High-level dashboard providing an instant summary of CPU usage, Memory consumption, Disk read/write rates, Network throughput, CPU Package temperature, Power state, and any active threshold alerts.

### View 2: CPU Monitoring
Detailed CPU hardware telemetry:
- Processor model name, physical core count, and logical processor (thread) count.
- Base clock frequency (MHz) and load averages (1m, 5m, 15m).
- Task states (runnable vs total procs).
- **Task-Manager-style live multi-line CPU utilization history chart**.
- Per-core utilization gauge bars for all individual cores.

### View 3: Memory Monitoring
Comprehensive RAM and Swap intelligence:
- Total RAM, Used RAM, Available RAM (Linux 3.14+ `MemAvailable` standard), Free RAM, Buffers, and Cache.
- Swap capacity and active swap usage.
- **Live multi-line memory consumption trend chart**.
- Clear distinction between VM allocated RAM and physical host RAM in virtualized/WSL2 environments.

### View 4: Top Processes
Live process inspection sorted by resource consumption:
- Displays PID, User, %CPU, %MEM, and Command.
- Scrollable with arrow keys or `j`/`k`.
- Strictly read-only; never interacts with or signals user processes.

### View 5: Thermal Sensors & Fans
Discovers hardware thermal zones across `/sys/class/thermal` and `/sys/class/hwmon`:
- Identifies CPU package and core temperatures.
- Discovers cooling fans and displays live RPM.
- Explains when thermal sensors are unavailable due to virtualized Hyper-V or container environments.

### View 6: Storage & Disk I/O
Storage telemetry:
- Live disk I/O throughput (Read B/s and Write B/s) derived from `/proc/diskstats`.
- Mounted filesystems table displaying Device, Total Capacity, Used Space, and Usage Percentage Bar.
- Automatically filters out internal virtual mounts and highlights root and host drives.

### View 7: Network Telemetry
Bandwidth and interface monitoring:
- Live total download and upload speeds (B/s, KB/s, MB/s).
- Per-interface breakdown showing interface name, operstate (`UP`, `DOWN`), current Rx/Tx speeds, and cumulative bytes transferred.

### View 8: Battery & Power Supply
Power telemetry:
- Battery presence, state (`Charging`, `Discharging`, `Full`), capacity percentage, health status, and battery technology.
- Accurately identifies desktop systems operating on AC mains power.

### View 9: Informational Alerts
Threshold monitoring:
- Automatically tracks CPU (>85%), RAM (>90%), Temperature (>80°C), and Storage (>90%).
- Displays timestamped alert logs with severity levels (`WARNING`, `CRITICAL`).
- Purely informational; never modifies system configuration.

### View 10: Settings & Diagnostics
Configuration inspection:
- Displays active refresh interval, theme, graph style, retention depth, and threshold limits.
- Shows standard XDG directory paths used for configuration, reports, and CSV exports.

---

## 4. Configuration

User configuration resides in `$XDG_CONFIG_HOME/smd-tui/config.conf` (defaults to `~/.config/smd-tui/config.conf`).

```ini
# Refresh interval in seconds (minimum: 1, default: 2)
REFRESH_INTERVAL=2

# Theme: default, cyan, green, amber, monochrome
THEME=default

# Alert thresholds
CPU_ALERT_THRESHOLD=85
MEM_ALERT_THRESHOLD=90
TEMP_ALERT_THRESHOLD=80
DISK_ALERT_THRESHOLD=90

# History buffer size (number of data points)
HISTORY_RETENTION=60

# Graph rendering style: braille, blocks, ascii
GRAPH_STYLE=braille

# Enable informational threshold alerts (true / false)
ENABLE_ALERTS=true
```

---

## 5. Command Line Interface

```bash
# Start interactive monitor
./app.sh

# Start with custom theme and 1-second refresh
./app.sh -t cyan -i 1

# Generate a system report non-interactively
./app.sh --export-report report.txt

# Append live metrics to CSV non-interactively
./app.sh --export-csv metrics.csv

# Verify required and recommended dependencies
./app.sh --check-deps
```
