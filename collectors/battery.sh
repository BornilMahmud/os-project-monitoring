#!/usr/bin/env bash
# collectors/battery.sh - Power supply, battery state and health collector for SMD-TUI
# Strictly read-only access to /sys/class/power_supply/

BATTERY_PRESENT="false"
BATTERY_PERCENT="N/A"
BATTERY_STATUS="Not Present / AC"
BATTERY_HEALTH="N/A"
BATTERY_TECH="N/A"
BATTERY_POWER_W="0.0"
BATTERY_NAME="None"

# Collect battery metrics from /sys/class/power_supply
battery_collect() {
    local sys_root="${1:-/sys}"

    BATTERY_PRESENT="false"
    BATTERY_PERCENT="N/A"
    BATTERY_STATUS="Not Present / AC"
    BATTERY_HEALTH="N/A"
    BATTERY_TECH="N/A"
    BATTERY_POWER_W="0.0"
    BATTERY_NAME="None"

    local ps_dir="$sys_root/class/power_supply"
    if [[ ! -d "$ps_dir" ]]; then
        return 0
    fi

    local bat_dirs=()
    while IFS= read -r -d '' bd; do
        bat_dirs+=("$bd")
    done < <(find "$ps_dir" -maxdepth 1 -name "BAT*" -o -name "battery*" -print0 2>/dev/null || true)

    # If no BAT* named dirs, scan all dirs in power_supply for type=Battery
    if [[ ${#bat_dirs[@]} -eq 0 ]]; then
        while IFS= read -r -d '' d; do
            if [[ -f "$d/type" && -r "$d/type" ]]; then
                local ptype
                ptype=$(cat "$d/type" 2>/dev/null || true)
                if [[ "$ptype" == "Battery" ]]; then
                    bat_dirs+=("$d")
                fi
            fi
        done < <(find "$ps_dir" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null || true)
    fi

    if [[ ${#bat_dirs[@]} -eq 0 ]]; then
        return 0
    fi

    local primary_bat="${bat_dirs[0]}"
    BATTERY_NAME="$(basename "$primary_bat")"
    BATTERY_PRESENT="true"

    if [[ -f "$primary_bat/capacity" && -r "$primary_bat/capacity" ]]; then
        local cap
        cap=$(cat "$primary_bat/capacity" 2>/dev/null || echo 0)
        if [[ "$cap" =~ ^[0-9]+$ ]]; then
            BATTERY_PERCENT="$cap"
        fi
    fi

    if [[ -f "$primary_bat/status" && -r "$primary_bat/status" ]]; then
        BATTERY_STATUS=$(cat "$primary_bat/status" 2>/dev/null || echo "Unknown")
    fi

    if [[ -f "$primary_bat/health" && -r "$primary_bat/health" ]]; then
        BATTERY_HEALTH=$(cat "$primary_bat/health" 2>/dev/null || echo "Good")
    fi

    if [[ -f "$primary_bat/technology" && -r "$primary_bat/technology" ]]; then
        BATTERY_TECH=$(cat "$primary_bat/technology" 2>/dev/null || echo "N/A")
    fi

    # Read power consumption if available (in micro-watts or micro-amperes)
    if [[ -f "$primary_bat/power_now" && -r "$primary_bat/power_now" ]]; then
        local p_now
        p_now=$(cat "$primary_bat/power_now" 2>/dev/null || echo 0)
        if [[ "$p_now" =~ ^[0-9]+$ ]] && [[ $p_now -gt 0 ]]; then
            local watts=$(( p_now / 1000000 ))
            local decimals=$(( (p_now % 1000000) / 10000 ))
            BATTERY_POWER_W=$(printf "%d.%02d" "$watts" "$decimals")
        fi
    fi
}
