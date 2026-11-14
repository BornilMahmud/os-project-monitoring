#!/usr/bin/env bash
# ui/dashboard.sh - Responsive Terminal UI dashboard and view renderers for SMD-TUI

# Render Top Application Header
dashboard_render_header() {
    local cols="$TERM_COLS"
    local now
    now=$(date +"%Y-%m-%d %H:%M:%S")

    local status_badge="${C_GOOD}[LIVE]${C_RESET}"
    if [[ "$UI_PAUSED" == "true" ]]; then
        status_badge="${C_WARN}[PAUSED]${C_RESET}"
    fi

    echo -e "${C_PRIMARY}${C_BOLD}┌─ SMD-TUI 2.0 ─ Linux Hardware Intelligence ──────────────────────────┐${C_RESET}"
    printf "${C_PRIMARY}│${C_RESET} Host: ${C_BOLD}%-15s${C_RESET} OS: %-18s Up: %-12s %b ${C_PRIMARY}│${C_RESET}\n" \
        "$SYS_HOSTNAME" \
        "$(ui_format_str "$SYS_DISTRO_PRETTY" 18)" \
        "$SYS_UPTIME_PRETTY" \
        "$status_badge"
    echo -e "${C_PRIMARY}├──────────────────────────────────────────────────────────────────────┤${C_RESET}"
}

# Render Navigation Tabs Bar
dashboard_render_tabs() {
    echo -n -e "${C_PRIMARY}│${C_RESET} "
    for i in "${!UI_TAB_NAMES[@]}"; do
        local tab_num=$(( i + 1 ))
        local key="$tab_num"
        if [[ $tab_num -eq 10 ]]; then key="0"; fi

        local tname="${UI_TAB_NAMES[$i]}"
        if [[ $tab_num -eq $UI_CURRENT_TAB ]]; then
            echo -n -e "${C_REV}${C_BOLD} ${key}:${tname} ${C_RESET} "
        else
            echo -n -e "${C_MUTED}${key}:${tname}${C_RESET} "
        fi
    done
    echo -e "${C_PRIMARY}│${C_RESET}"
    echo -e "${C_PRIMARY}├──────────────────────────────────────────────────────────────────────┤${C_RESET}"
}

# View 1: System Overview
render_view_overview() {
    echo -e "  ${C_BOLD}[ SYSTEM OVERVIEW ]${C_RESET}  ${C_DIM}Environment: $SYS_VIRT_TYPE${C_RESET}"
    echo ""

    # Row 1: CPU & Memory summary gauges
    local cpu_bar
    cpu_bar=$(render_gauge_bar "$CPU_USAGE_TOTAL" 18 "$CFG_GRAPH_STYLE")
    local mem_bar
    mem_bar=$(render_gauge_bar "$MEM_USAGE_PERCENT" 18 "$CFG_GRAPH_STYLE")

    echo -e "  CPU Usage    : ${C_PRIMARY}${cpu_bar}${C_RESET}  ${C_DIM}($CPU_INFO_MODEL)${C_RESET}"
    echo -e "  Memory Usage : ${C_PRIMARY}${mem_bar}${C_RESET}  ${C_DIM}($(format_bytes $(( MEM_USED_KB * 1024 ))) / $(format_bytes $(( MEM_TOTAL_KB * 1024 ))))${C_RESET}"
    if [[ "$SYS_IS_WSL" == "true" ]]; then
        echo -e "                 ${C_DIM}└─ Host Physical RAM: $SYS_HOST_RAM_GB${C_RESET}"
    fi

    echo ""
    # Row 2: Disk I/O & Network throughput
    echo -e "  Disk Read    : ${C_GOOD}$(format_speed "$STORAGE_TOTAL_READ_BPS")${C_RESET}      Disk Write : ${C_WARN}$(format_speed "$STORAGE_TOTAL_WRITE_BPS")${C_RESET}"
    echo -e "  Download     : ${C_GOOD}$(format_speed "$NET_TOTAL_RX_BPS")${C_RESET}      Upload     : ${C_WARN}$(format_speed "$NET_TOTAL_TX_BPS")${C_RESET}"

    echo ""
    # Row 3: Thermals & Battery
    if [[ "$THERMAL_STATUS" == "OK" ]]; then
        echo -e "  CPU Temp     : ${C_WARN}${THERMAL_CPU_TEMP}°C${C_RESET}  Sensors: $THERMAL_COUNT active"
    else
        echo -e "  Thermal Temp : ${C_DIM}N/A (Virtualized / Hyper-V guest)${C_RESET}"
    fi

    if [[ "$BATTERY_PRESENT" == "true" ]]; then
        echo -e "  Power Supply : Battery ($BATTERY_PERCENT%) - $BATTERY_STATUS"
    else
        echo -e "  Power Supply : Desktop PC / AC Power"
    fi

    echo ""
    # Active alerts summary if any
    if [[ $ALERTS_ACTIVE_COUNT -gt 0 ]]; then
        echo -e "  ${C_CRIT}${C_BOLD}! ACTIVE ALERTS (${ALERTS_ACTIVE_COUNT}):${C_RESET}"
        for i in "${!ALERT_METRIC[@]}"; do
            echo -e "    ${C_CRIT}• [${ALERT_LEVEL[$i]}] ${ALERT_METRIC[$i]}: ${ALERT_VALUE[$i]} (Threshold: ${ALERT_THRESHOLD[$i]}) - ${ALERT_MESSAGE[$i]}${C_RESET}"
        done
    else
        echo -e "  ${C_GOOD}✓ System Status: Healthy (All metrics within normal thresholds)${C_RESET}"
    fi
}

# View 2: CPU Monitoring & Trend Graph
render_view_cpu() {
    echo -e "  ${C_BOLD}[ CPU HARDWARE & UTILIZATION ]${C_RESET}"
    echo -e "  Model         : ${C_BOLD}$CPU_INFO_MODEL${C_RESET}"
    echo -e "  Architecture  : ${C_GOOD}${CPU_INFO_PHYSICAL_CORES} Physical Cores, ${CPU_INFO_LOGICAL_CORES} Logical Threads${C_RESET}"
    echo -e "  Clock Speed   : $CPU_INFO_MHZ MHz"
    echo -e "  Load Averages : $CPU_LOAD_1M (1m)  $CPU_LOAD_5M (5m)  $CPU_LOAD_15M (15m)"
    echo -e "  Task States   : $CPU_LOAD_RUNNABLE running / $CPU_LOAD_TOTAL_PROCS total tasks"
    echo ""

    # Live multi-line trend chart
    local series=($(history_get_series "cpu"))
    render_trend_chart 5 45 100 "CPU Utilization % History" "${series[@]}"

    echo ""
    echo -e "  ${C_BOLD}Per-Core Utilization:${C_RESET}"
    for i in "${!CPU_USAGE_CORES[@]}"; do
        local cbar
        cbar=$(render_gauge_bar "${CPU_USAGE_CORES[$i]}" 10 "$CFG_GRAPH_STYLE")
        printf "  Core %-2d: %b" "$i" "$cbar"
        if [[ $(( (i + 1) % 2 )) -eq 0 ]]; then
            echo ""
        fi
    done
    if [[ $(( ${#CPU_USAGE_CORES[@]} % 2 )) -ne 0 ]]; then echo ""; fi
}

# View 3: Memory Monitoring & Trend Graph
render_view_memory() {
    echo -e "  ${C_BOLD}[ MEMORY & SWAP INTELLIGENCE ]${C_RESET}"
    if [[ "$SYS_IS_WSL" == "true" ]]; then
        echo -e "  Linux VM RAM  : $(format_bytes $(( MEM_TOTAL_KB * 1024 ))) ${C_DIM}(Allocated by Windows: ~50% of $SYS_HOST_RAM_GB host RAM)${C_RESET}"
    else
        echo -e "  Total RAM     : $(format_bytes $(( MEM_TOTAL_KB * 1024 )))"
    fi
    echo -e "  Used RAM      : ${C_WARN}$(format_bytes $(( MEM_USED_KB * 1024 ))) (${MEM_USAGE_PERCENT}%)${C_RESET}"
    echo -e "  Available RAM : ${C_GOOD}$(format_bytes $(( MEM_AVAIL_KB * 1024 )))${C_RESET}"
    echo -e "  Free RAM      : $(format_bytes $(( MEM_FREE_KB * 1024 )))"
    echo -e "  Buffers/Cache : $(format_bytes $(( (MEM_BUFFERS_KB + MEM_CACHED_KB) * 1024 )))"
    if [[ $MEM_SWAP_TOTAL_KB -gt 0 ]]; then
        echo -e "  Swap Usage    : $(format_bytes $(( MEM_SWAP_USED_KB * 1024 ))) / $(format_bytes $(( MEM_SWAP_TOTAL_KB * 1024 ))) (${MEM_SWAP_PERCENT}%)"
    else
        echo -e "  Swap Usage    : None / Disabled"
    fi
    echo ""

    local series=($(history_get_series "mem"))
    render_trend_chart 5 45 100 "RAM Consumption % History" "${series[@]}"
}

# View 4: Scrollable Top Processes
render_view_processes() {
    echo -e "  ${C_BOLD}[ TOP CONSUMING PROCESSES ]${C_RESET}  ${C_DIM}(Scroll: Up/Down/j/k | Offset: $NAV_SCROLL_OFFSET)${C_RESET}"
    echo ""
    printf "  ${C_BOLD}%-7s %-12s %-8s %-8s %-30s${C_RESET}\n" "PID" "USER" "%CPU" "%MEM" "COMMAND"
    echo "  ──────────────────────────────────────────────────────────────────"

    local start="$NAV_SCROLL_OFFSET"
    local end=$(( start + 12 ))
    local total="${#PROC_CPU_PID[@]}"

    for ((i=start; i<end && i<total; i++)); do
        printf "  %-7s %-12s %-8s %-8s %-30s\n" \
            "${PROC_CPU_PID[$i]}" \
            "${PROC_CPU_USER[$i]}" \
            "${PROC_CPU_PCT[$i]}%" \
            "${PROC_CPU_MEM[$i]}%" \
            "$(ui_format_str "${PROC_CPU_COMM[$i]}" 30)"
    done
}

# View 5: Thermals & Fans
render_view_thermals() {
    echo -e "  ${C_BOLD}[ THERMAL SENSORS & COOLING FANS ]${C_RESET}"
    echo ""
    if [[ "$THERMAL_STATUS" == "OK" ]]; then
        echo -e "  Primary CPU Temp : ${C_WARN}${THERMAL_CPU_TEMP}°C${C_RESET}"
        echo ""
        echo "  Discovered Sensors:"
        for i in "${!THERMAL_NAMES[@]}"; do
            echo -e "    - ${THERMAL_NAMES[$i]}: ${C_BOLD}${THERMAL_TEMPS[$i]}°C${C_RESET}"
        done
        if [[ $THERMAL_FAN_COUNT -gt 0 ]]; then
            echo ""
            echo "  Cooling Fans:"
            for i in "${!THERMAL_FAN_NAMES[@]}"; do
                echo -e "    - ${THERMAL_FAN_NAMES[$i]}: ${THERMAL_FAN_RPM[$i]} RPM"
            done
        fi
    else
        echo -e "  Thermal Status   : ${C_DIM}N/A${C_RESET}"
        echo -e "  Reason           : Running inside a virtualized environment ($SYS_VIRT_TYPE)."
        echo -e "                     Hyper-V does not expose motherboard ACPI thermal zones to Linux guests."
    fi
}

# View 6: Storage & Disk I/O
render_view_storage() {
    echo -e "  ${C_BOLD}[ STORAGE & DISK I/O ]${C_RESET}"
    echo -e "  Disk Read I/O    : ${C_GOOD}$(format_speed "$STORAGE_TOTAL_READ_BPS")${C_RESET}"
    echo -e "  Disk Write I/O   : ${C_WARN}$(format_speed "$STORAGE_TOTAL_WRITE_BPS")${C_RESET}"
    echo ""
    echo "  Active Disks & Mountpoints:"
    printf "  ${C_BOLD}%-15s %-10s %-10s %-18s %s${C_RESET}\n" "Device" "Total" "Used" "Usage" "Mount"
    echo "  ──────────────────────────────────────────────────────────────────"
    for i in "${!STORAGE_FS_MOUNT[@]}"; do
        local size
        size=$(format_bytes $(( ${STORAGE_FS_SIZE_KB[$i]} * 1024 )))
        local used
        used=$(format_bytes $(( ${STORAGE_FS_USED_KB[$i]} * 1024 )))
        local bar
        bar=$(render_gauge_bar "${STORAGE_FS_PERCENT[$i]}" 10 "$CFG_GRAPH_STYLE")

        printf "  %-15s %-10s %-10s %-18b %s\n" \
            "${STORAGE_FS_DEVICE[$i]}" \
            "$size" \
            "$used" \
            "$bar" \
            "${STORAGE_FS_MOUNT[$i]}"
    done
}

# View 7: Network Telemetry
render_view_network() {
    echo -e "  ${C_BOLD}[ NETWORK INTERFACES & THROUGHPUT ]${C_RESET}"
    echo -e "  Total Download   : ${C_GOOD}$(format_speed "$NET_TOTAL_RX_BPS")${C_RESET}"
    echo -e "  Total Upload     : ${C_WARN}$(format_speed "$NET_TOTAL_TX_BPS")${C_RESET}"
    echo ""
    echo "  Interface Details:"
    printf "  ${C_BOLD}%-12s %-10s %-16s %-16s %s${C_RESET}\n" "Interface" "State" "Rx Speed" "Tx Speed" "Total Rx / Tx"
    echo "  ──────────────────────────────────────────────────────────────────"
    for i in "${!NET_IFACES[@]}"; do
        local rx_sp
        rx_sp=$(format_speed "${NET_IFACE_RX_BPS[$i]}")
        local tx_sp
        tx_sp=$(format_speed "${NET_IFACE_TX_BPS[$i]}")
        local rx_tot
        rx_tot=$(format_bytes "${NET_IFACE_TOTAL_RX[$i]}")
        local tx_tot
        tx_tot=$(format_bytes "${NET_IFACE_TOTAL_TX[$i]}")

        printf "  %-12s %-10s %-16s %-16s %s / %s\n" \
            "${NET_IFACES[$i]}" \
            "[${NET_IFACE_STATUS[$i]}]" \
            "$rx_sp" \
            "$tx_sp" \
            "$rx_tot" \
            "$tx_tot"
    done
}

# View 8: Battery & Power Supply
render_view_battery() {
    echo -e "  ${C_BOLD}[ BATTERY & POWER SUPPLY ]${C_RESET}"
    echo ""
    if [[ "$BATTERY_PRESENT" == "true" ]]; then
        echo -e "  Battery State    : ${C_BOLD}$BATTERY_STATUS${C_RESET} ($BATTERY_PERCENT%)"
        echo -e "  Health Status    : $BATTERY_HEALTH"
        echo -e "  Technology       : $BATTERY_TECH"
        echo -e "  Power Rate       : ${BATTERY_POWER_W} W"
    else
        echo -e "  Power Source     : Desktop PC / AC Mains Power (AMD Ryzen 5700G)"
        echo -e "  Battery Presence : Not Detected"
    fi
}

# View 9: Active Alerts Log
render_view_alerts() {
    echo -e "  ${C_BOLD}[ INFORMATIONAL THRESHOLD ALERTS ]${C_RESET}  ${C_DIM}(Strictly non-destructive)${C_RESET}"
    echo ""
    if [[ ${#ALERT_TIME[@]} -eq 0 ]]; then
        echo -e "  ${C_GOOD}✓ No active or historical alerts recorded. System healthy.${C_RESET}"
    else
        printf "  ${C_BOLD}%-10s %-8s %-10s %-8s %-10s %s${C_RESET}\n" "TIME" "LEVEL" "METRIC" "VALUE" "THRESH" "MESSAGE"
        echo "  ──────────────────────────────────────────────────────────────────"
        for i in "${!ALERT_TIME[@]}"; do
            local lvl_color="$C_WARN"
            if [[ "${ALERT_LEVEL[$i]}" == "CRITICAL" ]]; then lvl_color="$C_CRIT"; fi

            printf "  %-10s ${lvl_color}%-8s${C_RESET} %-10s %-8s %-10s %s\n" \
                "${ALERT_TIME[$i]}" \
                "[${ALERT_LEVEL[$i]}]" \
                "${ALERT_METRIC[$i]}" \
                "${ALERT_VALUE[$i]}" \
                "${ALERT_THRESHOLD[$i]}" \
                "${ALERT_MESSAGE[$i]}"
        done
    fi
}

# View 10: Settings & Diagnostics
render_view_settings() {
    echo -e "  ${C_BOLD}[ SMD-TUI 2.0 SETTINGS & DIAGNOSTICS ]${C_RESET}"
    echo ""
    echo -e "  Refresh Interval : ${C_BOLD}${CFG_REFRESH_INTERVAL}s${C_RESET}"
    echo -e "  Interface Theme  : ${C_BOLD}${CFG_THEME}${C_RESET}"
    echo -e "  Graph Style      : ${C_BOLD}${CFG_GRAPH_STYLE}${C_RESET}"
    echo -e "  History Buffer   : ${CFG_HISTORY_RETENTION} data points"
    echo -e "  Alert Thresholds : CPU: ${CFG_CPU_ALERT_THRESHOLD}% | RAM: ${CFG_MEM_ALERT_THRESHOLD}% | Temp: ${CFG_TEMP_ALERT_THRESHOLD}°C | Disk: ${CFG_DISK_ALERT_THRESHOLD}%"
    echo ""
    echo -e "  ${C_BOLD}Active Storage Locations (XDG Compliant):${C_RESET}"
    echo -e "    Config File    : ${SMD_CONFIG_DIR}/config.conf"
    echo -e "    Data / Reports : ${SMD_REPORT_DIR}"
    echo -e "    CSV Exports    : ${SMD_EXPORT_DIR}"
    echo ""
    echo -e "  ${C_DIM}Security: Strictly read-only monitoring. Zero write access to system interfaces.${C_RESET}"
}

# Render Help Screen Modal
dashboard_render_help() {
    echo -e "${C_PRIMARY}${C_BOLD}┌─ KEYBOARD SHORTCUTS & HELP ──────────────────────────────────────────┐${C_RESET}"
    echo -e "  ${C_BOLD}1 - 9, 0${C_RESET}   : Switch to Tab (1:Overview, 2:CPU, 3:RAM ... 0:Settings)"
    echo -e "  ${C_BOLD}Tab${C_RESET}        : Cycle to next tab"
    echo -e "  ${C_BOLD}Left / Right${C_RESET}: Previous / Next tab"
    echo -e "  ${C_BOLD}Up / Down${C_RESET}  : Scroll process table / alerts list"
    echo -e "  ${C_BOLD}P${C_RESET}          : Pause / Resume live data refreshing"
    echo -e "  ${C_BOLD}R${C_RESET}          : Force immediate metric refresh"
    echo -e "  ${C_BOLD}E${C_RESET}          : Export live report and CSV metrics log"
    echo -e "  ${C_BOLD}H or ?${C_RESET}     : Toggle this help overlay"
    echo -e "  ${C_BOLD}Q / Esc${C_RESET}    : Cleanly quit SMD-TUI and restore terminal"
    echo -e "${C_PRIMARY}└──────────────────────────────────────────────────────────────────────┘${C_RESET}"
}

# Render Bottom Footer
dashboard_render_footer() {
    echo -e "${C_PRIMARY}├──────────────────────────────────────────────────────────────────────┤${C_RESET}"
    printf "${C_PRIMARY}│${C_RESET} ${C_MUTED}[1-9] Tabs [Arrows] Nav [P]ause [R]efresh [E]xport [H]elp [Q]uit${C_RESET} ${C_PRIMARY}│${C_RESET}\n"
    echo -e "${C_PRIMARY}└──────────────────────────────────────────────────────────────────────┘${C_RESET}"
}

# Main dashboard render function
dashboard_draw() {
    ui_get_term_size
    ui_cursor 1 1

    dashboard_render_header
    dashboard_render_tabs

    if [[ "$UI_SHOW_HELP" == "true" ]]; then
        dashboard_render_help
    else
        case "$UI_CURRENT_TAB" in
            1) render_view_overview ;;
            2) render_view_cpu ;;
            3) render_view_memory ;;
            4) render_view_processes ;;
            5) render_view_thermals ;;
            6) render_view_storage ;;
            7) render_view_network ;;
            8) render_view_battery ;;
            9) render_view_alerts ;;
            10) render_view_settings ;;
        esac
    fi

    dashboard_render_footer
}
