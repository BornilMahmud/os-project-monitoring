# SMD-TUI 2.0
## Linux Hardware Intelligence & Interactive Terminal Monitor

[![Bash](https://img.shields.io/badge/language-Bash%205.x-blue.svg)](https://www.gnu.org/software/bash/)
[![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20WSL2-green.svg)](https://kernel.org)
[![License](https://img.shields.io/badge/license-GPL--3.0-orange.svg)](LICENSE)
[![Safety](https://img.shields.io/badge/safety-Strictly%20Read--Only-brightgreen.svg)](docs/SAFETY.md)
[![Tests](https://img.shields.io/badge/tests-54%20passed-success.svg)](tests/)

**SMD-TUI 2.0** is a lightweight, modular, interactive Linux hardware monitoring application written entirely in Bash 5.x. It delivers real-time system intelligence, live trend charts (similar to Windows Task Manager and htop), informational threshold alerts, and instant reporting without requiring root privileges or heavy external dependencies.

---

## Key Features

- **Live Continuous Monitoring**: Real-time terminal updating with live multi-line CPU and Memory trend charts.
- **10 Dedicated Views**:
  1. System Overview
  2. CPU Monitoring & Per-Core Utilization
  3. Memory & Swap Intelligence
  4. Top Consuming Processes (Scrollable)
  5. Thermal Sensors & Cooling Fans
  6. Storage Filesystems & Disk I/O Rates
  7. Network Interfaces & Bandwidth Speeds
  8. Battery State & Power Telemetry
  9. Informational Alerts Log
  10. Configuration & Diagnostics
- **Environment & Hardware Intelligence**:
  - Automatically identifies physical cores vs. logical threads.
  - Automatically detects Bare Metal, WSL2, Docker, or Virtual Machines.
  - When running inside WSL2, clearly shows both Linux VM allocated resources and Windows Host physical hardware (Total Host RAM, Host Uptime, Host C: and D: drives).
  - Gracefully handles missing thermal or battery sensors without erroring.
- **Strict Read-Only Safety**:
  - Never requires or uses `sudo`.
  - Never writes to `/sys` or `/proc`.
  - Never terminates user processes or modifies system settings.
  - Allowed file writes are strictly confined to user configuration and exports under standard XDG paths (`~/.config/smd-tui/`, `~/.local/share/smd-tui/`).
- **Data Exporting**: Instant full-system text reports and time-series CSV metrics export at the press of a key (`E`) or via command-line flags.

---

## Quickstart

### Launch Directly
```bash
./app.sh
```

### Install in User Space (~/.local/bin)
```bash
bash scripts/install.sh
```
Then launch from anywhere:
```bash
smd-tui
```

### Run Live Preview
```bash
bash scripts/demo_collectors.sh
```

---

## Keyboard Navigation

| Key | Function |
| :--- | :--- |
| **`1` – `9`, `0`** | Direct Tab Selection (1:Overview, 2:CPU, 3:RAM ... 0:Settings) |
| **`Tab`** | Cycle to next tab |
| **`Left` / `Right`** | Previous / Next tab |
| **`Up` / `Down`, `j` / `k`** | Scroll process tables and alert logs |
| **`P`** | Pause / Resume live data refreshing |
| **`R`** | Force immediate hardware metric refresh |
| **`E`** | Export live HTML system report, text report, and CSV telemetry |
| **`H` or `?`** | Toggle interactive keyboard help overlay |
| **`Q` or `Esc`** | Cleanly quit SMD-TUI and restore terminal state |

---

## Testing & Quality Assurance

SMD-TUI 2.0 includes a comprehensive automated test suite of **56 tests** across unit, integration, and regression tiers:

```bash
bash tests/run_tests.sh
```

- **Unit Tests**: Mathematical deltas, byte scalers, config validation, CPU/RAM collectors, storage I/O, network bandwidth, thermals, battery, processes, history ring buffers, graphs, and UI components.
- **Integration Tests**: CLI arguments, version, dependency validation, headless text/HTML report generation, and CSV output.
- **Regression & Safety Audit**: Static code analysis guaranteeing zero usage of `sudo`, zero writes to `/proc` or `/sys`, zero process kills, and zero destructive disk operations.

---

## Architecture

```
SMD-TUI-2.0/
├── app.sh                  # Main application orchestrator & live event loop
├── collectors/             # Strictly read-only hardware telemetry collectors
│   ├── cpu.sh              # CPU utilization, cores, frequency, load averages
│   ├── memory.sh           # RAM & Swap capacity, MemAvailable, buffers/cache
│   ├── storage.sh          # Filesystems, mountpoints, disk I/O rates
│   ├── network.sh          # Interfaces, operstate, RX/TX bandwidth speeds
│   ├── system.sh           # Distribution, kernel, uptime, virtualization
│   ├── thermals.sh         # Thermal zones, package temps, cooling fans
│   ├── battery.sh          # Power supply, capacity %, health, technology
│   └── processes.sh        # Read-only top CPU and memory process scanner
├── core/                   # Mathematical calculations, history, alerts, export
│   ├── calculations.sh     # Pure Bash integer & fixed-point math, unit scalers
│   ├── history.sh          # Circular ring buffers for live trend charts
│   ├── alerts.sh           # Real-time informational threshold evaluation
│   └── export.sh           # Formatted text report & CSV metrics exporter
├── ui/                     # Interactive ANSI terminal interface
│   ├── components.sh       # Color themes, boxes, terminal setup/restore
│   ├── graphs.sh           # ASCII, Unicode block & Braille trend charts
│   ├── navigation.sh       # 10 views routing, tab management, scrolling
│   ├── input.sh            # Non-blocking keyboard & escape sequence listener
│   └── dashboard.sh        # Layout renderer, headers, tabs, status bar
├── config/                 # Safe configuration
│   ├── defaults.conf       # Standard default intervals, thresholds, theme
│   └── loader.sh           # Safe parser & validator avoiding eval/source
├── scripts/                # Utility scripts
│   ├── demo_collectors.sh  # Live hardware telemetry preview script
│   └── install.sh          # Non-root installer (~/.local/bin)
├── docs/                   # Complete documentation
│   ├── MANUAL.md           # Detailed user manual & architecture guide
│   ├── SAFETY.md           # Strict read-only safety specification
│   └── CHANGELOG.md        # Release changelog & version history
└── tests/                  # Automated test harness & 16 test suites
```

---

## License

GPL-3.0 License. Designed for Linux systems and unprivileged user operation.
