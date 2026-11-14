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
SYS_VIRT_TYPE="Bare Metal"
SYS_IS_WSL="false"
SYS_HOST_OS=""
SYS_HOST_RAM_GB="N/A"
SYS_HOST_UPTIME="N/A"

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

# Detect virtualization environment (WSL2, Container, VM, or Bare Metal)
system_detect_virtualization() {
    SYS_IS_WSL="false"
    SYS_VIRT_TYPE="Bare Metal"
    SYS_HOST_OS=""

    # 1. Check for WSL / WSL2
    if [[ -f "/proc/version" ]] && grep -qi "microsoft" /proc/version 2>/dev/null; then
        SYS_IS_WSL="true"
        SYS_VIRT_TYPE="WSL2 (Windows Subsystem for Linux)"
        SYS_HOST_OS="Windows"

        # Query host physical memory and uptime if PowerShell is available
        if command -v powershell.exe >/dev/null 2>&1; then
            local h_ram
            h_ram=$(powershell.exe -NoProfile -NonInteractive -Command "[Math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 1)" 2>/dev/null | tr -d '\r\n ' || true)
            if [[ -n "$h_ram" ]]; then
                SYS_HOST_RAM_GB="${h_ram} GB"
            fi

            local h_up
            h_up=$(powershell.exe -NoProfile -NonInteractive -Command "
                \$os = Get-CimInstance Win32_OperatingSystem
                \$uptime = (Get-Date) - \$os.LastBootUpTime
                [string]::Format('{0}d {1:D2}h {2:D2}m', \$uptime.Days, \$uptime.Hours, \$uptime.Minutes)
            " 2>/dev/null | tr -d '\r\n' || true)
            if [[ -n "$h_up" ]]; then
                SYS_HOST_UPTIME="$h_up"
            fi
        fi
        return 0
    fi

    # 2. Check for containers
    if [[ -f "/.dockerenv" ]] || [[ -f "/run/.containerenv" ]]; then
        SYS_VIRT_TYPE="Container (Docker / Podman)"
        return 0
    fi

    # 3. Check systemd-detect-virt
    if command -v systemd-detect-virt >/dev/null 2>&1; then
        local virt
        virt=$(systemd-detect-virt 2>/dev/null || echo "none")
        if [[ "$virt" != "none" ]]; then
            SYS_VIRT_TYPE="Virtual Machine ($virt)"
            return 0
        fi
    fi
}

# Collect overall system identity
system_collect() {
    system_collect_os
    system_collect_uptime
    system_detect_virtualization

    SYS_KERNEL=$(uname -r 2>/dev/null || echo "Unknown")
    SYS_ARCH=$(uname -m 2>/dev/null || echo "Unknown")

    if [[ -f "/proc/sys/kernel/hostname" && -r "/proc/sys/kernel/hostname" ]]; then
        read -r SYS_HOSTNAME < "/proc/sys/kernel/hostname" || SYS_HOSTNAME=$(uname -n 2>/dev/null || echo "localhost")
    else
        SYS_HOSTNAME=$(uname -n 2>/dev/null || echo "localhost")
    fi

    SYS_CURRENT_USER=$(id -un 2>/dev/null || whoami 2>/dev/null || echo "$USER")
}
