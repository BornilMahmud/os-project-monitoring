#!/usr/bin/env bash
# collectors/network.sh - Network interfaces and bandwidth speed collector for SMD-TUI
# Strictly read-only access to /proc/net/dev and /sys/class/net

NET_TOTAL_RX_BPS=0
NET_TOTAL_TX_BPS=0
NET_STATUS="OK"

declare -a NET_IFACES=()
declare -a NET_IFACE_STATUS=()
declare -a NET_IFACE_RX_BPS=()
declare -a NET_IFACE_TX_BPS=()
declare -a NET_IFACE_TOTAL_RX=()
declare -a NET_IFACE_TOTAL_TX=()

# Internal previous network byte counters
declare -g -A _PREV_NET_RX=()
declare -g -A _PREV_NET_TX=()
_PREV_NET_TIME=0

# Collect network interface counters and throughput rates
network_collect_dev() {
    local netdev_file="${1:-/proc/net/dev}"
    local cur_time="${2:-$(date +%s)}"

    if [[ ! -f "$netdev_file" || ! -r "$netdev_file" ]]; then
        NET_TOTAL_RX_BPS=0
        NET_TOTAL_TX_BPS=0
        NET_STATUS="UNAVAILABLE"
        return 0
    fi

    NET_STATUS="OK"
    local total_rx_bps=0
    local total_tx_bps=0

    NET_IFACES=()
    NET_IFACE_STATUS=()
    NET_IFACE_RX_BPS=()
    NET_IFACE_TX_BPS=()
    NET_IFACE_TOTAL_RX=()
    NET_IFACE_TOTAL_TX=()

    local elapsed=0
    if [[ $_PREV_NET_TIME -gt 0 ]]; then
        elapsed=$(( cur_time - _PREV_NET_TIME ))
    fi

    while IFS= read -r line || [[ -n "$line" ]]; do
        # Ignore header lines
        if [[ "$line" =~ ^[[:space:]]*Inter- || "$line" =~ ^[[:space:]]*face ]]; then
            continue
        fi

        # Interface line has a colon
        if [[ "$line" =~ : ]]; then
            local clean_line="${line/:/: }"
            local parts=($clean_line)
            if [[ ${#parts[@]} -ge 10 ]]; then
                local iface="${parts[0]%:}"
                local rx_bytes="${parts[1]}"
                local tx_bytes="${parts[9]}"

                local iface_upper="${iface^^}"
                iface_upper="${iface_upper//[^A-Z0-9_]/_}"

                local rx_speed=0
                local tx_speed=0

                if [[ $elapsed -gt 0 ]]; then
                    local prev_rx="${_PREV_NET_RX[$iface]:-0}"
                    local prev_tx="${_PREV_NET_TX[$iface]:-0}"

                    local d_rx=$(( rx_bytes - prev_rx ))
                    local d_tx=$(( tx_bytes - prev_tx ))

                    if [[ $d_rx -lt 0 ]]; then d_rx=0; fi
                    if [[ $d_tx -lt 0 ]]; then d_tx=0; fi

                    rx_speed=$(calc_rate "$d_rx" "$elapsed")
                    tx_speed=$(calc_rate "$d_tx" "$elapsed")
                fi

                _PREV_NET_RX["$iface"]="$rx_bytes"
                _PREV_NET_TX["$iface"]="$tx_bytes"

                # Check interface operstate if sysfs exists
                local state="UNKNOWN"
                local state_file="/sys/class/net/$iface/operstate"
                if [[ -f "$state_file" && -r "$state_file" ]]; then
                    state=$(cat "$state_file" 2>/dev/null || echo "UNKNOWN")
                    state=$(echo "$state" | tr '[:lower:]' '[:upper:]')
                elif [[ "$iface" == "lo" ]]; then
                    state="UP"
                fi

                # Export interface specific variables (e.g. NET_ETH0_RX_BPS)
                printf -v "NET_${iface_upper}_RX_BPS" "%d" "$rx_speed"
                printf -v "NET_${iface_upper}_TX_BPS" "%d" "$tx_speed"

                # Populate arrays
                NET_IFACES+=("$iface")
                NET_IFACE_STATUS+=("$state")
                NET_IFACE_RX_BPS+=("$rx_speed")
                NET_IFACE_TX_BPS+=("$tx_speed")
                NET_IFACE_TOTAL_RX+=("$rx_bytes")
                NET_IFACE_TOTAL_TX+=("$tx_bytes")

                # Exclude loopback from total interface speed
                if [[ "$iface" != "lo" ]]; then
                    total_rx_bps=$(( total_rx_bps + rx_speed ))
                    total_tx_bps=$(( total_tx_bps + tx_speed ))
                fi
            fi
        fi
    done < "$netdev_file"

    NET_TOTAL_RX_BPS="$total_rx_bps"
    NET_TOTAL_TX_BPS="$total_tx_bps"
    _PREV_NET_TIME="$cur_time"
}

network_collect() {
    network_collect_dev "/proc/net/dev" "$(date +%s)"
}
