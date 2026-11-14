#!/usr/bin/env bash
# collectors/memory.sh - Memory and Swap collector for SMD-TUI
# Strictly read-only access to /proc/meminfo

MEM_TOTAL_KB=0
MEM_FREE_KB=0
MEM_AVAIL_KB=0
MEM_USED_KB=0
MEM_USAGE_PERCENT=0

MEM_BUFFERS_KB=0
MEM_CACHED_KB=0
MEM_SRECLAIMABLE_KB=0
MEM_SHMEM_KB=0

MEM_SWAP_TOTAL_KB=0
MEM_SWAP_FREE_KB=0
MEM_SWAP_USED_KB=0
MEM_SWAP_PERCENT=0

MEM_STATUS="OK"

# Collect memory and swap statistics from /proc/meminfo
mem_collect() {
    local meminfo_file="${1:-/proc/meminfo}"

    if [[ ! -f "$meminfo_file" || ! -r "$meminfo_file" ]]; then
        MEM_TOTAL_KB=0
        MEM_FREE_KB=0
        MEM_AVAIL_KB=0
        MEM_USED_KB=0
        MEM_USAGE_PERCENT=0
        MEM_BUFFERS_KB=0
        MEM_CACHED_KB=0
        MEM_SWAP_TOTAL_KB=0
        MEM_SWAP_FREE_KB=0
        MEM_SWAP_USED_KB=0
        MEM_SWAP_PERCENT=0
        MEM_STATUS="UNAVAILABLE"
        return 0
    fi

    local total=0 free=0 avail=0 buffers=0 cached=0 sreclaimable=0 shmem=0
    local swaptotal=0 swapfree=0

    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" =~ ^MemTotal:[[:space:]]*([0-9]+) ]]; then
            total="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^MemFree:[[:space:]]*([0-9]+) ]]; then
            free="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^MemAvailable:[[:space:]]*([0-9]+) ]]; then
            avail="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^Buffers:[[:space:]]*([0-9]+) ]]; then
            buffers="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^Cached:[[:space:]]*([0-9]+) ]]; then
            cached="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^SReclaimable:[[:space:]]*([0-9]+) ]]; then
            sreclaimable="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^Shmem:[[:space:]]*([0-9]+) ]]; then
            shmem="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^SwapTotal:[[:space:]]*([0-9]+) ]]; then
            swaptotal="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^SwapFree:[[:space:]]*([0-9]+) ]]; then
            swapfree="${BASH_REMATCH[1]}"
        fi
    done < "$meminfo_file"

    MEM_TOTAL_KB="$total"
    MEM_FREE_KB="$free"
    MEM_BUFFERS_KB="$buffers"
    MEM_CACHED_KB="$cached"
    MEM_SRECLAIMABLE_KB="$sreclaimable"
    MEM_SHMEM_KB="$shmem"

    # In modern Linux 3.14+, MemAvailable is standard.
    # Fallback if MemAvailable was 0: free + buffers + cached
    if [[ $avail -le 0 && $total -gt 0 ]]; then
        avail=$(( free + buffers + cached ))
    fi
    MEM_AVAIL_KB="$avail"

    # Used RAM = MemTotal - MemAvailable
    if [[ $total -ge $avail ]]; then
        MEM_USED_KB=$(( total - avail ))
    else
        MEM_USED_KB=0
    fi

    # Percentage
    MEM_USAGE_PERCENT=$(calc_percent "$MEM_USED_KB" "$MEM_TOTAL_KB")

    # Swap metrics
    MEM_SWAP_TOTAL_KB="$swaptotal"
    MEM_SWAP_FREE_KB="$swapfree"
    if [[ $swaptotal -ge $swapfree ]]; then
        MEM_SWAP_USED_KB=$(( swaptotal - swapfree ))
    else
        MEM_SWAP_USED_KB=0
    fi
    MEM_SWAP_PERCENT=$(calc_percent "$MEM_SWAP_USED_KB" "$MEM_SWAP_TOTAL_KB")

    MEM_STATUS="OK"
}
