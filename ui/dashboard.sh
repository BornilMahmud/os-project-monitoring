#!/usr/bin/env bash
# ui/dashboard.sh - Responsive, Clean Terminal UI Dashboard & View Renderers for SMD-TUI 2.0

# Render Top Application Header
dashboard_render_header() {
    local w="$BOX_WIDTH"
    local fill_top=$(( w - 46 ))
    if [[ $fill_top -lt 2 ]]; then fill_top=2; fi

    local status_badge="${C_GOOD}[LIVE]${C_RESET}"
    if [[ "$UI_PAUSED" == "true" ]]; then
        status_badge="${C_WARN}[PAUSED]${C_RESET}"
    fi

    echo -e "${C_BORDER}╭─ ${C_PRIMARY}${C_BOLD}SMD-TUI 2.0${C_RESET} ${C_MUTED}• Linux Hardware Intelligence${C_RESET} ${C_BORDER}$(ui_repeat "─" "$fill_top")╮${C_RESET}"

    # Inner width = w - 4 (excluding "│ " and " │")
    local inner_w=$(( w - 4 ))
    local host_str="Host: ${SYS_HOSTNAME}"
    local os_str="OS: $(ui_format_str "$SYS_DISTRO_PRETTY" 18)"
    local up_str="Up: ${SYS_UPTIME_PRETTY}"

    printf "${C_BORDER}│${C_RESET}  ${C_TEXT}%-18s${C_RESET} ${C_MUTED}%-22s${C_RESET} ${C_MUTED}%-16s${C_RESET} %b" \
        "$host_str" "$os_str" "$up_str" "$status_badge"

    # Pad remaining space on the right
    local printed_len=$(( 18 + 22 + 16 + 8 ))
    local pad_right=$(( inner_w - printed_len ))
    if [[ $pad_right -gt 0 ]]; then
        printf "%*s" "$pad_right" ""
    fi
    printf " ${C_BORDER}│${C_RESET}\n"

    echo -e "${C_BORDER}├$(ui_repeat "─" $(( w - 2 )))┤${C_RESET}"
}

# Render Navigation Tabs Bar with clean spacing and pill highlight
dashboard_render_tabs() {
    local w="$BOX_WIDTH"
    printf "${C_BORDER}│${C_RESET} "

    local used_len=2
    for i in "${!UI_TAB_NAMES[@]}"; do
        local tab_num=$(( i + 1 ))
        local key="$tab_num"
        if [[ $tab_num -eq 10 ]]; then key="0"; fi

        local tname="${UI_TAB_NAMES[$i]}"
        if [[ $tab_num -eq $UI_CURRENT_TAB ]]; then
            printf "${C_PRIMARY}${C_REV}${C_BOLD} %s %s ${C_RESET} " "$key" "$tname"
            used_len=$(( used_len + ${#key} + ${#tname} + 4 ))
        else
            printf "${C_MUTED} %s:%s ${C_RESET} " "$key" "$tname"
            used_len=$(( used_len + ${#key} + ${#tname} + 4 ))
        fi
    done

    local pad=$(( w - used_len - 1 ))
    if [[ $pad -gt 0 ]]; then
        printf "%*s" "$pad" ""
    fi
    printf "${C_BORDER}│${C_RESET}\n"
    echo -e "${C_BORDER}├$(ui_repeat "─" $(( w - 2 )))┤${C_RESET}"
}

# View 1: System Overview (Fresh, spacious, modern card sections)
render_view_overview() {
    echo ""
    # Section 1: Environment & Host Identity
    echo -e "  ${C_CARD_HEAD}┌─ [ ENVIRONMENT & HOST IDENTITY ]${C_RESET}"
    if [[ "$SYS_IS_WSL" == "true" ]]; then
        echo -e "  ${C_BORDER}│${C_RESET}  ${C_MUTED}Host Machine :${C_RESET} ${C_TEXT}Windows${C_RESET} ${C_DIM}(Host Uptime: ${SYS_HOST_UPTIME} | Host RAM: ${SYS_HOST_RAM_GB})${C_RESET}"
        if [[ "$SYS_HOST_GPU" != "N/A" ]]; then
            echo -e "  ${C_BORDER}│${C_RESET}  ${C_MUTED}Host Graphics:${C_RESET} ${C_PRIMARY}${SYS_HOST_GPU}${C_RESET}"
        fi
    fi
    echo -e "  ${C_BORDER}│${C_RESET}  ${C_MUTED}Linux Guest  :${C_RESET} ${C_TEXT}${SYS_DISTRO_PRETTY}${C_RESET} ${C_DIM}(Kernel: ${SYS_KERNEL} ${SYS_ARCH})${C_RESET}"
    echo -e "  ${C_BORDER}│${C_RESET}  ${C_MUTED}Environment  :${C_RESET} ${C_PRIMARY}${SYS_VIRT_TYPE}${C_RESET} ${C_DIM}(Active User: ${SYS_CURRENT_USER})${C_RESET}"
    echo ""

    # Section 2: Processor & Memory Load
    local cpu_bar
    cpu_bar=$(render_gauge_bar "$CPU_USAGE_TOTAL" 22 "$CFG_GRAPH_STYLE")
    local mem_bar
    mem_bar=$(render_gauge_bar "$MEM_USAGE_PERCENT" 22 "$CFG_GRAPH_STYLE")

    echo -e "  ${C_CARD_HEAD}┌─ [ PROCESSOR & MEMORY LOAD ]${C_RESET}"
    echo -e "  ${C_BORDER}│${C_RESET}  ${C_MUTED}CPU Utilization :${C_RESET} ${C_PRIMARY}${cpu_bar}${C_RESET}   ${C_DIM}${CPU_INFO_MODEL}${C_RESET}"
    echo -e "  ${C_BORDER}│${C_RESET}  ${C_MUTED}Memory Load     :${C_RESET} ${C_ACCENT}${mem_bar}${C_RESET}   ${C_DIM}$(format_bytes $(( MEM_USED_KB * 1024 ))) used / $(format_bytes $(( MEM_TOTAL_KB * 1024 ))) allocated${C_RESET}"
    echo ""

    # Section 3: Storage & Network Telemetry
    echo -e "  ${C_CARD_HEAD}┌─ [ REAL-TIME I/O & NETWORK THROUGHPUT ]${C_RESET}"
    printf "  ${C_BORDER}│${C_RESET}  ${C_MUTED}%-16s:${C_RESET} ${C_GOOD}%-18s${C_RESET} ${C_MUTED}%-18s:${C_RESET} ${C_GOOD}%s${C_RESET}\n" \
        "Storage Read" "$(format_speed "$STORAGE_TOTAL_READ_BPS")" \
        "Network Download" "$(format_speed "$NET_TOTAL_RX_BPS")"
    printf "  ${C_BORDER}│${C_RESET}  ${C_MUTED}%-16s:${C_RESET} ${C_WARN}%-18s${C_RESET} ${C_MUTED}%-18s:${C_RESET} ${C_WARN}%s${C_RESET}\n" \
        "Storage Write" "$(format_speed "$STORAGE_TOTAL_WRITE_BPS")" \
        "Network Upload" "$(format_speed "$NET_TOTAL_TX_BPS")"
    echo ""

    # Section 4: Hardware Sensors & Health
    echo -e "  ${C_CARD_HEAD}┌─ [ HARDWARE STATUS & HEALTH ]${C_RESET}"
    if [[ "$THERMAL_STATUS" == "OK" ]]; then
        echo -e "  ${C_BORDER}│${C_RESET}  ${C_MUTED}CPU Temperature :${C_RESET} ${C_WARN}${THERMAL_CPU_TEMP}°C${C_RESET} ${C_DIM}(${THERMAL_COUNT} sensors active)${C_RESET}"
    else
        echo -e "  ${C_BORDER}│${C_RESET}  ${C_MUTED}Thermal Status  :${C_RESET} ${C_DIM}N/A (Virtualized; Hyper-V does not expose motherboard ACPI)${C_RESET}"
    fi

    if [[ "$BATTERY_PRESENT" == "true" ]]; then
        echo -e "  ${C_BORDER}│${C_RESET}  ${C_MUTED}Power Source    :${C_RESET} ${C_TEXT}Battery (${BATTERY_PERCENT}%) - ${BATTERY_STATUS}${C_RESET}"
    else
        echo -e "  ${C_BORDER}│${C_RESET}  ${C_MUTED}Power Source    :${C_RESET} ${C_TEXT}Desktop PC / AC Mains Power${C_RESET}"
    fi

    if [[ $ALERTS_ACTIVE_COUNT -gt 0 ]]; then
        echo -e "  ${C_BORDER}│${C_RESET}  ${C_CRIT}${C_BOLD}! ALERTS (${ALERTS_ACTIVE_COUNT}):${C_RESET}"
        for i in "${!ALERT_METRIC[@]}"; do
            echo -e "  ${C_BORDER}│${C_RESET}    ${C_CRIT}• [${ALERT_LEVEL[$i]}] ${ALERT_METRIC[$i]}: ${ALERT_VALUE[$i]} (Limit: ${ALERT_THRESHOLD[$i]}) - ${ALERT_MESSAGE[$i]}${C_RESET}"
        done
    else
        echo -e "  ${C_BORDER}│${C_RESET}  ${C_MUTED}System Status   :${C_RESET} ${C_GOOD}● Healthy (All operational metrics within normal limits)${C_RESET}"
    fi
    echo ""
}

# View 2: CPU Monitoring & Trend Graph
render_view_cpu() {
    echo ""
    echo -e "  ${C_CARD_HEAD}┌─ [ PROCESSOR HARDWARE SPECIFICATIONS ]${C_RESET}"
    echo -e "  ${C_BORDER}│${C_RESET}  ${C_MUTED}Processor Model :${C_RESET} ${C_TEXT}${C_BOLD}$CPU_INFO_MODEL${C_RESET}"
    echo -e "  ${C_BORDER}│${C_RESET}  ${C_MUTED}Architecture    :${C_RESET} ${C_GOOD}${CPU_INFO_PHYSICAL_CORES} Physical Cores, ${CPU_INFO_LOGICAL_CORES} Logical Processors (Threads)${C_RESET}"
    echo -e "  ${C_BORDER}│${C_RESET}  ${C_MUTED}Clock Frequency :${C_RESET} ${C_TEXT}$CPU_INFO_MHZ MHz${C_RESET}"
    echo -e "  ${C_BORDER}│${C_RESET}  ${C_MUTED}Load Averages   :${C_RESET} ${C_TEXT}$CPU_LOAD_1M${C_RESET} (1m)   ${C_TEXT}$CPU_LOAD_5M${C_RESET} (5m)   ${C_TEXT}$CPU_LOAD_15M${C_RESET} (15m)"
    echo -e "  ${C_BORDER}│${C_RESET}  ${C_MUTED}Active Tasks    :${C_RESET} ${C_TEXT}$CPU_LOAD_RUNNABLE running / $CPU_LOAD_TOTAL_PROCS total tasks${C_RESET}"
    echo ""

    # Live multi-line trend chart
    local series=($(history_get_series "cpu"))
    render_trend_chart 5 48 100 "CPU Utilization % History" "${series[@]}"
    echo ""

    echo -e "  ${C_CARD_HEAD}┌─ [ PER-CORE REAL-TIME LOAD ]${C_RESET}"
    for i in "${!CPU_USAGE_CORES[@]}"; do
        local cbar
        cbar=$(render_gauge_bar "${CPU_USAGE_CORES[$i]}" 8 "$CFG_GRAPH_STYLE")
        printf "  Core %-2d: %b  " "$i" "$cbar"
        if [[ $(( (i + 1) % 4 )) -eq 0 ]]; then
            echo ""
        fi
    done
    if [[ $(( ${#CPU_USAGE_CORES[@]} % 4 )) -ne 0 ]]; then echo ""; fi
    echo ""
}

# View 3: Memory Monitoring & Trend Graph
render_view_memory() {
    echo ""
    echo -e "  ${C_CARD_HEAD}┌─ [ MEMORY ALLOCATION & BREAKDOWN ]${C_RESET}"
    if [[ "$SYS_IS_WSL" == "true" ]]; then
        echo -e "  ${C_BORDER}│${C_RESET}  ${C_MUTED}Host Machine RAM :${C_RESET} ${C_TEXT}${C_BOLD}$SYS_HOST_RAM_GB Total Physical PC Memory${C_RESET}"
        echo -e "  ${C_BORDER}│${C_RESET}  ${C_MUTED}Linux Guest RAM  :${C_RESET} ${C_TEXT}$(format_bytes $(( MEM_TOTAL_KB * 1024 )))${C_RESET} ${C_DIM}(Allocated by Hyper-V: ~50% of Host RAM)${C_RESET}"
    else
        echo -e "  ${C_BORDER}│${C_RESET}  ${C_MUTED}Total System RAM :${C_RESET} ${C_TEXT}$(format_bytes $(( MEM_TOTAL_KB * 1024 )))${C_RESET}"
    fi

    echo -e "  ${C_BORDER}│${C_RESET}  ${C_MUTED}Used Memory      :${C_RESET} ${C_WARN}$(format_bytes $(( MEM_USED_KB * 1024 ))) (${MEM_USAGE_PERCENT}%)${C_RESET}"
    echo -e "  ${C_BORDER}│${C_RESET}  ${C_MUTED}Available Memory :${C_RESET} ${C_GOOD}$(format_bytes $(( MEM_AVAIL_KB * 1024 )))${C_RESET}"
    echo -e "  ${C_BORDER}│${C_RESET}  ${C_MUTED}Free Memory      :${C_RESET} ${C_TEXT}$(format_bytes $(( MEM_FREE_KB * 1024 )))${C_RESET}"
    echo -e "  ${C_BORDER}│${C_RESET}  ${C_MUTED}Buffers & Cache  :${C_RESET} ${C_TEXT}$(format_bytes $(( (MEM_BUFFERS_KB + MEM_CACHED_KB) * 1024 )))${C_RESET}"

    if [[ $MEM_SWAP_TOTAL_KB -gt 0 ]]; then
        echo -e "  ${C_BORDER}│${C_RESET}  ${C_MUTED}Swap File Usage  :${C_RESET} ${C_TEXT}$(format_bytes $(( MEM_SWAP_USED_KB * 1024 ))) / $(format_bytes $(( MEM_SWAP_TOTAL_KB * 1024 ))) (${MEM_SWAP_PERCENT}%)${C_RESET}"
    else
        echo -e "  ${C_BORDER}│${C_RESET}  ${C_MUTED}Swap File Usage  :${C_RESET} ${C_DIM}None / Disabled${C_RESET}"
    fi
    echo ""

    local series=($(history_get_series "mem"))
    render_trend_chart 5 48 100 "RAM Consumption % History" "${series[@]}"
    echo ""
}

# View 4: Scrollable Top Processes
render_view_processes() {
    echo ""
    echo -e "  ${C_CARD_HEAD}┌─ [ TOP RESOURCE-CONSUMING PROCESSES ]${C_RESET}  ${C_DIM}(Scroll: Up/Down or j/k | Offset: $NAV_SCROLL_OFFSET)${C_RESET}"
    echo ""
    printf "  ${C_BOLD}%-8s %-14s %-10s %-10s %-32s${C_RESET}\n" "PID" "USER" "%CPU" "%MEM" "COMMAND"
    echo -e "  ${C_BORDER}$(ui_repeat "─" 76)${C_RESET}"

    local start="$NAV_SCROLL_OFFSET"
    local end=$(( start + 12 ))
    local total="${#PROC_CPU_PID[@]}"

    for ((i=start; i<end && i<total; i++)); do
        printf "  %-8s %-14s ${C_PRIMARY}%-10s${C_RESET} %-10s %-32s\n" \
            "${PROC_CPU_PID[$i]}" \
            "${PROC_CPU_USER[$i]}" \
            "${PROC_CPU_PCT[$i]}%" \
            "${PROC_CPU_MEM[$i]}%" \
            "$(ui_format_str "${PROC_CPU_COMM[$i]}" 32)"
    done
    echo ""
}

# View 5: Thermals & Fans
render_view_thermals() {
    echo ""
    echo -e "  ${C_CARD_HEAD}┌─ [ THERMAL SENSORS & COOLING HARDWARE ]${C_RESET}"
    echo ""
    if [[ "$THERMAL_STATUS" == "OK" ]]; then
        echo -e "  ${C_BORDER}│${C_RESET}  ${C_MUTED}Primary CPU Temp :${C_RESET} ${C_WARN}${THERMAL_CPU_TEMP}°C${C_RESET}"
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
        echo -e "  ${C_BORDER}│${C_RESET}  ${C_MUTED}Thermal Status   :${C_RESET} ${C_DIM}N/A${C_RESET}"
        echo -e "  ${C_BORDER}│${C_RESET}  ${C_MUTED}Environment Note :${C_RESET} Running inside ${SYS_VIRT_TYPE}."
        echo -e "  ${C_BORDER}│${C_RESET}                     Hyper-V does not expose motherboard ACPI thermal zones to Linux guests."
        if [[ "$SYS_HOST_GPU" != "N/A" ]]; then
            echo ""
            echo -e "  ${C_BORDER}│${C_RESET}  ${C_MUTED}Host Graphics    :${C_RESET} ${C_PRIMARY}${C_BOLD}$SYS_HOST_GPU${C_RESET}"
        fi
    fi
    echo ""
}

# View 6: Storage & Disk I/O
render_view_storage() {
    echo ""
    echo -e "  ${C_CARD_HEAD}┌─ [ STORAGE DISK THROUGHPUT ]${C_RESET}"
    printf "  ${C_BORDER}│${C_RESET}  ${C_MUTED}%-16s:${C_RESET} ${C_GOOD}%-18s${C_RESET} ${C_MUTED}%-16s:${C_RESET} ${C_WARN}%s${C_RESET}\n" \
        "Disk Read I/O" "$(format_speed "$STORAGE_TOTAL_READ_BPS")" \
        "Disk Write I/O" "$(format_speed "$STORAGE_TOTAL_WRITE_BPS")"
    echo ""

    echo -e "  ${C_CARD_HEAD}┌─ [ MOUNTED STORAGE VOLUMES & HOST DRIVES ]${C_RESET}"
    printf "  ${C_BOLD}%-16s %-12s %-12s %-20s %s${C_RESET}\n" "Device / Drive" "Capacity" "Used Space" "Usage Gauge" "Mountpoint"
    echo -e "  ${C_BORDER}$(ui_repeat "─" 76)${C_RESET}"

    for i in "${!STORAGE_FS_MOUNT[@]}"; do
        local size
        size=$(format_bytes $(( ${STORAGE_FS_SIZE_KB[$i]} * 1024 )))
        local used
        used=$(format_bytes $(( ${STORAGE_FS_USED_KB[$i]} * 1024 )))
        local bar
        bar=$(render_gauge_bar "${STORAGE_FS_PERCENT[$i]}" 10 "$CFG_GRAPH_STYLE")

        printf "  %-16s %-12s %-12s %-20b %s\n" \
            "${STORAGE_FS_DEVICE[$i]}" \
            "$size" \
            "$used" \
            "$bar" \
            "${STORAGE_FS_MOUNT[$i]}"
    done
    echo ""
}

# View 7: Network Telemetry
render_view_network() {
    echo ""
    echo -e "  ${C_CARD_HEAD}┌─ [ NETWORK AGGREGATE BANDWIDTH ]${C_RESET}"
    printf "  ${C_BORDER}│${C_RESET}  ${C_MUTED}%-16s:${C_RESET} ${C_GOOD}%-18s${C_RESET} ${C_MUTED}%-16s:${C_RESET} ${C_WARN}%s${C_RESET}\n" \
        "Total Download" "$(format_speed "$NET_TOTAL_RX_BPS")" \
        "Total Upload" "$(format_speed "$NET_TOTAL_TX_BPS")"
    echo ""

    echo -e "  ${C_CARD_HEAD}┌─ [ NETWORK INTERFACE STATUS & THROUGHPUT ]${C_RESET}"
    printf "  ${C_BOLD}%-12s %-8s %-16s %-16s %s${C_RESET}\n" "Interface" "State" "Rx Speed" "Tx Speed" "Total Rx / Tx"
    echo -e "  ${C_BORDER}$(ui_repeat "─" 76)${C_RESET}"

    for i in "${!NET_IFACES[@]}"; do
        local rx_sp
        rx_sp=$(format_speed "${NET_IFACE_RX_BPS[$i]}")
        local tx_sp
        tx_sp=$(format_speed "${NET_IFACE_TX_BPS[$i]}")
        local rx_tot
        rx_tot=$(format_bytes "${NET_IFACE_TOTAL_RX[$i]}")
        local tx_tot
        tx_tot=$(format_bytes "${NET_IFACE_TOTAL_TX[$i]}")
        local st_col="${C_GOOD}"
        if [[ "${NET_IFACE_STATUS[$i]}" != "UP" ]]; then st_col="${C_MUTED}"; fi

        printf "  %-12s ${st_col}%-8s${C_RESET} %-16s %-16s %s / %s\n" \
            "${NET_IFACES[$i]}" \
            "[${NET_IFACE_STATUS[$i]}]" \
            "$rx_sp" \
            "$tx_sp" \
            "$rx_tot" \
            "$tx_tot"
    done
    echo ""
}

# View 8: Battery & Power Supply
render_view_battery() {
    echo ""
    echo -e "  ${C_CARD_HEAD}┌─ [ POWER SUPPLY & BATTERY STATUS ]${C_RESET}"
    echo ""
    if [[ "$BATTERY_PRESENT" == "true" ]]; then
        echo -e "  ${C_BORDER}│${C_RESET}  ${C_MUTED}Battery State    :${C_RESET} ${C_BOLD}$BATTERY_STATUS${C_RESET} ($BATTERY_PERCENT%)"
        echo -e "  ${C_BORDER}│${C_RESET}  ${C_MUTED}Health Status    :${C_RESET} $BATTERY_HEALTH"
        echo -e "  ${C_BORDER}│${C_RESET}  ${C_MUTED}Technology       :${C_RESET} $BATTERY_TECH"
        echo -e "  ${C_BORDER}│${C_RESET}  ${C_MUTED}Power Draw       :${C_RESET} ${BATTERY_POWER_W} W"
    else
        echo -e "  ${C_BORDER}│${C_RESET}  ${C_MUTED}Power Source     :${C_RESET} ${C_TEXT}Desktop PC / AC Mains Power${C_RESET} ${C_DIM}($CPU_INFO_MODEL)${C_RESET}"
        echo -e "  ${C_BORDER}│${C_RESET}  ${C_MUTED}Battery State    :${C_RESET} ${C_MUTED}No battery installed (Standard Desktop workstation)${C_RESET}"
    fi
    echo ""
}

# View 9: Active Alerts Log
render_view_alerts() {
    echo ""
    echo -e "  ${C_CARD_HEAD}┌─ [ INFORMATIONAL THRESHOLD ALERTS ]${C_RESET}  ${C_DIM}(Strictly read-only monitoring)${C_RESET}"
    echo ""
    if [[ ${#ALERT_TIME[@]} -eq 0 ]]; then
        echo -e "  ${C_GOOD}● No active alerts. All monitored subsystems operating normally.${C_RESET}"
    else
        printf "  ${C_BOLD}%-10s %-10s %-10s %-8s %-10s %s${C_RESET}\n" "TIME" "LEVEL" "METRIC" "VALUE" "THRESH" "MESSAGE"
        echo -e "  ${C_BORDER}$(ui_repeat "─" 76)${C_RESET}"
        for i in "${!ALERT_TIME[@]}"; do
            local lvl_color="$C_WARN"
            if [[ "${ALERT_LEVEL[$i]}" == "CRITICAL" ]]; then lvl_color="$C_CRIT"; fi

            printf "  %-10s ${lvl_color}%-10s${C_RESET} %-10s %-8s %-10s %s\n" \
                "${ALERT_TIME[$i]}" \
                "[${ALERT_LEVEL[$i]}]" \
                "${ALERT_METRIC[$i]}" \
                "${ALERT_VALUE[$i]}" \
                "${ALERT_THRESHOLD[$i]}" \
                "${ALERT_MESSAGE[$i]}"
        done
    fi
    echo ""
}

# View 10: Settings & Diagnostics
render_view_settings() {
    echo ""
    echo -e "  ${C_CARD_HEAD}┌─ [ SMD-TUI 2.0 CONFIGURATION & EXPORT SETTINGS ]${C_RESET}"
    echo -e "  ${C_BORDER}│${C_RESET}  ${C_MUTED}Refresh Rate     :${C_RESET} ${C_TEXT}${C_BOLD}${CFG_REFRESH_INTERVAL} second(s)${C_RESET}"
    echo -e "  ${C_BORDER}│${C_RESET}  ${C_MUTED}Interface Theme  :${C_RESET} ${C_TEXT}${CFG_THEME}${C_RESET}"
    echo -e "  ${C_BORDER}│${C_RESET}  ${C_MUTED}Graph Rendering  :${C_RESET} ${C_TEXT}${CFG_GRAPH_STYLE}${C_RESET}"
    echo -e "  ${C_BORDER}│${C_RESET}  ${C_MUTED}History Buffer   :${C_RESET} ${C_TEXT}${CFG_HISTORY_RETENTION} data points${C_RESET}"
    echo -e "  ${C_BORDER}│${C_RESET}  ${C_MUTED}Alert Thresholds :${C_RESET} CPU: ${CFG_CPU_ALERT_THRESHOLD}% | RAM: ${CFG_MEM_ALERT_THRESHOLD}% | Temp: ${CFG_TEMP_ALERT_THRESHOLD}°C | Disk: ${CFG_DISK_ALERT_THRESHOLD}%"
    echo ""

    echo -e "  ${C_CARD_HEAD}┌─ [ ACTIVE FILE PATHS (XDG COMPLIANT) ]${C_RESET}"
    echo -e "  ${C_BORDER}│${C_RESET}  ${C_MUTED}Configuration    :${C_RESET} ${C_TEXT}${SMD_CONFIG_DIR}/config.conf${C_RESET}"
    echo -e "  ${C_BORDER}│${C_RESET}  ${C_MUTED}HTML Reports     :${C_RESET} ${C_PRIMARY}${SMD_REPORT_DIR}/*.html${C_RESET} & ./exports/"
    echo -e "  ${C_BORDER}│${C_RESET}  ${C_MUTED}CSV Metrics Logs :${C_RESET} ${C_TEXT}${SMD_EXPORT_DIR}/*.csv${C_RESET}"
    echo ""
    echo -e "  ${C_DIM}Export Tip: Press 'E' anytime to instantly generate a full HTML report of current system metrics.${C_RESET}"
    echo ""
}

# Render Help Screen Modal
dashboard_render_help() {
    local w="$BOX_WIDTH"
    echo ""
    echo -e "  ${C_CARD_HEAD}┌─ [ KEYBOARD SHORTCUTS & NAVIGATION ]${C_RESET}"
    echo -e "  ${C_BORDER}│${C_RESET}  ${C_PRIMARY}${C_BOLD}1 - 9, 0${C_RESET}     : Switch tabs (1:Overview, 2:CPU, 3:RAM ... 0:Settings)"
    echo -e "  ${C_BORDER}│${C_RESET}  ${C_PRIMARY}${C_BOLD}Tab${C_RESET}          : Cycle to next tab"
    echo -e "  ${C_BORDER}│${C_RESET}  ${C_PRIMARY}${C_BOLD}Left / Right${C_RESET} : Navigate to Previous / Next tab"
    echo -e "  ${C_BORDER}│${C_RESET}  ${C_PRIMARY}${C_BOLD}Up / Down${C_RESET}    : Scroll process tables & alert history (or j/k)"
    echo -e "  ${C_BORDER}│${C_RESET}  ${C_PRIMARY}${C_BOLD}P${C_RESET}            : Pause / Resume live data collection"
    echo -e "  ${C_BORDER}│${C_RESET}  ${C_PRIMARY}${C_BOLD}R${C_RESET}            : Force an immediate metric refresh"
    echo -e "  ${C_BORDER}│${C_RESET}  ${C_PRIMARY}${C_BOLD}E${C_RESET}            : Export live HTML report & CSV telemetry"
    echo -e "  ${C_BORDER}│${C_RESET}  ${C_PRIMARY}${C_BOLD}H or ?${C_RESET}       : Toggle this help overlay"
    echo -e "  ${C_BORDER}│${C_RESET}  ${C_PRIMARY}${C_BOLD}Q or Esc${C_RESET}     : Cleanly quit SMD-TUI and restore terminal"
    echo ""
}

# Render Bottom Footer
dashboard_render_footer() {
    local w="$BOX_WIDTH"
    local fill_bot=$(( w - 66 ))
    if [[ $fill_bot -lt 2 ]]; then fill_bot=2; fi

    echo -e "${C_BORDER}├$(ui_repeat "─" $(( w - 2 )))┤${C_RESET}"
    printf "${C_BORDER}│${C_RESET} ${C_MUTED}[1-9,0] Tabs  •  [Arrows] Nav  •  [P]ause  •  [R]efresh  •  ${C_PRIMARY}[E]xport HTML${C_RESET}  •  ${C_MUTED}[Q]uit${C_RESET}"

    local inner_w=$(( w - 4 ))
    local printed_len=68
    local pad_right=$(( inner_w - printed_len ))
    if [[ $pad_right -gt 0 ]]; then
        printf "%*s" "$pad_right" ""
    fi
    printf " ${C_BORDER}│${C_RESET}\n"

    echo -e "${C_BORDER}╰$(ui_repeat "─" $(( w - 2 )))╯${C_RESET}\033[J"
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
