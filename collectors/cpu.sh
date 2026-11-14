#!/usr/bin/env bash
# collectors/cpu.sh - CPU hardware and utilization collector for SMD-TUI
# Strictly read-only access to /proc/stat, /proc/loadavg, /proc/cpuinfo

# CPU Metrics state variables
CPU_INFO_MODEL="Unknown CPU"
CPU_INFO_CORES=1
CPU_INFO_MHZ="N/A"

CPU_LOAD_1M="0.00"
CPU_LOAD_5M="0.00"
CPU_LOAD_15M="0.00"
CPU_LOAD_RUNNABLE=0
CPU_LOAD_TOTAL_PROCS=0

CPU_USAGE_TOTAL=0
declare -a CPU_USAGE_CORES=()

# Internal previous tick counters
_PREV_TOTAL_ACTIVE=0
_PREV_TOTAL_TIME=0
declare -a _PREV_CORE_ACTIVE=()
declare -a _PREV_CORE_TIME=()

# Collect static CPU information (Model, Cores, Frequency)
cpu_collect_info() {
    local cpuinfo_file="${1:-/proc/cpuinfo}"

    if [[ ! -f "$cpuinfo_file" || ! -r "$cpuinfo_file" ]]; then
        CPU_INFO_MODEL="Unknown CPU"
        if command -v nproc >/dev/null 2>&1; then
            CPU_INFO_CORES=$(nproc 2>/dev/null || echo 1)
        else
            CPU_INFO_CORES=1
        fi
        return 0
    fi

    local model=""
    local mhz=""
    local cores=0

    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" =~ ^model[[:space:]]+name[[:space:]]*:[[:space:]]*(.*)$ ]]; then
            if [[ -z "$model" ]]; then
                model="${BASH_REMATCH[1]}"
            fi
        elif [[ "$line" =~ ^processor[[:space:]]*:[[:space:]]*[0-9]+ ]]; then
            cores=$((cores + 1))
        elif [[ "$line" =~ ^cpu[[:space:]]+MHz[[:space:]]*:[[:space:]]*([0-9]+) ]]; then
            if [[ -z "$mhz" ]]; then
                mhz="${BASH_REMATCH[1]}"
            fi
        fi
    done < "$cpuinfo_file"

    CPU_INFO_MODEL="${model:-Unknown CPU}"
    if [[ $cores -gt 0 ]]; then
        CPU_INFO_CORES="$cores"
    elif command -v nproc >/dev/null 2>&1; then
        CPU_INFO_CORES=$(nproc 2>/dev/null || echo 1)
    else
        CPU_INFO_CORES=1
    fi

    # Fallback for frequency if not in cpuinfo
    if [[ -z "$mhz" ]]; then
        local freq_file="/sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq"
        if [[ -f "$freq_file" && -r "$freq_file" ]]; then
            local raw_freq
            raw_freq=$(cat "$freq_file" 2>/dev/null || echo 0)
            if [[ $raw_freq -gt 0 ]]; then
                mhz=$(( raw_freq / 1000 ))
            fi
        fi
    fi

    CPU_INFO_MHZ="${mhz:-N/A}"
}

# Collect Load Average and runnable tasks
cpu_collect_load() {
    local loadavg_file="${1:-/proc/loadavg}"

    if [[ ! -f "$loadavg_file" || ! -r "$loadavg_file" ]]; then
        CPU_LOAD_1M="0.00"
        CPU_LOAD_5M="0.00"
        CPU_LOAD_15M="0.00"
        CPU_LOAD_RUNNABLE=0
        CPU_LOAD_TOTAL_PROCS=0
        return 0
    fi

    local l1 l5 l15 procs _
    read -r l1 l5 l15 procs _ < "$loadavg_file" || true

    CPU_LOAD_1M="${l1:-0.00}"
    CPU_LOAD_5M="${l5:-0.00}"
    CPU_LOAD_15M="${l15:-0.00}"

    if [[ "$procs" =~ ^([0-9]+)/([0-9]+)$ ]]; then
        CPU_LOAD_RUNNABLE="${BASH_REMATCH[1]}"
        CPU_LOAD_TOTAL_PROCS="${BASH_REMATCH[2]}"
    fi
}

# Collect CPU ticks and compute delta utilization
cpu_collect_stat() {
    local stat_file="${1:-/proc/stat}"

    if [[ ! -f "$stat_file" || ! -r "$stat_file" ]]; then
        CPU_USAGE_TOTAL=0
        return 0
    fi

    while IFS= read -r line || [[ -n "$line" ]]; do
        # Overall CPU line: cpu user nice system idle iowait irq softirq steal guest guest_nice
        if [[ "$line" =~ ^cpu[[:space:]]+([0-9]+)[[:space:]]+([0-9]+)[[:space:]]+([0-9]+)[[:space:]]+([0-9]+)[[:space:]]+([0-9]+)[[:space:]]+([0-9]+)[[:space:]]+([0-9]+)[[:space:]]+([0-9]+) ]]; then
            local u="${BASH_REMATCH[1]}"
            local n="${BASH_REMATCH[2]}"
            local s="${BASH_REMATCH[3]}"
            local idle="${BASH_REMATCH[4]}"
            local iowait="${BASH_REMATCH[5]}"
            local irq="${BASH_REMATCH[6]}"
            local softirq="${BASH_REMATCH[7]}"
            local steal="${BASH_REMATCH[8]}"

            local active=$(( u + n + s + irq + softirq + steal ))
            local total=$(( active + idle + iowait ))

            if [[ $_PREV_TOTAL_TIME -gt 0 ]]; then
                local d_active=$(( active - _PREV_TOTAL_ACTIVE ))
                local d_total=$(( total - _PREV_TOTAL_TIME ))
                if [[ $d_total -gt 0 ]]; then
                    CPU_USAGE_TOTAL=$(calc_percent "$d_active" "$d_total")
                fi
            fi

            _PREV_TOTAL_ACTIVE="$active"
            _PREV_TOTAL_TIME="$total"

        # Per core lines: cpu0, cpu1, ...
        elif [[ "$line" =~ ^cpu([0-9]+)[[:space:]]+([0-9]+)[[:space:]]+([0-9]+)[[:space:]]+([0-9]+)[[:space:]]+([0-9]+)[[:space:]]+([0-9]+)[[:space:]]+([0-9]+)[[:space:]]+([0-9]+)[[:space:]]+([0-9]+) ]]; then
            local core_idx="${BASH_REMATCH[1]}"
            local u="${BASH_REMATCH[2]}"
            local n="${BASH_REMATCH[3]}"
            local s="${BASH_REMATCH[4]}"
            local idle="${BASH_REMATCH[5]}"
            local iowait="${BASH_REMATCH[6]}"
            local irq="${BASH_REMATCH[7]}"
            local softirq="${BASH_REMATCH[8]}"
            local steal="${BASH_REMATCH[9]}"

            local active=$(( u + n + s + irq + softirq + steal ))
            local total=$(( active + idle + iowait ))

            local prev_act="${_PREV_CORE_ACTIVE[$core_idx]:-0}"
            local prev_tot="${_PREV_CORE_TIME[$core_idx]:-0}"

            if [[ $prev_tot -gt 0 ]]; then
                local d_active=$(( active - prev_act ))
                local d_total=$(( total - prev_tot ))
                if [[ $d_total -gt 0 ]]; then
                    CPU_USAGE_CORES["$core_idx"]=$(calc_percent "$d_active" "$d_total")
                fi
            else
                CPU_USAGE_CORES["$core_idx"]=0
            fi

            _PREV_CORE_ACTIVE["$core_idx"]="$active"
            _PREV_CORE_TIME["$core_idx"]="$total"
        fi
    done < "$stat_file"
}

# Main CPU collector function
cpu_collect() {
    cpu_collect_info
    cpu_collect_load
    cpu_collect_stat
}
