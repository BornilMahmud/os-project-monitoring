#!/usr/bin/env bash
# collectors/system.sh - System identity, OS distribution, kernel, uptime collector
# Strictly read-only access to /etc/os-release, /proc/uptime, /proc/sys/kernel/hostname

SYS_DISTRO_NAME="Linux"
SYS_DISTRO_VERSION=""
SYS_DISTRO_PRETTY="Linux Generic"
SYS_KERNEL=""
SYS_ARCH=""
SYS_HOSTNAME=""
SYS_UPTIME_SEC=0
SYS_UPTIME_PRETTY="0s"
SYS_CURRENT_USER=""

# Parse distribution details from /etc/os-release or fallback
system_collect_os() {
    local os_file="${1:-/etc/os-release}"

    if [[ ! -f "$os_file" || ! -r "$os_file" ]]; then
        SYS_DISTRO_NAME="Linux"
        SYS_DISTRO_VERSION="Unknown"
        SYS_DISTRO_PRETTY="Linux Generic"
        return 0
    fi

    local name="" version="" pretty=""

    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" =~ ^NAME=\"?(.*[^\"])\"?$ ]]; then
            name="${BASH_REMATCH[1]}"
            name="${name%\"}"
            name="${name#\"}"
        elif [[ "$line" =~ ^VERSION=\"?(.*[^\"])\"?$ ]]; then
            version="${BASH_REMATCH[1]}"
            version="${version%\"}"
            version="${version#\"}"
        elif [[ "$line" =~ ^PRETTY_NAME=\"?(.*[^\"])\"?$ ]]; then
            pretty="${BASH_REMATCH[1]}"
            pretty="${pretty%\"}"
            pretty="${pretty#\"}"
        fi
    done < "$os_file"

    SYS_DISTRO_NAME="${name:-Linux}"
    SYS_DISTRO_VERSION="${version:-}"
    SYS_DISTRO_PRETTY="${pretty:-${SYS_DISTRO_NAME} ${SYS_DISTRO_VERSION}}"
}

# Parse system uptime from /proc/uptime
system_collect_uptime() {
    local uptime_file="${1:-/proc/uptime}"

    if [[ ! -f "$uptime_file" || ! -r "$uptime_file" ]]; then
        SYS_UPTIME_SEC=0
        SYS_UPTIME_PRETTY="0s"
        return 0
    fi

    local up_sec _
    read -r up_sec _ < "$uptime_file" || true

    # Strip decimal portion for integer duration formatting
    local int_sec="${up_sec%%.*}"
    int_sec="${int_sec:-0}"

    SYS_UPTIME_SEC="$int_sec"
    SYS_UPTIME_PRETTY=$(format_duration "$int_sec")
}

# Collect overall system identity
system_collect() {
    system_collect_os
    system_collect_uptime

    SYS_KERNEL=$(uname -r 2>/dev/null || echo "Unknown")
    SYS_ARCH=$(uname -m 2>/dev/null || echo "Unknown")

    if [[ -f "/proc/sys/kernel/hostname" && -r "/proc/sys/kernel/hostname" ]]; then
        read -r SYS_HOSTNAME < "/proc/sys/kernel/hostname" || SYS_HOSTNAME=$(uname -n 2>/dev/null || echo "localhost")
    else
        SYS_HOSTNAME=$(uname -n 2>/dev/null || echo "localhost")
    fi

    SYS_CURRENT_USER=$(id -un 2>/dev/null || whoami 2>/dev/null || echo "$USER")
}
