#!/usr/bin/env bash
# core/export.sh - Report and CSV metric export utilities for SMD-TUI
# Strictly writes to application-owned XDG directories or user-specified output files.

# Generate a modern, self-contained HTML system intelligence report
export_report_html() {
    local target="${1:-}"

    if [[ -z "$target" ]]; then
        local ts
        ts="$(date +%Y%m%d_%H%M%S)"
        target="${SMD_REPORT_DIR}/report_${ts}.html"
    fi

    # Ensure parent directory exists
    mkdir -p "$(dirname "$target")" 2>/dev/null || true

    # Also create a local project exports directory if running in project root
    local local_export_dir=""
    if [[ -d "./exports" || -w "." ]]; then
        mkdir -p "./exports" 2>/dev/null || true
        if [[ -d "./exports" && -w "./exports" ]]; then
            local_export_dir="./exports"
        fi
    fi

    # Gather fresh real-time metrics
    system_collect
    cpu_collect
    mem_collect
    storage_collect
    network_collect
    thermal_collect
    battery_collect
    process_collect 15

    local gen_time
    gen_time="$(date +"%Y-%m-%d %H:%M:%S")"

    local cpu_used_pct="${CPU_USAGE_TOTAL:-0}"
    local mem_used_pct="${MEM_USAGE_PERCENT:-0}"
    local ram_tot_str
    ram_tot_str=$(format_bytes $(( MEM_TOTAL_KB * 1024 )))
    local ram_used_str
    ram_used_str=$(format_bytes $(( MEM_USED_KB * 1024 )))
    local ram_avail_str
    ram_avail_str=$(format_bytes $(( MEM_AVAIL_KB * 1024 )))
    local ram_free_str
    ram_free_str=$(format_bytes $(( MEM_FREE_KB * 1024 )))
    local ram_cache_str
    ram_cache_str=$(format_bytes $(( (MEM_BUFFERS_KB + MEM_CACHED_KB) * 1024 )))

    local swap_tot_str="None"
    local swap_used_str="0 B"
    local swap_pct=0
    if [[ $MEM_SWAP_TOTAL_KB -gt 0 ]]; then
        swap_tot_str=$(format_bytes $(( MEM_SWAP_TOTAL_KB * 1024 )))
        swap_used_str=$(format_bytes $(( MEM_SWAP_USED_KB * 1024 )))
        swap_pct="$MEM_SWAP_PERCENT"
    fi

    local disk_read_str
    disk_read_str=$(format_speed "$STORAGE_TOTAL_READ_BPS")
    local disk_write_str
    disk_write_str=$(format_speed "$STORAGE_TOTAL_WRITE_BPS")
    local net_rx_str
    net_rx_str=$(format_speed "$NET_TOTAL_RX_BPS")
    local net_tx_str
    net_tx_str=$(format_speed "$NET_TOTAL_TX_BPS")

    local status_color="#10b981"
    local status_text="ALL SYSTEMS HEALTHY"
    if [[ $cpu_used_pct -ge 85 || $mem_used_pct -ge 90 ]]; then
        status_color="#f59e0b"
        status_text="HIGH RESOURCE UTILIZATION"
    fi

    cat << 'EOF_HTML_HEAD' > "$target"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>SMD-TUI 2.0 - System Intelligence Report</title>
    <style>
        :root {
            --bg-base: #0a0f1d;
            --bg-card: #131b2e;
            --bg-card-subtle: #19243d;
            --border-card: #202e4d;
            --text-main: #f1f5f9;
            --text-muted: #94a3b8;
            --text-dim: #64748b;
            --primary: #06b6d4;
            --accent: #3b82f6;
            --emerald: #10b981;
            --amber: #f59e0b;
            --rose: #f43f5e;
            --indigo: #818cf8;
            --font-sans: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            --font-mono: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", "Courier New", monospace;
        }
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
            background-color: var(--bg-base);
            color: var(--text-main);
            font-family: var(--font-sans);
            line-height: 1.5;
            padding: 32px 24px;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
        }
        header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            flex-wrap: wrap;
            gap: 16px;
            padding-bottom: 24px;
            border-bottom: 1px solid var(--border-card);
            margin-bottom: 28px;
        }
        .brand {
            display: flex;
            align-items: center;
            gap: 12px;
        }
        .brand-badge {
            background: linear-gradient(135deg, #06b6d4 0%, #3b82f6 100%);
            color: #04101e;
            font-weight: 800;
            font-size: 14px;
            padding: 6px 12px;
            border-radius: 8px;
            letter-spacing: 0.05em;
        }
        .brand-title h1 {
            font-size: 24px;
            font-weight: 700;
            letter-spacing: -0.02em;
            color: var(--text-main);
        }
        .brand-title p {
            color: var(--text-muted);
            font-size: 13px;
        }
        .header-actions {
            display: flex;
            align-items: center;
            gap: 12px;
        }
        .status-pill {
            display: inline-flex;
            align-items: center;
            gap: 8px;
            padding: 6px 14px;
            border-radius: 9999px;
            font-size: 12px;
            font-weight: 600;
            background: var(--bg-card);
            border: 1px solid var(--border-card);
        }
        .status-dot {
            width: 8px;
            height: 8px;
            border-radius: 50%;
        }
        .btn-print {
            background: var(--bg-card-subtle);
            border: 1px solid var(--border-card);
            color: var(--text-main);
            padding: 8px 16px;
            border-radius: 8px;
            font-size: 13px;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.2s ease;
        }
        .btn-print:hover {
            background: var(--border-card);
            color: #fff;
        }
        /* Top Executive Summary Cards */
        .summary-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
            gap: 18px;
            margin-bottom: 28px;
        }
        .summary-card {
            background: var(--bg-card);
            border: 1px solid var(--border-card);
            border-radius: 12px;
            padding: 20px;
            position: relative;
            overflow: hidden;
        }
        .summary-card::before {
            content: '';
            position: absolute;
            top: 0; left: 0; right: 0;
            height: 3px;
            background: var(--card-accent, var(--primary));
        }
        .summary-label {
            font-size: 12px;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.05em;
            color: var(--text-muted);
            margin-bottom: 8px;
        }
        .summary-value {
            font-size: 32px;
            font-weight: 700;
            letter-spacing: -0.02em;
            font-family: var(--font-mono);
            margin-bottom: 8px;
        }
        .summary-subtext {
            font-size: 13px;
            color: var(--text-muted);
        }
        .progress-bar {
            height: 8px;
            background: rgba(255,255,255,0.08);
            border-radius: 9999px;
            overflow: hidden;
            margin-top: 12px;
        }
        .progress-fill {
            height: 100%;
            border-radius: 9999px;
            transition: width 0.3s ease;
        }
        /* Content Sections */
        .section-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(540px, 1fr));
            gap: 22px;
            margin-bottom: 28px;
        }
        @media (max-width: 768px) {
            .section-grid { grid-template-columns: 1fr; }
        }
        .panel {
            background: var(--bg-card);
            border: 1px solid var(--border-card);
            border-radius: 12px;
            padding: 22px;
        }
        .panel-full {
            margin-bottom: 28px;
        }
        .panel-header {
            display: flex;
            align-items: center;
            justify-content: space-between;
            margin-bottom: 18px;
            padding-bottom: 12px;
            border-bottom: 1px solid var(--border-card);
        }
        .panel-title {
            font-size: 16px;
            font-weight: 600;
            color: var(--text-main);
            display: flex;
            align-items: center;
            gap: 8px;
        }
        .panel-title-icon {
            color: var(--primary);
        }
        .panel-badge {
            font-size: 12px;
            color: var(--text-muted);
            background: var(--bg-card-subtle);
            padding: 3px 8px;
            border-radius: 6px;
            font-family: var(--font-mono);
        }
        /* Key-Value Lists */
        .kv-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
            gap: 12px 20px;
        }
        .kv-item {
            display: flex;
            flex-direction: column;
        }
        .kv-key {
            font-size: 12px;
            color: var(--text-muted);
            margin-bottom: 2px;
        }
        .kv-val {
            font-size: 14px;
            font-weight: 600;
            color: var(--text-main);
            font-family: var(--font-mono);
            word-break: break-all;
        }
        /* Core Grid */
        .core-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(110px, 1fr));
            gap: 8px;
            margin-top: 14px;
        }
        .core-box {
            background: var(--bg-card-subtle);
            border: 1px solid rgba(255,255,255,0.05);
            border-radius: 8px;
            padding: 8px 10px;
            text-align: center;
        }
        .core-name {
            font-size: 11px;
            color: var(--text-muted);
            margin-bottom: 4px;
        }
        .core-pct {
            font-size: 14px;
            font-weight: 700;
            font-family: var(--font-mono);
        }
        /* Tables */
        .table-responsive {
            overflow-x: auto;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            font-size: 13px;
        }
        th {
            text-align: left;
            padding: 10px 14px;
            color: var(--text-muted);
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.04em;
            font-size: 11px;
            border-bottom: 1px solid var(--border-card);
        }
        td {
            padding: 10px 14px;
            border-bottom: 1px solid rgba(255,255,255,0.04);
            font-family: var(--font-mono);
            color: var(--text-main);
        }
        tr:hover td {
            background: rgba(255,255,255,0.02);
        }
        .tag {
            display: inline-block;
            padding: 2px 7px;
            border-radius: 4px;
            font-size: 11px;
            font-weight: 600;
        }
        .tag-green { background: rgba(16, 185, 129, 0.15); color: #34d399; }
        .tag-blue { background: rgba(59, 130, 246, 0.15); color: #60a5fa; }
        .tag-amber { background: rgba(245, 158, 11, 0.15); color: #fbbf24; }
        .tag-muted { background: rgba(148, 163, 184, 0.15); color: #94a3b8; }
        footer {
            margin-top: 40px;
            padding-top: 20px;
            border-top: 1px solid var(--border-card);
            text-align: center;
            color: var(--text-dim);
            font-size: 12px;
        }
        @media print {
            body { background: #fff; color: #000; padding: 0; }
            .btn-print { display: none; }
            .panel, .summary-card { border: 1px solid #ccc; background: #fff; color: #000; box-shadow: none; }
            th, td, .kv-val, .kv-key, .summary-subtext, .brand-title h1, .brand-title p { color: #000 !important; }
        }
    </style>
</head>
<body>
<div class="container">
    <header>
        <div class="brand">
            <div class="brand-badge">SMD-TUI 2.0</div>
            <div class="brand-title">
                <h1>Hardware Intelligence & Telemetry Report</h1>
                <p>Local Linux Hardware Monitoring & Environment Analysis</p>
            </div>
        </div>
        <div class="header-actions">
            <div class="status-pill">
                <span class="status-dot" style="background: __STATUS_COLOR__;"></span>
                <span>__STATUS_TEXT__</span>
            </div>
            <button class="btn-print" onclick="window.print()">Print / Save PDF</button>
        </div>
    </header>
EOF_HTML_HEAD

    # Replace placeholders in head
    sed -i "s/__STATUS_COLOR__/${status_color}/g" "$target"
    sed -i "s/__STATUS_TEXT__/${status_text}/g" "$target"

    # Executive Summary Cards
    cat << EOF >> "$target"
    <!-- Executive Summary -->
    <div class="summary-grid">
        <div class="summary-card" style="--card-accent: #06b6d4;">
            <div class="summary-label">CPU Utilization</div>
            <div class="summary-value" style="color: #06b6d4;">${cpu_used_pct}%</div>
            <div class="summary-subtext">${CPU_INFO_PHYSICAL_CORES} Cores / ${CPU_INFO_LOGICAL_CORES} Threads &bull; ${CPU_INFO_MHZ} MHz</div>
            <div class="progress-bar">
                <div class="progress-fill" style="width: ${cpu_used_pct}%; background: #06b6d4;"></div>
            </div>
        </div>

        <div class="summary-card" style="--card-accent: #818cf8;">
            <div class="summary-label">Memory Utilization</div>
            <div class="summary-value" style="color: #818cf8;">${mem_used_pct}%</div>
            <div class="summary-subtext">${ram_used_str} of ${ram_tot_str} (${ram_avail_str} avail)</div>
            <div class="progress-bar">
                <div class="progress-fill" style="width: ${mem_used_pct}%; background: #818cf8;"></div>
            </div>
        </div>

        <div class="summary-card" style="--card-accent: #10b981;">
            <div class="summary-label">Storage Throughput</div>
            <div class="summary-value" style="color: #10b981;">${disk_read_str}</div>
            <div class="summary-subtext">Write: ${disk_write_str} &bull; ${#STORAGE_FS_MOUNT[@]} active partitions</div>
            <div class="progress-bar">
                <div class="progress-fill" style="width: 100%; background: #10b981;"></div>
            </div>
        </div>

        <div class="summary-card" style="--card-accent: #3b82f6;">
            <div class="summary-label">Network Throughput</div>
            <div class="summary-value" style="color: #3b82f6;">${net_rx_str}</div>
            <div class="summary-subtext">Tx: ${net_tx_str} &bull; ${#NET_IFACES[@]} active interfaces</div>
            <div class="progress-bar">
                <div class="progress-fill" style="width: 100%; background: #3b82f6;"></div>
            </div>
        </div>
    </div>

    <!-- Section Grid: System & CPU -->
    <div class="section-grid">
        <!-- Panel 1: System Identity -->
        <div class="panel">
            <div class="panel-header">
                <div class="panel-title">
                    <span class="panel-title-icon">&#9679;</span> System Identity & Environment
                </div>
                <div class="panel-badge">${SYS_VIRT_TYPE}</div>
            </div>
            <div class="kv-grid">
                <div class="kv-item"><div class="kv-key">Hostname</div><div class="kv-val">${SYS_HOSTNAME}</div></div>
                <div class="kv-item"><div class="kv-key">Distribution</div><div class="kv-val">${SYS_DISTRO_PRETTY}</div></div>
                <div class="kv-item"><div class="kv-key">Kernel</div><div class="kv-val">${SYS_KERNEL}</div></div>
                <div class="kv-item"><div class="kv-key">Architecture</div><div class="kv-val">${SYS_ARCH}</div></div>
                <div class="kv-item"><div class="kv-key">Logged-in User</div><div class="kv-val">${SYS_CURRENT_USER}</div></div>
                <div class="kv-item"><div class="kv-key">Linux Uptime</div><div class="kv-val">${SYS_UPTIME_PRETTY}</div></div>
EOF

    if [[ "$SYS_IS_WSL" == "true" ]]; then
        cat << EOF >> "$target"
                <div class="kv-item"><div class="kv-key">Host Machine</div><div class="kv-val">Windows (${SYS_HOST_UPTIME} Up)</div></div>
                <div class="kv-item"><div class="kv-key">Host Physical RAM</div><div class="kv-val">${SYS_HOST_RAM_GB}</div></div>
                <div class="kv-item"><div class="kv-key">Host GPU</div><div class="kv-val">${SYS_HOST_GPU}</div></div>
EOF
    fi

    cat << EOF >> "$target"
                <div class="kv-item"><div class="kv-key">Report Generated</div><div class="kv-val">${gen_time}</div></div>
            </div>
        </div>

        <!-- Panel 2: CPU Hardware -->
        <div class="panel">
            <div class="panel-header">
                <div class="panel-title">
                    <span class="panel-title-icon">&#9679;</span> CPU Metrics & Per-Core Load
                </div>
                <div class="panel-badge">${CPU_INFO_PHYSICAL_CORES}C / ${CPU_INFO_LOGICAL_CORES}T</div>
            </div>
            <div class="kv-grid">
                <div class="kv-item"><div class="kv-key">Processor Model</div><div class="kv-val">${CPU_INFO_MODEL}</div></div>
                <div class="kv-item"><div class="kv-key">Base Clock</div><div class="kv-val">${CPU_INFO_MHZ} MHz</div></div>
                <div class="kv-item"><div class="kv-key">Load Averages</div><div class="kv-val">${CPU_LOAD_1M}, ${CPU_LOAD_5M}, ${CPU_LOAD_15M}</div></div>
                <div class="kv-item"><div class="kv-key">Task States</div><div class="kv-val">${CPU_LOAD_RUNNABLE} running / ${CPU_LOAD_TOTAL_PROCS} total</div></div>
            </div>

            <div class="core-grid">
EOF

    for i in "${!CPU_USAGE_CORES[@]}"; do
        local cpct="${CPU_USAGE_CORES[$i]}"
        local ccolor="#06b6d4"
        if [[ $cpct -ge 80 ]]; then ccolor="#f43f5e"; elif [[ $cpct -ge 50 ]]; then ccolor="#f59e0b"; fi
        cat << EOF >> "$target"
                <div class="core-box">
                    <div class="core-name">Core $i</div>
                    <div class="core-pct" style="color: ${ccolor};">${cpct}%</div>
                </div>
EOF
    done

    cat << EOF >> "$target"
            </div>
        </div>
    </div>

    <!-- Section Grid: Memory & Storage -->
    <div class="section-grid">
        <!-- Panel 3: Memory & Swap -->
        <div class="panel">
            <div class="panel-header">
                <div class="panel-title">
                    <span class="panel-title-icon">&#9679;</span> Memory & Swap Telemetry
                </div>
                <div class="panel-badge">${ram_used_str} / ${ram_tot_str}</div>
            </div>
            <div class="kv-grid">
                <div class="kv-item"><div class="kv-key">Total RAM</div><div class="kv-val">${ram_tot_str}</div></div>
                <div class="kv-item"><div class="kv-key">Used RAM</div><div class="kv-val">${ram_used_str} (${mem_used_pct}%)</div></div>
                <div class="kv-item"><div class="kv-key">Available RAM</div><div class="kv-val">${ram_avail_str}</div></div>
                <div class="kv-item"><div class="kv-key">Free RAM</div><div class="kv-val">${ram_free_str}</div></div>
                <div class="kv-item"><div class="kv-key">Buffers / Cache</div><div class="kv-val">${ram_cache_str}</div></div>
                <div class="kv-item"><div class="kv-key">Swap Space</div><div class="kv-val">${swap_used_str} / ${swap_tot_str} (${swap_pct}%)</div></div>
            </div>
            <div style="margin-top: 16px;">
                <div class="kv-key">RAM Allocation</div>
                <div class="progress-bar">
                    <div class="progress-fill" style="width: ${mem_used_pct}%; background: #818cf8;"></div>
                </div>
            </div>
        </div>

        <!-- Panel 4: Thermals & Hardware Power -->
        <div class="panel">
            <div class="panel-header">
                <div class="panel-title">
                    <span class="panel-title-icon">&#9679;</span> Hardware Thermals & Power
                </div>
                <div class="panel-badge">${BATTERY_STATUS}</div>
            </div>
            <div class="kv-grid">
                <div class="kv-item"><div class="kv-key">Thermal Status</div><div class="kv-val">${THERMAL_STATUS}</div></div>
                <div class="kv-item"><div class="kv-key">CPU Package Temp</div><div class="kv-val">${THERMAL_CPU_TEMP}&deg;C</div></div>
                <div class="kv-item"><div class="kv-key">Sensors Detected</div><div class="kv-val">${THERMAL_COUNT} active</div></div>
                <div class="kv-item"><div class="kv-key">Cooling Fans</div><div class="kv-val">${THERMAL_FAN_COUNT} detected</div></div>
                <div class="kv-item"><div class="kv-key">Power Source</div><div class="kv-val">Desktop PC / AC Power</div></div>
                <div class="kv-item"><div class="kv-key">Graphics Adapter</div><div class="kv-val">${SYS_HOST_GPU}</div></div>
            </div>
        </div>
    </div>

    <!-- Panel 5: Mounted Disks & Storage Volumes -->
    <div class="panel panel-full">
        <div class="panel-header">
            <div class="panel-title">
                <span class="panel-title-icon">&#9679;</span> Mounted Storage Volumes & Host Drives
            </div>
            <div class="panel-badge">Read: ${disk_read_str} | Write: ${disk_write_str}</div>
        </div>
        <div class="table-responsive">
            <table>
                <thead>
                    <tr>
                        <th>Device / Drive</th>
                        <th>Mountpoint</th>
                        <th>Capacity</th>
                        <th>Used Space</th>
                        <th>Usage</th>
                    </tr>
                </thead>
                <tbody>
EOF

    for i in "${!STORAGE_FS_MOUNT[@]}"; do
        local sz
        sz=$(format_bytes $(( ${STORAGE_FS_SIZE_KB[$i]} * 1024 )))
        local us
        us=$(format_bytes $(( ${STORAGE_FS_USED_KB[$i]} * 1024 )))
        local pct="${STORAGE_FS_PERCENT[$i]}"
        local pcol="#10b981"
        if [[ $pct -ge 90 ]]; then pcol="#f43f5e"; elif [[ $pct -ge 75 ]]; then pcol="#f59e0b"; fi

        cat << EOF >> "$target"
                    <tr>
                        <td><strong>${STORAGE_FS_DEVICE[$i]}</strong></td>
                        <td>${STORAGE_FS_MOUNT[$i]}</td>
                        <td>${sz}</td>
                        <td>${us}</td>
                        <td>
                            <div style="display: flex; align-items: center; gap: 8px;">
                                <div class="progress-bar" style="width: 120px; margin: 0;">
                                    <div class="progress-fill" style="width: ${pct}%; background: ${pcol};"></div>
                                </div>
                                <span>${pct}%</span>
                            </div>
                        </td>
                    </tr>
EOF
    done

    cat << EOF >> "$target"
                </tbody>
            </table>
        </div>
    </div>

    <!-- Panel 6: Network Interfaces -->
    <div class="panel panel-full">
        <div class="panel-header">
            <div class="panel-title">
                <span class="panel-title-icon">&#9679;</span> Network Interfaces & Throughput
            </div>
            <div class="panel-badge">Rx: ${net_rx_str} | Tx: ${net_tx_str}</div>
        </div>
        <div class="table-responsive">
            <table>
                <thead>
                    <tr>
                        <th>Interface</th>
                        <th>State</th>
                        <th>Current Download</th>
                        <th>Current Upload</th>
                        <th>Total Received</th>
                        <th>Total Transmitted</th>
                    </tr>
                </thead>
                <tbody>
EOF

    for i in "${!NET_IFACES[@]}"; do
        local rx_sp
        rx_sp=$(format_speed "${NET_IFACE_RX_BPS[$i]}")
        local tx_sp
        tx_sp=$(format_speed "${NET_IFACE_TX_BPS[$i]}")
        local rx_tot
        rx_tot=$(format_bytes "${NET_IFACE_TOTAL_RX[$i]}")
        local tx_tot
        tx_tot=$(format_bytes "${NET_IFACE_TOTAL_TX[$i]}")
        local st_tag="tag-green"
        if [[ "${NET_IFACE_STATUS[$i]}" != "UP" ]]; then st_tag="tag-muted"; fi

        cat << EOF >> "$target"
                    <tr>
                        <td><strong>${NET_IFACES[$i]}</strong></td>
                        <td><span class="tag ${st_tag}">${NET_IFACE_STATUS[$i]}</span></td>
                        <td style="color: #34d399;">${rx_sp}</td>
                        <td style="color: #fbbf24;">${tx_sp}</td>
                        <td>${rx_tot}</td>
                        <td>${tx_tot}</td>
                    </tr>
EOF
    done

    cat << EOF >> "$target"
                </tbody>
            </table>
        </div>
    </div>

    <!-- Panel 7: Top Consuming Processes -->
    <div class="panel panel-full">
        <div class="panel-header">
            <div class="panel-title">
                <span class="panel-title-icon">&#9679;</span> Top Resource Consuming Processes
            </div>
            <div class="panel-badge">${#PROC_CPU_PID[@]} scanned</div>
        </div>
        <div class="table-responsive">
            <table>
                <thead>
                    <tr>
                        <th>PID</th>
                        <th>User</th>
                        <th>% CPU</th>
                        <th>% Memory</th>
                        <th>Process Command</th>
                    </tr>
                </thead>
                <tbody>
EOF

    for i in "${!PROC_CPU_PID[@]}"; do
        if [[ $i -lt 15 ]]; then
            cat << EOF >> "$target"
                    <tr>
                        <td>${PROC_CPU_PID[$i]}</td>
                        <td>${PROC_CPU_USER[$i]}</td>
                        <td style="color: #06b6d4; font-weight: 600;">${PROC_CPU_PCT[$i]}%</td>
                        <td>${PROC_CPU_MEM[$i]}%</td>
                        <td>${PROC_CPU_COMM[$i]}</td>
                    </tr>
EOF
        fi
    done

    cat << EOF >> "$target"
                </tbody>
            </table>
        </div>
    </div>

    <footer>
        <p>SMD-TUI 2.0 &bull; Linux Hardware Intelligence & Interactive Terminal Monitor &bull; Generated locally in user space with zero root privileges.</p>
    </footer>
</div>
</body>
</html>
EOF

    # If local exports directory exists, make a copy there too for instant access
    if [[ -n "$local_export_dir" && "$target" != "$local_export_dir/"* ]]; then
        local copy_target="${local_export_dir}/$(basename "$target")"
        cp "$target" "$copy_target" 2>/dev/null || true
    fi

    echo "$target"
}

# Generate a formatted system intelligence text report
export_report_txt() {
    local target="${1:-}"

    if [[ -z "$target" ]]; then
        local ts
        ts="$(date +%Y%m%d_%H%M%S)"
        target="${SMD_REPORT_DIR}/report_${ts}.txt"
    fi

    # Ensure parent directory exists
    mkdir -p "$(dirname "$target")" 2>/dev/null || true

    # Gather fresh metrics
    system_collect
    cpu_collect
    mem_collect
    storage_collect
    network_collect
    thermal_collect
    battery_collect
    process_collect 10

    local gen_time
    gen_time="$(date +"%Y-%m-%d %H:%M:%S")"

    cat << EOF > "$target"
================================================================================
SMD-TUI 2.0 System Intelligence Report
Generated: $gen_time
================================================================================

[SYSTEM IDENTITY & ENVIRONMENT]
  Hostname        : $SYS_HOSTNAME
  Distro          : $SYS_DISTRO_PRETTY
  Kernel          : $SYS_KERNEL ($SYS_ARCH)
  Current User    : $SYS_CURRENT_USER
  Environment     : $SYS_VIRT_TYPE
  Linux Uptime    : $SYS_UPTIME_PRETTY
EOF

    if [[ "$SYS_IS_WSL" == "true" ]]; then
        cat << EOF >> "$target"
  Host OS         : Windows
  Host Uptime     : $SYS_HOST_UPTIME
  Host Total RAM  : $SYS_HOST_RAM_GB
  Host GPU        : $SYS_HOST_GPU
EOF
    fi

    cat << EOF >> "$target"

[CPU METRICS]
  Model           : $CPU_INFO_MODEL
  Architecture    : ${CPU_INFO_PHYSICAL_CORES} Physical Cores, ${CPU_INFO_LOGICAL_CORES} Logical Threads
  Base Clock      : $CPU_INFO_MHZ MHz
  Overall Usage   : ${CPU_USAGE_TOTAL}%
  Load Averages   : $CPU_LOAD_1M (1m), $CPU_LOAD_5M (5m), $CPU_LOAD_15M (15m)
  Active Tasks    : $CPU_LOAD_RUNNABLE running / $CPU_LOAD_TOTAL_PROCS total

[MEMORY & SWAP]
  Total RAM       : $(format_bytes $(( MEM_TOTAL_KB * 1024 )))
  Used RAM        : $(format_bytes $(( MEM_USED_KB * 1024 ))) (${MEM_USAGE_PERCENT}%)
  Available RAM   : $(format_bytes $(( MEM_AVAIL_KB * 1024 )))
  Free RAM        : $(format_bytes $(( MEM_FREE_KB * 1024 )))
  Buffers/Cache   : $(format_bytes $(( (MEM_BUFFERS_KB + MEM_CACHED_KB) * 1024 )))
  Swap Total      : $(format_bytes $(( MEM_SWAP_TOTAL_KB * 1024 )))
  Swap Used       : $(format_bytes $(( MEM_SWAP_USED_KB * 1024 ))) (${MEM_SWAP_PERCENT}%)

[STORAGE & DISK I/O]
  Disk Read Rate  : $(format_speed "$STORAGE_TOTAL_READ_BPS")
  Disk Write Rate : $(format_speed "$STORAGE_TOTAL_WRITE_BPS")
  Mounted Filesystems:
EOF

    for i in "${!STORAGE_FS_MOUNT[@]}"; do
        local sz
        sz=$(format_bytes $(( ${STORAGE_FS_SIZE_KB[$i]} * 1024 )))
        local us
        us=$(format_bytes $(( ${STORAGE_FS_USED_KB[$i]} * 1024 )))
        printf "    %-18s %-12s %-12s %-8s %s\n" \
            "${STORAGE_FS_DEVICE[$i]}" "$sz" "$us" "${STORAGE_FS_PERCENT[$i]}%" "${STORAGE_FS_MOUNT[$i]}" >> "$target"
    done

    cat << EOF >> "$target"

[NETWORK INTERFACES & THROUGHPUT]
  Total Download  : $(format_speed "$NET_TOTAL_RX_BPS")
  Total Upload    : $(format_speed "$NET_TOTAL_TX_BPS")
EOF

    for i in "${!NET_IFACES[@]}"; do
        local rx_sp
        rx_sp=$(format_speed "${NET_IFACE_RX_BPS[$i]}")
        local tx_sp
        tx_sp=$(format_speed "${NET_IFACE_TX_BPS[$i]}")
        local rx_tot
        rx_tot=$(format_bytes "${NET_IFACE_TOTAL_RX[$i]}")
        local tx_tot
        tx_tot=$(format_bytes "${NET_IFACE_TOTAL_TX[$i]}")
        printf "    - %-10s [%s] Rx: %s | Tx: %s (Total: %s / %s)\n" \
            "${NET_IFACES[$i]}" "${NET_IFACE_STATUS[$i]}" "$rx_sp" "$tx_sp" "$rx_tot" "$tx_tot" >> "$target"
    done

    cat << EOF >> "$target"

[THERMAL SENSORS & POWER]
  Thermal Status  : $THERMAL_STATUS
  CPU Package     : ${THERMAL_CPU_TEMP}°C
  Battery State   : $BATTERY_STATUS ($BATTERY_PERCENT%)

[TOP 10 PROCESSES]
  PID     USER         %CPU     %MEM     COMMAND
  ----------------------------------------------------------------------
EOF

    for i in "${!PROC_CPU_PID[@]}"; do
        if [[ $i -lt 10 ]]; then
            printf "  %-7s %-12s %-8s %-8s %s\n" \
                "${PROC_CPU_PID[$i]}" "${PROC_CPU_USER[$i]}" "${PROC_CPU_PCT[$i]}%" "${PROC_CPU_MEM[$i]}%" "${PROC_CPU_COMM[$i]}" >> "$target"
        fi
    done

    cat << EOF >> "$target"

================================================================================
End of SMD-TUI 2.0 Report
================================================================================
EOF

    echo "$target"
}

# Export live metrics row to CSV file
export_metrics_csv() {
    local target="${1:-}"

    if [[ -z "$target" ]]; then
        local ts
        ts="$(date +%Y%m%d_%H%M%S)"
        target="${SMD_EXPORT_DIR}/metrics_${ts}.csv"
    fi

    # Ensure parent directory exists
    mkdir -p "$(dirname "$target")" 2>/dev/null || true

    # Write CSV header if file is new or empty
    if [[ ! -s "$target" ]]; then
        echo "Timestamp,CPU_Usage,RAM_Used_MB,RAM_Total_MB,RAM_Usage_Pct,Disk_Read_Bps,Disk_Write_Bps,Net_Rx_Bps,Net_Tx_Bps,CPU_Temp_C" > "$target"
    fi

    local ts
    ts="$(date +"%Y-%m-%d %H:%M:%S")"
    local ram_used_mb=$(( MEM_USED_KB / 1024 ))
    local ram_tot_mb=$(( MEM_TOTAL_KB / 1024 ))

    echo "${ts},${CPU_USAGE_TOTAL},${ram_used_mb},${ram_tot_mb},${MEM_USAGE_PERCENT},${STORAGE_TOTAL_READ_BPS},${STORAGE_TOTAL_WRITE_BPS},${NET_TOTAL_RX_BPS},${NET_TOTAL_TX_BPS},${THERMAL_CPU_TEMP}" >> "$target"

    echo "$target"
}
