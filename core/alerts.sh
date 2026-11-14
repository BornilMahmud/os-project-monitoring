#!/usr/bin/env bash
# core/alerts.sh - Real-time informational threshold alerts evaluator for SMD-TUI
# Strictly informational. Never performs corrective actions or modifies system settings.

ALERTS_ACTIVE_COUNT=0
declare -a ALERT_TIME=()
declare -a ALERT_METRIC=()
declare -a ALERT_LEVEL=()
declare -a ALERT_VALUE=()
declare -a ALERT_THRESHOLD=()
declare -a ALERT_MESSAGE=()

# Maximum alert history items stored
MAX_ALERT_HISTORY=50

alerts_init() {
    ALERTS_ACTIVE_COUNT=0
    ALERT_TIME=()
    ALERT_METRIC=()
    ALERT_LEVEL=()
    ALERT_VALUE=()
    ALERT_THRESHOLD=()
    ALERT_MESSAGE=()
}

_add_alert() {
    local metric="$1"
    local level="$2"
    local val="$3"
    local thresh="$4"
    local msg="$5"
    local now
    now="$(date +%H:%M:%S 2>/dev/null || echo "00:00:00")"

    ALERT_TIME+=("$now")
    ALERT_METRIC+=("$metric")
    ALERT_LEVEL+=("$level")
    ALERT_VALUE+=("$val")
    ALERT_THRESHOLD+=("$thresh")
    ALERT_MESSAGE+=("$msg")

    ALERTS_ACTIVE_COUNT=$(( ALERTS_ACTIVE_COUNT + 1 ))

    if [[ ${#ALERT_TIME[@]} -gt $MAX_ALERT_HISTORY ]]; then
        ALERT_TIME=("${ALERT_TIME[@]:1}")
        ALERT_METRIC=("${ALERT_METRIC[@]:1}")
        ALERT_LEVEL=("${ALERT_LEVEL[@]:1}")
        ALERT_VALUE=("${ALERT_VALUE[@]:1}")
        ALERT_THRESHOLD=("${ALERT_THRESHOLD[@]:1}")
        ALERT_MESSAGE=("${ALERT_MESSAGE[@]:1}")
    fi
}

# Evaluate metrics against configured thresholds
alerts_evaluate() {
    local cpu="${1:-0}"
    local mem="${2:-0}"
    local temp="${3:-N/A}"
    local disk="${4:-0}"

    if [[ "${CFG_ENABLE_ALERTS:-true}" != "true" ]]; then
        return 0
    fi

    ALERTS_ACTIVE_COUNT=0

    # CPU Alert
    if [[ "$cpu" =~ ^[0-9]+$ ]]; then
        local cpu_thresh="${CFG_CPU_ALERT_THRESHOLD:-85}"
        if [[ $cpu -ge 95 ]]; then
            _add_alert "CPU" "CRITICAL" "${cpu}%" "${cpu_thresh}%" "Severe CPU saturation"
        elif [[ $cpu -ge $cpu_thresh ]]; then
            _add_alert "CPU" "WARNING" "${cpu}%" "${cpu_thresh}%" "High CPU utilization"
        fi
    fi

    # Memory Alert
    if [[ "$mem" =~ ^[0-9]+$ ]]; then
        local mem_thresh="${CFG_MEM_ALERT_THRESHOLD:-90}"
        if [[ $mem -ge 98 ]]; then
            _add_alert "MEM" "CRITICAL" "${mem}%" "${mem_thresh}%" "Critical low memory"
        elif [[ $mem -ge $mem_thresh ]]; then
            _add_alert "MEM" "WARNING" "${mem}%" "${mem_thresh}%" "High memory consumption"
        fi
    fi

    # Temperature Alert
    if [[ "$temp" =~ ^[0-9]+$ ]]; then
        local temp_thresh="${CFG_TEMP_ALERT_THRESHOLD:-80}"
        if [[ $temp -ge 95 ]]; then
            _add_alert "TEMP" "CRITICAL" "${temp}°C" "${temp_thresh}°C" "Critical thermal limit reached"
        elif [[ $temp -ge $temp_thresh ]]; then
            _add_alert "TEMP" "WARNING" "${temp}°C" "${temp_thresh}°C" "High thermal sensor reading"
        fi
    fi

    # Disk Storage Alert
    if [[ "$disk" =~ ^[0-9]+$ ]]; then
        local disk_thresh="${CFG_DISK_ALERT_THRESHOLD:-90}"
        if [[ $disk -ge 95 ]]; then
            _add_alert "DISK" "CRITICAL" "${disk}%" "${disk_thresh}%" "Filesystem almost full"
        elif [[ $disk -ge $disk_thresh ]]; then
            _add_alert "DISK" "WARNING" "${disk}%" "${disk_thresh}%" "High storage utilization"
        fi
    fi
}
