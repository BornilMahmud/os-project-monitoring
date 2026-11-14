#!/usr/bin/env bash
# config/loader.sh - Safe configuration loader and validator for SMD-TUI
# Strictly avoids eval/source on user-supplied configuration files.

# Global configuration variables with secure built-in defaults
CFG_REFRESH_INTERVAL=2
CFG_THEME="default"
CFG_CPU_ALERT_THRESHOLD=85
CFG_MEM_ALERT_THRESHOLD=90
CFG_TEMP_ALERT_THRESHOLD=80
CFG_DISK_ALERT_THRESHOLD=90
CFG_HISTORY_RETENTION=60
CFG_GRAPH_STYLE="braille"
CFG_ENABLE_ALERTS="true"
CFG_LOG_LEVEL="info"

# XDG Standard Directories
smd_init_xdg() {
    export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
    export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
    export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

    SMD_CONFIG_DIR="$XDG_CONFIG_HOME/smd-tui"
    SMD_DATA_DIR="$XDG_DATA_HOME/smd-tui"
    SMD_STATE_DIR="$XDG_STATE_HOME/smd-tui"
    SMD_EXPORT_DIR="$SMD_DATA_DIR/exports"
    SMD_REPORT_DIR="$SMD_DATA_DIR/reports"

    # Only create application-owned directories
    mkdir -p "$SMD_CONFIG_DIR" "$SMD_DATA_DIR" "$SMD_STATE_DIR" "$SMD_EXPORT_DIR" "$SMD_REPORT_DIR" 2>/dev/null || true
}

# Validate and apply a single key-value configuration pair safely
config_set_validated() {
    local key="$1"
    local val="$2"

    # Strict regex: keys must be alphanumeric/underscores; values cannot contain semicolons, backticks, $, parens
    if [[ ! "$key" =~ ^[A-Z0-9_]+$ ]]; then
        return 1
    fi

    # Disallow command substitution, subshells, chaining
    if [[ "$val" =~ [\;\|\&\`\$\(\)\<\>\{\}] ]]; then
        return 1
    fi

    case "$key" in
        REFRESH_INTERVAL)
            if [[ "$val" =~ ^[0-9]+$ ]] && [[ "$val" -ge 1 && "$val" -le 3600 ]]; then
                CFG_REFRESH_INTERVAL="$val"
            fi
            ;;
        THEME)
            case "$val" in
                default|cyan|green|amber|monochrome)
                    CFG_THEME="$val"
                    ;;
            esac
            ;;
        CPU_ALERT_THRESHOLD)
            if [[ "$val" =~ ^[0-9]+$ ]] && [[ "$val" -ge 1 && "$val" -le 100 ]]; then
                CFG_CPU_ALERT_THRESHOLD="$val"
            fi
            ;;
        MEM_ALERT_THRESHOLD)
            if [[ "$val" =~ ^[0-9]+$ ]] && [[ "$val" -ge 1 && "$val" -le 100 ]]; then
                CFG_MEM_ALERT_THRESHOLD="$val"
            fi
            ;;
        TEMP_ALERT_THRESHOLD)
            if [[ "$val" =~ ^[0-9]+$ ]] && [[ "$val" -ge 1 && "$val" -le 120 ]]; then
                CFG_TEMP_ALERT_THRESHOLD="$val"
            fi
            ;;
        DISK_ALERT_THRESHOLD)
            if [[ "$val" =~ ^[0-9]+$ ]] && [[ "$val" -ge 1 && "$val" -le 100 ]]; then
                CFG_DISK_ALERT_THRESHOLD="$val"
            fi
            ;;
        HISTORY_RETENTION)
            if [[ "$val" =~ ^[0-9]+$ ]] && [[ "$val" -ge 10 && "$val" -le 3600 ]]; then
                CFG_HISTORY_RETENTION="$val"
            fi
            ;;
        GRAPH_STYLE)
            case "$val" in
                braille|blocks|ascii)
                    CFG_GRAPH_STYLE="$val"
                    ;;
            esac
            ;;
        ENABLE_ALERTS)
            case "$val" in
                true|false|yes|no|1|0)
                    if [[ "$val" == "true" || "$val" == "yes" || "$val" == "1" ]]; then
                        CFG_ENABLE_ALERTS="true"
                    else
                        CFG_ENABLE_ALERTS="false"
                    fi
                    ;;
            esac
            ;;
        LOG_LEVEL)
            case "$val" in
                info|warn|error)
                    CFG_LOG_LEVEL="$val"
                    ;;
            esac
            ;;
    esac
}

# Parse a file safely without source or eval
config_load_file() {
    local file="$1"
    if [[ ! -f "$file" || ! -r "$file" ]]; then
        return 1
    fi

    while IFS= read -r line || [[ -n "$line" ]]; do
        # Trim leading/trailing whitespace
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"

        # Ignore empty lines and comments
        if [[ -z "$line" || "$line" =~ ^# ]]; then
            continue
        fi

        # Match KEY=VALUE
        if [[ "$line" =~ ^([A-Za-z0-9_]+)[[:space:]]*=[[:space:]]*(.*)$ ]]; then
            local k="${BASH_REMATCH[1]}"
            local v="${BASH_REMATCH[2]}"
            # Strip matching quotes if present
            if [[ "$v" =~ ^\"(.*)\"$ ]] || [[ "$v" =~ ^\'(.*)\'$ ]]; then
                v="${BASH_REMATCH[1]}"
            fi
            config_set_validated "$k" "$v" || true
        fi
    done < "$file"
}

# Initialize configuration hierarchy:
# 1. defaults.conf
# 2. $XDG_CONFIG_HOME/smd-tui/config.conf (if exists)
# 3. optional custom config file
config_init() {
    local default_file="${1:-}"
    local custom_file="${2:-}"

    smd_init_xdg

    # 1. Load project defaults if available
    if [[ -n "$default_file" && -f "$default_file" ]]; then
        config_load_file "$default_file"
    fi

    # 2. Load user config if exists
    local user_cfg="$XDG_CONFIG_HOME/smd-tui/config.conf"
    if [[ -f "$user_cfg" ]]; then
        config_load_file "$user_cfg"
    fi

    # 3. Load custom specified config file
    if [[ -n "$custom_file" && -f "$custom_file" ]]; then
        config_load_file "$custom_file"
    fi
}
