#!/usr/bin/env bash
# collectors/thermals.sh - Hardware thermal zones, temperatures, and fan speeds collector
# Strictly read-only access to /sys/class/thermal, /sys/class/hwmon, and optional sensors command

THERMAL_STATUS="UNAVAILABLE"
THERMAL_COUNT=0
THERMAL_CPU_TEMP="N/A"

declare -a THERMAL_NAMES=()
declare -a THERMAL_TEMPS=()

THERMAL_FAN_COUNT=0
declare -a THERMAL_FAN_NAMES=()
declare -a THERMAL_FAN_RPM=()

# Collect thermal sensors and fans
thermal_collect() {
    local sys_root="${1:-/sys}"

    THERMAL_NAMES=()
    THERMAL_TEMPS=()
    THERMAL_FAN_NAMES=()
    THERMAL_FAN_RPM=()
    THERMAL_CPU_TEMP="N/A"
    THERMAL_COUNT=0
    THERMAL_FAN_COUNT=0
    THERMAL_STATUS="UNAVAILABLE"

    local max_cpu_temp=0
    local found_cpu_temp=0

    # 1. Scan /sys/class/thermal/thermal_zone*
    local tz_dirs=()
    if [[ -d "$sys_root/class/thermal" ]]; then
        while IFS= read -r -d '' d; do
            tz_dirs+=("$d")
        done < <(find "$sys_root/class/thermal" -maxdepth 1 -name "thermal_zone*" -print0 2>/dev/null || true)
    fi

    for tz in "${tz_dirs[@]}"; do
        if [[ -f "$tz/temp" && -r "$tz/temp" ]]; then
            local raw_temp
            raw_temp=$(cat "$tz/temp" 2>/dev/null || echo 0)
            if [[ "$raw_temp" =~ ^[0-9]+$ ]] && [[ $raw_temp -gt 0 ]]; then
                local temp_c=$(( raw_temp / 1000 ))
                local type_name="thermal_zone"
                if [[ -f "$tz/type" && -r "$tz/type" ]]; then
                    type_name=$(head -n 1 "$tz/type" 2>/dev/null || echo "thermal_zone")
                fi

                THERMAL_NAMES+=("$type_name")
                THERMAL_TEMPS+=("$temp_c")

                # Detect CPU temperature candidate
                if [[ "$type_name" =~ (cpu|pkg|core|x86) ]]; then
                    if [[ $temp_c -gt $max_cpu_temp ]]; then
                        max_cpu_temp="$temp_c"
                        found_cpu_temp=1
                    fi
                elif [[ $found_cpu_temp -eq 0 && $temp_c -gt $max_cpu_temp ]]; then
                    max_cpu_temp="$temp_c"
                fi
            fi
        fi
    done

    # 2. Scan /sys/class/hwmon/hwmon*
    local hwmon_dirs=()
    if [[ -d "$sys_root/class/hwmon" ]]; then
        while IFS= read -r -d '' d; do
            hwmon_dirs+=("$d")
        done < <(find "$sys_root/class/hwmon" -maxdepth 1 -name "hwmon*" -print0 2>/dev/null || true)
    fi

    for hw in "${hwmon_dirs[@]}"; do
        local hw_name="hwmon"
        if [[ -f "$hw/name" && -r "$hw/name" ]]; then
            hw_name=$(head -n 1 "$hw/name" 2>/dev/null || echo "hwmon")
        fi

        # Find temperature inputs
        local temp_inputs=()
        while IFS= read -r -d '' ti; do
            temp_inputs+=("$ti")
        done < <(find "$hw" -maxdepth 1 -name "temp*_input" -print0 2>/dev/null || true)

        for ti in "${temp_inputs[@]}"; do
            local raw_temp
            raw_temp=$(cat "$ti" 2>/dev/null || echo 0)
            if [[ "$raw_temp" =~ ^[0-9]+$ ]] && [[ $raw_temp -gt 0 ]]; then
                local temp_c=$(( raw_temp / 1000 ))
                local base="${ti%_input}"
                local label_file="${base}_label"
                local label="$hw_name"
                if [[ -f "$label_file" && -r "$label_file" ]]; then
                    local custom_label
                    custom_label=$(head -n 1 "$label_file" 2>/dev/null || true)
                    if [[ -n "$custom_label" ]]; then
                        label="${hw_name} - ${custom_label}"
                    fi
                fi

                THERMAL_NAMES+=("$label")
                THERMAL_TEMPS+=("$temp_c")

                if [[ "$label" =~ (Package|Core|CPU|x86) ]]; then
                    if [[ $temp_c -gt $max_cpu_temp ]]; then
                        max_cpu_temp="$temp_c"
                        found_cpu_temp=1
                    fi
                elif [[ $found_cpu_temp -eq 0 && $temp_c -gt $max_cpu_temp ]]; then
                    max_cpu_temp="$temp_c"
                fi
            fi
        done

        # Find fan inputs
        local fan_inputs=()
        while IFS= read -r -d '' fi_path; do
            fan_inputs+=("$fi_path")
        done < <(find "$hw" -maxdepth 1 -name "fan*_input" -print0 2>/dev/null || true)

        for fi_path in "${fan_inputs[@]}"; do
            local raw_rpm
            raw_rpm=$(cat "$fi_path" 2>/dev/null || echo 0)
            if [[ "$raw_rpm" =~ ^[0-9]+$ ]]; then
                local base="${fi_path%_input}"
                local label_file="${base}_label"
                local fan_label="${hw_name} Fan"
                if [[ -f "$label_file" && -r "$label_file" ]]; then
                    local custom_label
                    custom_label=$(head -n 1 "$label_file" 2>/dev/null || true)
                    if [[ -n "$custom_label" ]]; then
                        fan_label="${hw_name} - ${custom_label}"
                    fi
                fi

                THERMAL_FAN_NAMES+=("$fan_label")
                THERMAL_FAN_RPM+=("$raw_rpm")
            fi
        done
    done

    THERMAL_COUNT="${#THERMAL_NAMES[@]}"
    THERMAL_FAN_COUNT="${#THERMAL_FAN_NAMES[@]}"

    if [[ $THERMAL_COUNT -gt 0 ]]; then
        THERMAL_STATUS="OK"
        if [[ $max_cpu_temp -gt 0 ]]; then
            THERMAL_CPU_TEMP="$max_cpu_temp"
        elif [[ $THERMAL_COUNT -gt 0 ]]; then
            THERMAL_CPU_TEMP="${THERMAL_TEMPS[0]}"
        fi
    fi
}
