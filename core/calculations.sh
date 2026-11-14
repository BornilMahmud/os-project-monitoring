#!/usr/bin/env bash
# core/calculations.sh - Pure Bash mathematical and formatting utilities for SMD-TUI

# Calculate integer percentage: (part * 100) / total
# Returns 0 if total <= 0
calc_percent() {
    local part="${1:-0}"
    local total="${2:-0}"

    if [[ -z "$total" || "$total" -le 0 ]]; then
        echo 0
        return 0
    fi

    if [[ -z "$part" || "$part" -le 0 ]]; then
        echo 0
        return 0
    fi

    local percent=$(( (part * 100) / total ))
    if [[ $percent -gt 100 ]]; then
        percent=100
    fi
    echo "$percent"
}

# Calculate rate per second: delta / elapsed_seconds
# Returns 0 if elapsed_seconds <= 0
calc_rate() {
    local delta="${1:-0}"
    local elapsed="${2:-0}"

    if [[ -z "$elapsed" || "$elapsed" -le 0 ]]; then
        echo 0
        return 0
    fi

    if [[ -z "$delta" || "$delta" -le 0 ]]; then
        echo 0
        return 0
    fi

    echo $(( delta / elapsed ))
}

# Calculate delta between two counters, handling possible reset or overflow
calc_delta() {
    local cur="${1:-0}"
    local prev="${2:-0}"

    if [[ -z "$cur" || "$cur" -lt 0 ]]; then cur=0; fi
    if [[ -z "$prev" || "$prev" -lt 0 ]]; then prev=0; fi

    if [[ "$cur" -lt "$prev" ]]; then
        echo 0
    else
        echo $(( cur - prev ))
    fi
}

# Restrict an integer value within [min, max]
clamp() {
    local val="${1:-0}"
    local min="${2:-0}"
    local max="${3:-100}"

    if [[ "$val" -lt "$min" ]]; then
        echo "$min"
    elif [[ "$val" -gt "$max" ]]; then
        echo "$max"
    else
        echo "$val"
    fi
}

# Format byte count into human-readable string (B, KB, MB, GB, TB) with 2 decimals
format_bytes() {
    local bytes="${1:-0}"

    # Handle negative or zero
    if [[ -z "$bytes" || "$bytes" -le 0 ]]; then
        echo "0 B"
        return 0
    fi

    local kb=1024
    local mb=$(( 1024 * 1024 ))
    local gb=$(( 1024 * 1024 * 1024 ))
    local tb=$(( 1024 * 1024 * 1024 * 1024 ))

    if [[ "$bytes" -lt "$kb" ]]; then
        echo "${bytes} B"
    elif [[ "$bytes" -lt "$mb" ]]; then
        local int=$(( bytes / kb ))
        local rem=$(( ((bytes % kb) * 100) / kb ))
        printf "%d.%02d KB\n" "$int" "$rem"
    elif [[ "$bytes" -lt "$gb" ]]; then
        local int=$(( bytes / mb ))
        local rem=$(( ((bytes % mb) * 100) / mb ))
        printf "%d.%02d MB\n" "$int" "$rem"
    elif [[ "$bytes" -lt "$tb" ]]; then
        local int=$(( bytes / gb ))
        local rem=$(( ((bytes % gb) * 100) / gb ))
        printf "%d.%02d GB\n" "$int" "$rem"
    else
        local int=$(( bytes / tb ))
        local rem=$(( ((bytes % tb) * 100) / tb ))
        printf "%d.%02d TB\n" "$int" "$rem"
    fi
}

# Format transfer speed (bytes per second)
format_speed() {
    local bps="${1:-0}"
    local formatted
    formatted=$(format_bytes "$bps")
    echo "${formatted}/s"
}

# Format duration in seconds into human-readable time (e.g. 1d 04h 32m 10s)
format_duration() {
    local total_sec="${1:-0}"

    if [[ -z "$total_sec" || "$total_sec" -le 0 ]]; then
        echo "0s"
        return 0
    fi

    local d=$(( total_sec / 86400 ))
    local h=$(( (total_sec % 86400) / 3600 ))
    local m=$(( (total_sec % 3600) / 60 ))
    local s=$(( total_sec % 60 ))

    local out=""
    if [[ $d -gt 0 ]]; then
        out="${d}d "
    fi

    if [[ $d -gt 0 || $h -gt 0 ]]; then
        if [[ $d -gt 0 ]]; then
            out="${out}$(printf "%02dh " "$h")"
        else
            out="${out}${h}h "
        fi
    fi

    if [[ $d -gt 0 || $h -gt 0 || $m -gt 0 ]]; then
        if [[ $d -gt 0 || $h -gt 0 ]]; then
            out="${out}$(printf "%02dm " "$m")"
        else
            out="${out}${m}m "
        fi
    fi

    if [[ $d -gt 0 || $h -gt 0 || $m -gt 0 ]]; then
        out="${out}$(printf "%02ds" "$s")"
    else
        out="${s}s"
    fi

    echo "$out"
}
