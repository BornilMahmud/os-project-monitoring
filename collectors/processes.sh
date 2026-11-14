#!/usr/bin/env bash
# collectors/processes.sh - Top CPU and Memory processes collector for SMD-TUI
# Strictly read-only access via standard 'ps' command. Never performs kill, signal, or modification.

declare -a PROC_CPU_PID=()
declare -a PROC_CPU_USER=()
declare -a PROC_CPU_PCT=()
declare -a PROC_CPU_MEM=()
declare -a PROC_CPU_COMM=()

declare -a PROC_MEM_PID=()
declare -a PROC_MEM_USER=()
declare -a PROC_MEM_PCT=()
declare -a PROC_MEM_MEM=()
declare -a PROC_MEM_COMM=()

# Parse process listing lines into target arrays
process_parse_file() {
    local file="$1"
    local mode="${2:-cpu}" # cpu or mem
    local limit="${3:-25}"

    if [[ "$mode" == "cpu" ]]; then
        PROC_CPU_PID=()
        PROC_CPU_USER=()
        PROC_CPU_PCT=()
        PROC_CPU_MEM=()
        PROC_CPU_COMM=()
    else
        PROC_MEM_PID=()
        PROC_MEM_USER=()
        PROC_MEM_PCT=()
        PROC_MEM_MEM=()
        PROC_MEM_COMM=()
    fi

    if [[ ! -r "$file" ]]; then
        return 0
    fi

    local header=1
    local count=0

    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ $header -eq 1 ]]; then
            header=0
            continue
        fi

        if [[ $count -ge $limit ]]; then
            break
        fi

        # Format: PID USER %CPU %MEM COMMAND (comm can have spaces or args)
        local parts=($line)
        if [[ ${#parts[@]} -ge 5 ]]; then
            local pid="${parts[0]}"
            local user="${parts[1]}"
            local cpu="${parts[2]}"
            local mem="${parts[3]}"
            # Command is parts[4..]
            local comm="${parts[*]:4}"

            if [[ "$mode" == "cpu" ]]; then
                PROC_CPU_PID+=("$pid")
                PROC_CPU_USER+=("$user")
                PROC_CPU_PCT+=("$cpu")
                PROC_CPU_MEM+=("$mem")
                PROC_CPU_COMM+=("$comm")
            else
                PROC_MEM_PID+=("$pid")
                PROC_MEM_USER+=("$user")
                PROC_MEM_PCT+=("$cpu")
                PROC_MEM_MEM+=("$mem")
                PROC_MEM_COMM+=("$comm")
            fi
            count=$((count + 1))
        fi
    done < "$file"
}

# Collect top CPU and top memory consuming processes directly via process substitution
process_collect() {
    local limit="${1:-25}"

    process_parse_file <(ps -eo pid,user,%cpu,%mem,comm --sort=-%cpu 2>/dev/null || true) "cpu" "$limit"
    process_parse_file <(ps -eo pid,user,%cpu,%mem,comm --sort=-%mem 2>/dev/null || true) "mem" "$limit"
}
