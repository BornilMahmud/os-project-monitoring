# Changelog - SMD-TUI 2.0

## [2.0.0] - 2026-11-14

### Added
- **Modular 3-Tier Bash Architecture**: Separated hardware collectors (`collectors/`), mathematical calculations and history buffers (`core/`), ANSI rendering and input handling (`ui/`), and safe configuration (`config/`).
- **10 Interactive Monitoring Views**:
  1. System Overview Dashboard
  2. CPU Telemetry & Multi-line Utilization Trend Chart
  3. Memory Telemetry & Utilization Trend Chart
  4. Scrollable Top Consuming Processes Table
  5. Thermal Sensors, Package Temps & Fan Speed RPM
  6. Storage Filesystems & Live Disk I/O Rates
  7. Network Interfaces, Operstate & Bandwidth Speeds
  8. Battery State, Health, Capacity & Power Draw
  9. Informational Real-Time Threshold Alerts
  10. Settings, Theme Diagnostics & XDG Paths
- **Live Task-Manager-Style Continuous Refresh**: Real-time continuous updating loop with pause/resume support (`P`), immediate refresh (`R`), and terminal resizing (`SIGWINCH`).
- **Virtualization & Environment Intelligence**:
  - Automatic detection of WSL2, Docker containers, and virtual machines.
  - Distinguishes between physical cores and logical processors (threads).
  - Reports both virtual machine allocated RAM and host physical PC memory when running in WSL2.
  - Prioritizes host drives (e.g. `C:` and `D:` drives under `/mnt/c` and `/mnt/d`) over internal virtual mounts.
- **Reporting & Data Export**:
  - Instant text report generation (`E` or `--export-report`).
  - Time-series CSV metric logging (`E` or `--export-csv`).
  - Strict containment within XDG standard user directories (`$XDG_DATA_HOME/smd-tui`).
- **Strict Read-Only Safety Protocol**:
  - Zero sudo requirement.
  - Zero sysfs/procfs writes.
  - Zero process signals or termination commands.
  - Zero hardware or service modifications.
- **Automated Test Suite**:
  - 16 test suites with 54 automated unit, integration, and regression tests.
  - Automated safety audit test suite (`test_safety_audit.bats`).
- **User Space Non-Root Installer**:
  - `scripts/install.sh` for unprivileged setup in `~/.local/bin` with `--uninstall` support.
