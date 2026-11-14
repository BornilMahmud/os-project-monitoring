#!/usr/bin/env bash
# app.sh - SMD-TUI 2.0 Main Application Controller & Interactive Terminal Monitor
# Strictly read-only local hardware monitoring application.

set -euo pipefail

# Check Bash version requirement (Bash 5.0+)
if [[ "${BASH_VERSINFO[0]:-0}" -lt 5 ]]; then
    echo "Error: SMD-TUI 2.0 requires GNU Bash 5.0 or newer (detected version: ${BASH_VERSION:-unknown})." >&2
    exit 1
fi

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_VERSION="2.0.0"

# Source modules
source "$APP_DIR/core/calculations.sh"
source "$APP_DIR/config/loader.sh"
source "$APP_DIR/core/history.sh"
source "$APP_DIR/core/alerts.sh"
source "$APP_DIR/core/export.sh"

source "$APP_DIR/collectors/cpu.sh"
source "$APP_DIR/collectors/memory.sh"
source "$APP_DIR/collectors/storage.sh"
source "$APP_DIR/collectors/network.sh"
source "$APP_DIR/collectors/system.sh"
source "$APP_DIR/collectors/thermals.sh"
source "$APP_DIR/collectors/battery.sh"
source "$APP_DIR/collectors/processes.sh"

source "$APP_DIR/ui/components.sh"
source "$APP_DIR/ui/graphs.sh"
source "$APP_DIR/ui/navigation.sh"
source "$APP_DIR/ui/input.sh"
source "$APP_DIR/ui/dashboard.sh"

# Signal cleanup handler
cleanup_and_exit() {
    trap - EXIT INT TERM HUP
    ui_restore_term
    exit 0
}

# Window resize handler
handle_resize() {
    ui_get_term_size
    tput clear 2>/dev/null || printf "\033[2J"
    dashboard_draw
}

# Display usage guide
show_help() {
    cat << EOF
SMD-TUI 2.0 - Linux Hardware Intelligence & Interactive Terminal Monitor

Usage:
  ./app.sh [OPTIONS]

Options:
  -h, --help               Display this help and usage guide
  -v, --version            Display version information
  -c, --config <file>      Path to custom configuration file
  -i, --interval <sec>     Refresh interval in seconds (default: 2)
  -t, --theme <name>       Color theme (default, cyan, green, amber, monochrome)
  --check-deps             Check for recommended system utilities
  --export-report [file]   Generate a system report and exit (headless mode)
  --export-csv [file]      Generate/append live metrics to CSV and exit

Interactive Shortcuts:
  1 - 9, 0                 Directly switch monitoring tabs
  Tab                      Cycle to the next tab
  Left / Right             Previous / Next tab
  Up / Down, j / k         Scroll process tables and alert logs
  P                        Pause / Resume live continuous data refreshing
  R                        Force immediate hardware metric refresh
  E                        Export system report and CSV metrics log
  H or ?                   Toggle interactive keyboard help overlay
  Q or Esc                 Cleanly quit SMD-TUI and restore terminal

Strict Read-Only Policy:
  SMD-TUI 2.0 never controls hardware, terminates processes, or writes
  to system files. All monitoring operations operate with non-root privileges.
EOF
}

# Check recommended system utilities
check_dependencies() {
    echo "=================================================="
    echo "SMD-TUI 2.0 Dependency Check"
    echo "=================================================="

    local required=("bash" "tput" "date" "ps" "df" "uname")
    local recommended=("ip" "free" "lscpu" "sensors")

    echo "Required core utilities:"
    for cmd in "${required[@]}"; do
        if command -v "$cmd" >/dev/null 2>&1; then
            echo -e "  ✓ $cmd : Found ($(command -v "$cmd"))"
        else
            echo -e "  ✗ $cmd : MISSING (Required for basic operation)"
        fi
    done

    echo ""
    echo "Recommended / optional utilities:"
    for cmd in "${recommended[@]}"; do
        if command -v "$cmd" >/dev/null 2>&1; then
            echo -e "  ✓ $cmd : Found ($(command -v "$cmd"))"
        else
            echo -e "  - $cmd : Not installed (Graceful /proc & /sys fallbacks active)"
        fi
    done
    echo "=================================================="
}

main() {
    local custom_config=""
    local override_interval=""
    local override_theme=""
    local headless_report=""
    local headless_csv=""

    # Parse command line options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--version)
                echo "SMD-TUI version $APP_VERSION"
                exit 0
                ;;
            --check-deps)
                check_dependencies
                exit 0
                ;;
            -c|--config)
                custom_config="${2:-}"
                shift 2
                ;;
            -i|--interval)
                override_interval="${2:-}"
                shift 2
                ;;
            -t|--theme)
                override_theme="${2:-}"
                shift 2
                ;;
            --export-report)
                if [[ $# -gt 1 && ! "$2" =~ ^- ]]; then
                    headless_report="$2"
                    shift 2
                else
                    headless_report="default"
                    shift 1
                fi
                ;;
            --export-csv)
                if [[ $# -gt 1 && ! "$2" =~ ^- ]]; then
                    headless_csv="$2"
                    shift 2
                else
                    headless_csv="default"
                    shift 1
                fi
                ;;
            *)
                echo "Unknown option: $1" >&2
                show_help
                exit 1
                ;;
        esac
    done

    # 1. Initialize configuration hierarchy
    config_init "$APP_DIR/config/defaults.conf" "$custom_config"

    # Apply runtime CLI overrides
    if [[ -n "$override_interval" ]]; then
        config_set_validated "REFRESH_INTERVAL" "$override_interval"
    fi
    if [[ -n "$override_theme" ]]; then
        config_set_validated "THEME" "$override_theme"
    fi

    # 2. Check for headless export modes
    if [[ -n "$headless_report" ]]; then
        local target=""
        if [[ "$headless_report" != "default" ]]; then target="$headless_report"; fi
        local generated
        generated=$(export_report_txt "$target")
        echo "System report generated: $generated"
        exit 0
    fi

    if [[ -n "$headless_csv" ]]; then
        local target=""
        if [[ "$headless_csv" != "default" ]]; then target="$headless_csv"; fi
        local generated
        generated=$(export_metrics_csv "$target")
        echo "Metrics CSV exported: $generated"
        exit 0
    fi

    # 3. Interactive TUI Mode Setup
    history_init "$CFG_HISTORY_RETENTION"
    alerts_init
    nav_init
    ui_theme_apply "$CFG_THEME"

    # Trap termination signals to guarantee terminal restoration
    trap cleanup_and_exit EXIT INT TERM HUP
    trap handle_resize WINCH

    ui_init_term

    # Initial metric collection
    system_collect
    cpu_collect
    mem_collect
    storage_collect
    network_collect
    thermal_collect
    battery_collect
    process_collect 25

    # Push initial metrics to history
    history_push "cpu" "$CPU_USAGE_TOTAL"
    history_push "mem" "$MEM_USAGE_PERCENT"
    if [[ "$THERMAL_CPU_TEMP" =~ ^[0-9]+$ ]]; then
        history_push "temp" "$THERMAL_CPU_TEMP"
    fi
    history_push "net_rx" "$NET_TOTAL_RX_BPS"
    history_push "net_tx" "$NET_TOTAL_TX_BPS"
    history_push "disk_r" "$STORAGE_TOTAL_READ_BPS"
    history_push "disk_w" "$STORAGE_TOTAL_WRITE_BPS"

    dashboard_draw

    local last_tick
    last_tick=$(date +%s)
    local sub_poll=0.2

    # Continuous Real-Time Interactive Loop
    while true; do
        # 1. Listen for user keyboard input (non-blocking, direct shell state mutation)
        ui_read_input "$sub_poll"

        case "$UI_ACTION" in
            QUIT)
                cleanup_and_exit
                ;;
            REDRAW|TAB_CHANGED|PAUSE)
                if [[ "$UI_ACTION" == "TAB_CHANGED" && "$UI_CURRENT_TAB" -eq 4 ]]; then
                    process_collect 25
                fi
                dashboard_draw
                ;;
            EXPORT)
                local r_file
                r_file=$(export_report_txt "")
                local c_file
                c_file=$(export_metrics_csv "")
                _add_alert "EXPORT" "INFO" "OK" "-" "Report exported to $(basename "$r_file")"
                dashboard_draw
                ;;
            REFRESH)
                # Force refresh
                last_tick=0
                ;;
            NONE)
                ;;
        esac

        # 2. Check if refresh interval elapsed
        local now
        now=$(date +%s)
        local elapsed=$(( now - last_tick ))

        if [[ $elapsed -ge $CFG_REFRESH_INTERVAL && "$UI_PAUSED" == "false" ]]; then
            last_tick="$now"

            # Fresh metrics collection
            system_collect_uptime
            cpu_collect
            mem_collect
            storage_collect
            network_collect
            thermal_collect
            battery_collect
            if [[ "$UI_CURRENT_TAB" -eq 4 ]]; then
                process_collect 25
            fi

            # Push to history ring buffers
            history_push "cpu" "$CPU_USAGE_TOTAL"
            history_push "mem" "$MEM_USAGE_PERCENT"
            if [[ "$THERMAL_CPU_TEMP" =~ ^[0-9]+$ ]]; then
                history_push "temp" "$THERMAL_CPU_TEMP"
            fi
            history_push "net_rx" "$NET_TOTAL_RX_BPS"
            history_push "net_tx" "$NET_TOTAL_TX_BPS"
            history_push "disk_r" "$STORAGE_TOTAL_READ_BPS"
            history_push "disk_w" "$STORAGE_TOTAL_WRITE_BPS"

            # Evaluate alerts
            local max_disk=0
            for d_pct in "${STORAGE_FS_PERCENT[@]}"; do
                if [[ $d_pct -gt $max_disk ]]; then max_disk="$d_pct"; fi
            done
            alerts_evaluate "$CPU_USAGE_TOTAL" "$MEM_USAGE_PERCENT" "$THERMAL_CPU_TEMP" "$max_disk"

            # Redraw dashboard
            dashboard_draw
        fi
    done
}

main "$@"
