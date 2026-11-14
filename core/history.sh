#!/usr/bin/env bash
# core/history.sh - In-memory historical ring buffers for live monitoring graphs

HIST_RETENTION=60

declare -a HIST_CPU=()
declare -a HIST_MEM=()
declare -a HIST_TEMP=()
declare -a HIST_NET_RX=()
declare -a HIST_NET_TX=()
declare -a HIST_DISK_R=()
declare -a HIST_DISK_W=()

# Initialize ring buffer retention
history_init() {
    HIST_RETENTION="${1:-60}"
    HIST_CPU=()
    HIST_MEM=()
    HIST_TEMP=()
    HIST_NET_RX=()
    HIST_NET_TX=()
    HIST_DISK_R=()
    HIST_DISK_W=()
}

# Push a new value into the specified metric's ring buffer
history_push() {
    local metric="$1"
    local val="${2:-0}"

    case "$metric" in
        cpu)
            HIST_CPU+=("$val")
            if [[ ${#HIST_CPU[@]} -gt $HIST_RETENTION ]]; then
                HIST_CPU=("${HIST_CPU[@]:1}")
            fi
            ;;
        mem)
            HIST_MEM+=("$val")
            if [[ ${#HIST_MEM[@]} -gt $HIST_RETENTION ]]; then
                HIST_MEM=("${HIST_MEM[@]:1}")
            fi
            ;;
        temp)
            HIST_TEMP+=("$val")
            if [[ ${#HIST_TEMP[@]} -gt $HIST_RETENTION ]]; then
                HIST_TEMP=("${HIST_TEMP[@]:1}")
            fi
            ;;
        net_rx)
            HIST_NET_RX+=("$val")
            if [[ ${#HIST_NET_RX[@]} -gt $HIST_RETENTION ]]; then
                HIST_NET_RX=("${HIST_NET_RX[@]:1}")
            fi
            ;;
        net_tx)
            HIST_NET_TX+=("$val")
            if [[ ${#HIST_NET_TX[@]} -gt $HIST_RETENTION ]]; then
                HIST_NET_TX=("${HIST_NET_TX[@]:1}")
            fi
            ;;
        disk_r)
            HIST_DISK_R+=("$val")
            if [[ ${#HIST_DISK_R[@]} -gt $HIST_RETENTION ]]; then
                HIST_DISK_R=("${HIST_DISK_R[@]:1}")
            fi
            ;;
        disk_w)
            HIST_DISK_W+=("$val")
            if [[ ${#HIST_DISK_W[@]} -gt $HIST_RETENTION ]]; then
                HIST_DISK_W=("${HIST_DISK_W[@]:1}")
            fi
            ;;
    esac
}

# Retrieve the historical values as an array/string
history_get_series() {
    local metric="$1"
    case "$metric" in
        cpu) echo "${HIST_CPU[*]:-}" ;;
        mem) echo "${HIST_MEM[*]:-}" ;;
        temp) echo "${HIST_TEMP[*]:-}" ;;
        net_rx) echo "${HIST_NET_RX[*]:-}" ;;
        net_tx) echo "${HIST_NET_TX[*]:-}" ;;
        disk_r) echo "${HIST_DISK_R[*]:-}" ;;
        disk_w) echo "${HIST_DISK_W[*]:-}" ;;
    esac
}

# Calculate minimum in history
history_get_min() {
    local series=($(history_get_series "$1"))
    if [[ ${#series[@]} -eq 0 ]]; then
        echo 0
        return 0
    fi
    local min="${series[0]}"
    for v in "${series[@]}"; do
        if [[ $v -lt $min ]]; then
            min="$v"
        fi
    done
    echo "$min"
}

# Calculate maximum in history
history_get_max() {
    local series=($(history_get_series "$1"))
    if [[ ${#series[@]} -eq 0 ]]; then
        echo 0
        return 0
    fi
    local max="${series[0]}"
    for v in "${series[@]}"; do
        if [[ $v -gt $max ]]; then
            max="$v"
        fi
    done
    echo "$max"
}

# Calculate integer average in history
history_get_avg() {
    local series=($(history_get_series "$1"))
    if [[ ${#series[@]} -eq 0 ]]; then
        echo 0
        return 0
    fi
    local sum=0
    for v in "${series[@]}"; do
        sum=$(( sum + v ))
    done
    echo $(( sum / ${#series[@]} ))
}
