#!/usr/bin/env bash
# core/export.sh - Report and CSV metric export utilities for SMD-TUI
# Strictly writes to application-owned XDG directories or user-specified output files.

# Generate a formatted system intelligence text report
export_report_txt() {
    local target="${1:-}"

    if [[ -z "$target" ]]; then
        local ts
        ts="$(date +%Y%m%d_%H%M%S)"
        target="${SMD_REPORT_DIR}/report_${ts}.txt"
    fi

    # Ensure parent directory exists
    mkdir -p "$(dirname "$target")" 2>/dev/null || true

    # Gather fresh metrics
    system_collect
    cpu_collect
    mem_collect
    storage_collect
    network_collect
    thermal_collect
    battery_collect
    process_collect 10

    local gen_time
    gen_time="$(date +"%Y-%m-%d %H:%M:%S")"

    cat << EOF > "$target"
================================================================================
SMD-TUI 2.0 System Intelligence Report
Generated: $gen_time
================================================================================

[SYSTEM IDENTITY & ENVIRONMENT]
  Hostname        : $SYS_HOSTNAME
  Distro          : $SYS_DISTRO_PRETTY
  Kernel          : $SYS_KERNEL ($SYS_ARCH)
  Current User    : $SYS_CURRENT_USER
  Environment     : $SYS_VIRT_TYPE
  Linux Uptime    : $SYS_UPTIME_PRETTY
EOF

    if [[ "$SYS_IS_WSL" == "true" ]]; then
        cat << EOF >> "$target"
  Host OS         : Windows
  Host Uptime     : $SYS_HOST_UPTIME
  Host Total RAM  : $SYS_HOST_RAM_GB
EOF
    fi

    cat << EOF >> "$target"

[CPU METRICS]
  Model           : $CPU_INFO_MODEL
  Architecture    : ${CPU_INFO_PHYSICAL_CORES} Physical Cores, ${CPU_INFO_LOGICAL_CORES} Logical Threads
  Base Clock      : $CPU_INFO_MHZ MHz
  Overall Usage   : ${CPU_USAGE_TOTAL}%
  Load Averages   : $CPU_LOAD_1M (1m), $CPU_LOAD_5M (5m), $CPU_LOAD_15M (15m)
  Active Tasks    : $CPU_LOAD_RUNNABLE running / $CPU_LOAD_TOTAL_PROCS total

[MEMORY & SWAP]
  Total RAM       : $(format_bytes $(( MEM_TOTAL_KB * 1024 )))
  Used RAM        : $(format_bytes $(( MEM_USED_KB * 1024 ))) (${MEM_USAGE_PERCENT}%)
  Available RAM   : $(format_bytes $(( MEM_AVAIL_KB * 1024 )))
  Free RAM        : $(format_bytes $(( MEM_FREE_KB * 1024 )))
  Buffers/Cache   : $(format_bytes $(( (MEM_BUFFERS_KB + MEM_CACHED_KB) * 1024 )))
  Swap Total      : $(format_bytes $(( MEM_SWAP_TOTAL_KB * 1024 )))
  Swap Used       : $(format_bytes $(( MEM_SWAP_USED_KB * 1024 ))) (${MEM_SWAP_PERCENT}%)

[STORAGE & DISK I/O]
  Disk Read Rate  : $(format_speed "$STORAGE_TOTAL_READ_BPS")
  Disk Write Rate : $(format_speed "$STORAGE_TOTAL_WRITE_BPS")
  Mounted Filesystems:
EOF

    for i in "${!STORAGE_FS_MOUNT[@]}"; do
        local sz
        sz=$(format_bytes $(( ${STORAGE_FS_SIZE_KB[$i]} * 1024 )))
        local us
        us=$(format_bytes $(( ${STORAGE_FS_USED_KB[$i]} * 1024 )))
        printf "    %-18s %-12s %-12s %-8s %s\n" \
            "${STORAGE_FS_DEVICE[$i]}" "$sz" "$us" "${STORAGE_FS_PERCENT[$i]}%" "${STORAGE_FS_MOUNT[$i]}" >> "$target"
    done

    cat << EOF >> "$target"

[NETWORK INTERFACES & THROUGHPUT]
  Total Download  : $(format_speed "$NET_TOTAL_RX_BPS")
  Total Upload    : $(format_speed "$NET_TOTAL_TX_BPS")
EOF

    for i in "${!NET_IFACES[@]}"; do
        local rx_sp
        rx_sp=$(format_speed "${NET_IFACE_RX_BPS[$i]}")
        local tx_sp
        tx_sp=$(format_speed "${NET_IFACE_TX_BPS[$i]}")
        local rx_tot
        rx_tot=$(format_bytes "${NET_IFACE_TOTAL_RX[$i]}")
        local tx_tot
        tx_tot=$(format_bytes "${NET_IFACE_TOTAL_TX[$i]}")
        printf "    - %-10s [%s] Rx: %s | Tx: %s (Total: %s / %s)\n" \
            "${NET_IFACES[$i]}" "${NET_IFACE_STATUS[$i]}" "$rx_sp" "$tx_sp" "$rx_tot" "$tx_tot" >> "$target"
    done

    cat << EOF >> "$target"

[THERMAL SENSORS & POWER]
  Thermal Status  : $THERMAL_STATUS
  CPU Package     : ${THERMAL_CPU_TEMP}°C
  Battery State   : $BATTERY_STATUS ($BATTERY_PERCENT%)

[TOP 10 PROCESSES]
  PID     USER         %CPU     %MEM     COMMAND
  ----------------------------------------------------------------------
EOF

    for i in "${!PROC_CPU_PID[@]}"; do
        if [[ $i -lt 10 ]]; then
            printf "  %-7s %-12s %-8s %-8s %s\n" \
                "${PROC_CPU_PID[$i]}" "${PROC_CPU_USER[$i]}" "${PROC_CPU_PCT[$i]}%" "${PROC_CPU_MEM[$i]}%" "${PROC_CPU_COMM[$i]}" >> "$target"
        fi
    done

    cat << EOF >> "$target"

================================================================================
End of SMD-TUI 2.0 Report
================================================================================
EOF

    echo "$target"
}

# Export live metrics row to CSV file
export_metrics_csv() {
    local target="${1:-}"

    if [[ -z "$target" ]]; then
        local ts
        ts="$(date +%Y%m%d_%H%M%S)"
        target="${SMD_EXPORT_DIR}/metrics_${ts}.csv"
    fi

    # Ensure parent directory exists
    mkdir -p "$(dirname "$target")" 2>/dev/null || true

    # Write CSV header if file is new or empty
    if [[ ! -s "$target" ]]; then
        echo "Timestamp,CPU_Usage,RAM_Used_MB,RAM_Total_MB,RAM_Usage_Pct,Disk_Read_Bps,Disk_Write_Bps,Net_Rx_Bps,Net_Tx_Bps,CPU_Temp_C" > "$target"
    fi

    local ts
    ts="$(date +"%Y-%m-%d %H:%M:%S")"
    local ram_used_mb=$(( MEM_USED_KB / 1024 ))
    local ram_tot_mb=$(( MEM_TOTAL_KB / 1024 ))

    echo "${ts},${CPU_USAGE_TOTAL},${ram_used_mb},${ram_tot_mb},${MEM_USAGE_PERCENT},${STORAGE_TOTAL_READ_BPS},${STORAGE_TOTAL_WRITE_BPS},${NET_TOTAL_RX_BPS},${NET_TOTAL_TX_BPS},${THERMAL_CPU_TEMP}" >> "$target"

    echo "$target"
}
