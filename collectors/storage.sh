#!/usr/bin/env bash
# collectors/storage.sh - Storage and Disk I/O collector for SMD-TUI
# Strictly read-only access to /proc/diskstats and df -P -k

STORAGE_TOTAL_READ_BPS=0
STORAGE_TOTAL_WRITE_BPS=0

declare -a STORAGE_FS_DEVICE=()
declare -a STORAGE_FS_MOUNT=()
declare -a STORAGE_FS_SIZE_KB=()
declare -a STORAGE_FS_USED_KB=()
declare -a STORAGE_FS_AVAIL_KB=()
declare -a STORAGE_FS_PERCENT=()

# Internal previous disk stats state
_PREV_DISK_READ_SECTORS=0
_PREV_DISK_WRITE_SECTORS=0
_PREV_DISK_TIME=0

# Collect disk I/O rates (bytes per second)
storage_collect_io() {
    local diskstats_file="${1:-/proc/diskstats}"
    local cur_time="${2:-$(date +%s)}"

    if [[ ! -f "$diskstats_file" || ! -r "$diskstats_file" ]]; then
        STORAGE_TOTAL_READ_BPS=0
        STORAGE_TOTAL_WRITE_BPS=0
        return 0
    fi

    local total_read_sec=0
    local total_write_sec=0

    while IFS= read -r line || [[ -n "$line" ]]; do
        # Extract columns: 3: dev, 6: read sectors, 10: write sectors
        # Example: 8 0 sda 1000 50 20000 5000 500 20 10000 ...
        local parts=($line)
        if [[ ${#parts[@]} -ge 10 ]]; then
            local dev="${parts[2]}"
            local r_sec="${parts[5]}"
            local w_sec="${parts[9]}"

            # Only count primary devices (e.g. sda, sdb, nvme0n1, vda, mmcblk0) to prevent double counting partitions
            if [[ "$dev" =~ ^(sd[a-z]|nvme[0-9]+n[0-9]+|vd[a-z]|hd[a-z]|mmcblk[0-9]+)$ ]]; then
                total_read_sec=$(( total_read_sec + r_sec ))
                total_write_sec=$(( total_write_sec + w_sec ))
            fi
        fi
    done < "$diskstats_file"

    if [[ $_PREV_DISK_TIME -gt 0 ]]; then
        local elapsed=$(( cur_time - _PREV_DISK_TIME ))
        if [[ $elapsed -gt 0 ]]; then
            local d_read=$(( total_read_sec - _PREV_DISK_READ_SECTORS ))
            local d_write=$(( total_write_sec - _PREV_DISK_WRITE_SECTORS ))

            if [[ $d_read -lt 0 ]]; then d_read=0; fi
            if [[ $d_write -lt 0 ]]; then d_write=0; fi

            # 1 sector = 512 bytes
            local read_bytes=$(( d_read * 512 ))
            local write_bytes=$(( d_write * 512 ))

            STORAGE_TOTAL_READ_BPS=$(calc_rate "$read_bytes" "$elapsed")
            STORAGE_TOTAL_WRITE_BPS=$(calc_rate "$write_bytes" "$elapsed")
        fi
    fi

    _PREV_DISK_READ_SECTORS="$total_read_sec"
    _PREV_DISK_WRITE_SECTORS="$total_write_sec"
    _PREV_DISK_TIME="$cur_time"
}

# Collect mounted filesystems capacity and utilization
storage_collect_filesystems() {
    STORAGE_FS_DEVICE=()
    STORAGE_FS_MOUNT=()
    STORAGE_FS_SIZE_KB=()
    STORAGE_FS_USED_KB=()
    STORAGE_FS_AVAIL_KB=()
    STORAGE_FS_PERCENT=()

    local df_cmd="df -P -k"
    if df -x tmpfs >/dev/null 2>&1; then
        df_cmd="df -P -k -x tmpfs -x devtmpfs -x squashfs 2>/dev/null"
    fi

    local header=1
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ $header -eq 1 ]]; then
            header=0
            continue
        fi

        # Format: Filesystem 1024-blocks Used Available Capacity Mounted on
        local parts=($line)
        if [[ ${#parts[@]} -ge 6 ]]; then
            local dev="${parts[0]}"
            local size="${parts[1]}"
            local used="${parts[2]}"
            local avail="${parts[3]}"
            local cap="${parts[4]}"
            local mount="${parts[5]}"

            # Ignore virtual/special mounts
            if [[ "$mount" =~ ^/(dev|sys|proc) ]]; then
                continue
            fi

            # Clean percentage symbol
            local pct="${cap%\%}"

            STORAGE_FS_DEVICE+=("$dev")
            STORAGE_FS_SIZE_KB+=("$size")
            STORAGE_FS_USED_KB+=("$used")
            STORAGE_FS_AVAIL_KB+=("$avail")
            STORAGE_FS_PERCENT+=("${pct:-0}")
            STORAGE_FS_MOUNT+=("$mount")
        fi
    done < <(eval "$df_cmd" 2>/dev/null || df -P -k 2>/dev/null || true)
}

storage_collect() {
    storage_collect_io "/proc/diskstats" "$(date +%s)"
    storage_collect_filesystems
}
