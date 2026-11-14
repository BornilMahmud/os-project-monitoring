#!/usr/bin/env bash
# scripts/demo_collectors.sh - Live Hardware Collector Preview for SMD-TUI 2.0
# Strictly read-only preview of collected system metrics

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source all foundation and collector modules
source "$PROJECT_ROOT/core/calculations.sh"
source "$PROJECT_ROOT/config/loader.sh"
source "$PROJECT_ROOT/collectors/cpu.sh"
source "$PROJECT_ROOT/collectors/memory.sh"
source "$PROJECT_ROOT/collectors/storage.sh"
source "$PROJECT_ROOT/collectors/network.sh"
source "$PROJECT_ROOT/collectors/system.sh"
source "$PROJECT_ROOT/collectors/thermals.sh"
source "$PROJECT_ROOT/collectors/battery.sh"
source "$PROJECT_ROOT/collectors/processes.sh"

# ANSI Colors
BOLD='\033[1m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'

clear || true
echo -e "${CYAN}${BOLD}======================================================================${NC}"
echo -e "${CYAN}${BOLD}       SMD-TUI 2.0 - Live Hardware Intelligence Preview               ${NC}"
echo -e "${CYAN}${BOLD}======================================================================${NC}"

# 1. System Identity
system_collect
echo -e "\n${BLUE}${BOLD}[1] SYSTEM IDENTITY${NC}"
echo -e "  Distro       : ${GREEN}$SYS_DISTRO_PRETTY${NC}"
echo -e "  Kernel       : $SYS_KERNEL ($SYS_ARCH)"
echo -e "  Hostname     : $SYS_HOSTNAME"
echo -e "  Current User : $SYS_CURRENT_USER"
echo -e "  Uptime       : $SYS_UPTIME_PRETTY"

# 2. CPU Collection
echo -e "\n${BLUE}${BOLD}[2] CPU METRICS${NC} (Sampling 1-second delta...)"
cpu_collect
sleep 1
cpu_collect

echo -e "  Model        : $CPU_INFO_MODEL"
echo -e "  Cores        : $CPU_INFO_CORES physical/logical"
echo -e "  Frequency    : $CPU_INFO_MHZ MHz"
echo -e "  Load Average : $CPU_LOAD_1M (1m), $CPU_LOAD_5M (5m), $CPU_LOAD_15M (15m)"
echo -e "  Active Tasks : $CPU_LOAD_RUNNABLE running / $CPU_LOAD_TOTAL_PROCS total"
echo -e "  Overall Usage: ${YELLOW}${CPU_USAGE_TOTAL}%${NC}"
if [[ ${#CPU_USAGE_CORES[@]} -gt 0 ]]; then
    echo -n "  Per-Core     : "
    for i in "${!CPU_USAGE_CORES[@]}"; do
        echo -n "Core$i: ${CPU_USAGE_CORES[$i]}%  "
        if [[ $(( (i + 1) % 4 )) -eq 0 && $(( i + 1 )) -lt ${#CPU_USAGE_CORES[@]} ]]; then
            echo -e "\n                 "
        fi
    done
    echo ""
fi

# 3. Memory & Swap
mem_collect
echo -e "\n${BLUE}${BOLD}[3] MEMORY & SWAP${NC}"
echo -e "  Total RAM    : $(format_bytes $(( MEM_TOTAL_KB * 1024 )))"
echo -e "  Used RAM     : ${YELLOW}$(format_bytes $(( MEM_USED_KB * 1024 ))) (${MEM_USAGE_PERCENT}%)${NC}"
echo -e "  Available    : $(format_bytes $(( MEM_AVAIL_KB * 1024 )))"
echo -e "  Free RAM     : $(format_bytes $(( MEM_FREE_KB * 1024 )))"
echo -e "  Buffers/Cache: $(format_bytes $(( (MEM_BUFFERS_KB + MEM_CACHED_KB) * 1024 )))"
if [[ $MEM_SWAP_TOTAL_KB -gt 0 ]]; then
    echo -e "  Swap Usage   : $(format_bytes $(( MEM_SWAP_USED_KB * 1024 ))) / $(format_bytes $(( MEM_SWAP_TOTAL_KB * 1024 ))) (${MEM_SWAP_PERCENT}%)"
else
    echo -e "  Swap Usage   : Disabled / None"
fi

# 4. Storage & Disk I/O
storage_collect
echo -e "\n${BLUE}${BOLD}[4] STORAGE & DISK I/O${NC}"
echo -e "  Disk Read I/O : $(format_speed "$STORAGE_TOTAL_READ_BPS")"
echo -e "  Disk Write I/O: $(format_speed "$STORAGE_TOTAL_WRITE_BPS")"
echo -e "  Mounted Filesystems:"
printf "    %-20s %-12s %-12s %-8s %s\n" "Device" "Size" "Used" "Usage" "Mount"
for i in "${!STORAGE_FS_MOUNT[@]}"; do
    if [[ $i -lt 5 ]]; then
        local_size=$(format_bytes $(( ${STORAGE_FS_SIZE_KB[$i]} * 1024 )))
        local_used=$(format_bytes $(( ${STORAGE_FS_USED_KB[$i]} * 1024 )))
        printf "    %-20s %-12s %-12s %-8s %s\n" \
            "${STORAGE_FS_DEVICE[$i]}" \
            "$local_size" \
            "$local_used" \
            "${STORAGE_FS_PERCENT[$i]}%" \
            "${STORAGE_FS_MOUNT[$i]}"
    fi
done

# 5. Network Interfaces & Bandwidth
network_collect
echo -e "\n${BLUE}${BOLD}[5] NETWORK TELEMETRY${NC}"
echo -e "  Download Speed: $(format_speed "$NET_TOTAL_RX_BPS")"
echo -e "  Upload Speed  : $(format_speed "$NET_TOTAL_TX_BPS")"
echo -e "  Active Interfaces:"
for i in "${!NET_IFACES[@]}"; do
    echo -e "    - ${NET_IFACES[$i]} [${NET_IFACE_STATUS[$i]}]: RX $(format_bytes "${NET_IFACE_TOTAL_RX[$i]}") | TX $(format_bytes "${NET_IFACE_TOTAL_TX[$i]}")"
done

# 6. Thermals & Fans
thermal_collect
echo -e "\n${BLUE}${BOLD}[6] THERMAL SENSORS & FANS${NC}"
if [[ "$THERMAL_STATUS" == "OK" ]]; then
    echo -e "  CPU Package Temp: ${YELLOW}${THERMAL_CPU_TEMP}°C${NC}"
    for i in "${!THERMAL_NAMES[@]}"; do
        echo -e "    - ${THERMAL_NAMES[$i]}: ${THERMAL_TEMPS[$i]}°C"
    done
    if [[ $THERMAL_FAN_COUNT -gt 0 ]]; then
        echo -e "  Cooling Fans:"
        for i in "${!THERMAL_FAN_NAMES[@]}"; do
            echo -e "    - ${THERMAL_FAN_NAMES[$i]}: ${THERMAL_FAN_RPM[$i]} RPM"
        done
    fi
else
    echo -e "  Status: ${YELLOW}N/A (Virtual / Virtualized environment or hardware sensors restricted)${NC}"
fi

# 7. Battery & Power
battery_collect
echo -e "\n${BLUE}${BOLD}[7] BATTERY & POWER SUPPLY${NC}"
if [[ "$BATTERY_PRESENT" == "true" ]]; then
    echo -e "  Status : $BATTERY_STATUS ($BATTERY_PERCENT%)"
    echo -e "  Health : $BATTERY_HEALTH"
    echo -e "  Tech   : $BATTERY_TECH"
else
    echo -e "  Status : ${YELLOW}$BATTERY_STATUS (No battery detected / Desktop / AC power)${NC}"
fi

# 8. Top Processes
process_collect 5
echo -e "\n${BLUE}${BOLD}[8] TOP PROCESSES${NC}"
echo -e "  Top CPU Processes:"
printf "    %-8s %-12s %-8s %-8s %s\n" "PID" "USER" "%CPU" "%MEM" "COMMAND"
for i in "${!PROC_CPU_PID[@]}"; do
    if [[ $i -lt 5 ]]; then
        printf "    %-8s %-12s %-8s %-8s %s\n" \
            "${PROC_CPU_PID[$i]}" \
            "${PROC_CPU_USER[$i]}" \
            "${PROC_CPU_PCT[$i]}%" \
            "${PROC_CPU_MEM[$i]}%" \
            "${PROC_CPU_COMM[$i]}"
    fi
done

echo -e "\n${CYAN}======================================================================${NC}"
echo -e "${GREEN}${BOLD}✓ Live hardware data collection verified successfully!${NC}"
echo -e "${CYAN}======================================================================${NC}"
