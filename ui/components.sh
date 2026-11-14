#!/usr/bin/env bash
# ui/components.sh - ANSI color themes, box drawing, and terminal controls for SMD-TUI

# Default ANSI escape codes
C_RESET="\033[0m"
C_BOLD="\033[1m"
C_DIM="\033[2m"
C_REV="\033[7m"

C_PRIMARY="\033[0;36m"   # Cyan
C_ACCENT="\033[1;34m"    # Bold Blue
C_WARN="\033[1;33m"      # Yellow
C_CRIT="\033[1;31m"      # Bold Red
C_GOOD="\033[0;32m"      # Green
C_MUTED="\033[0;37m"     # Light gray
C_BG_CARD=""

TERM_ROWS=24
TERM_COLS=80

# Apply color theme
ui_theme_apply() {
    local theme="${1:-default}"

    case "$theme" in
        cyan)
            C_PRIMARY="\033[1;36m"
            C_ACCENT="\033[0;36m"
            C_WARN="\033[1;33m"
            C_CRIT="\033[1;31m"
            C_GOOD="\033[1;32m"
            C_MUTED="\033[0;37m"
            ;;
        green)
            C_PRIMARY="\033[1;32m"
            C_ACCENT="\033[0;32m"
            C_WARN="\033[1;33m"
            C_CRIT="\033[1;31m"
            C_GOOD="\033[1;32m"
            C_MUTED="\033[0;37m"
            ;;
        amber)
            C_PRIMARY="\033[1;33m"
            C_ACCENT="\033[0;33m"
            C_WARN="\033[1;31m"
            C_CRIT="\033[1;31m"
            C_GOOD="\033[1;32m"
            C_MUTED="\033[0;37m"
            ;;
        monochrome)
            C_RESET=""
            C_BOLD=""
            C_DIM=""
            C_REV=""
            C_PRIMARY=""
            C_ACCENT=""
            C_WARN=""
            C_CRIT=""
            C_GOOD=""
            C_MUTED=""
            ;;
        default|*)
            C_PRIMARY="\033[0;36m"
            C_ACCENT="\033[1;34m"
            C_WARN="\033[1;33m"
            C_CRIT="\033[1;31m"
            C_GOOD="\033[0;32m"
            C_MUTED="\033[0;37m"
            ;;
    esac
}

# Query current terminal dimensions
ui_get_term_size() {
    if command -v tput >/dev/null 2>&1; then
        TERM_COLS=$(tput cols 2>/dev/null || echo 80)
        TERM_ROWS=$(tput lines 2>/dev/null || echo 24)
    else
        TERM_COLS="${COLUMNS:-80}"
        TERM_ROWS="${LINES:-24}"
    fi

    if [[ $TERM_COLS -lt 80 ]]; then TERM_COLS=80; fi
    if [[ $TERM_ROWS -lt 24 ]]; then TERM_ROWS=24; fi
}

# Initialize terminal screen buffer (saves screen, hides cursor)
ui_init_term() {
    if command -v tput >/dev/null 2>&1; then
        tput smcup 2>/dev/null || true
        tput civis 2>/dev/null || true
        tput clear 2>/dev/null || true
    fi
    stty -echo 2>/dev/null || true
    ui_get_term_size
}

# Cleanly restore terminal settings on exit or trap
ui_restore_term() {
    if command -v tput >/dev/null 2>&1; then
        tput cnorm 2>/dev/null || true
        tput rmcup 2>/dev/null || true
        tput sgr0 2>/dev/null || true
    fi
    stty echo 2>/dev/null || true
}

# Move cursor to row, col (1-indexed)
ui_cursor() {
    local r="$1"
    local c="$2"
    printf "\033[%d;%dH" "$r" "$c"
}

# Truncate or pad string to exact length
ui_format_str() {
    local str="$1"
    local max_len="$2"
    if [[ ${#str} -gt $max_len ]]; then
        echo "${str:0:$((max_len - 1))}…"
    else
        printf "%-${max_len}s" "$str"
    fi
}
