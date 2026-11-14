#!/usr/bin/env bash
# ui/components.sh - ANSI color themes, box drawing, and terminal controls for SMD-TUI

# Default ANSI escape codes
C_RESET="\033[0m"
C_BOLD="\033[1m"
C_DIM="\033[38;5;242m"
C_REV="\033[7m"

C_PRIMARY="\033[38;5;45m"     # Modern Sky Cyan
C_ACCENT="\033[38;5;75m"      # Azure Blue
C_BORDER="\033[38;5;67m"      # Soft Slate Blue
C_WARN="\033[38;5;215m"       # Soft Warm Amber
C_CRIT="\033[38;5;203m"       # Coral Red
C_GOOD="\033[38;5;78m"        # Emerald Mint
C_MUTED="\033[38;5;246m"      # Slate Gray
C_TEXT="\033[38;5;255m"       # Crisp White
C_CARD_HEAD="\033[38;5;153m\033[1m" # Light Ice Blue Bold

TERM_ROWS=24
TERM_COLS=80
BOX_WIDTH=78

# Apply color theme
ui_theme_apply() {
    local theme="${1:-default}"

    case "$theme" in
        cyan)
            C_PRIMARY="\033[38;5;51m"
            C_ACCENT="\033[38;5;45m"
            C_BORDER="\033[38;5;37m"
            C_WARN="\033[38;5;215m"
            C_CRIT="\033[38;5;203m"
            C_GOOD="\033[38;5;78m"
            C_MUTED="\033[38;5;246m"
            C_TEXT="\033[38;5;255m"
            C_CARD_HEAD="\033[38;5;51m\033[1m"
            ;;
        green)
            C_PRIMARY="\033[38;5;42m"
            C_ACCENT="\033[38;5;36m"
            C_BORDER="\033[38;5;29m"
            C_WARN="\033[38;5;215m"
            C_CRIT="\033[38;5;203m"
            C_GOOD="\033[38;5;78m"
            C_MUTED="\033[38;5;246m"
            C_TEXT="\033[38;5;255m"
            C_CARD_HEAD="\033[38;5;120m\033[1m"
            ;;
        amber)
            C_PRIMARY="\033[38;5;215m"
            C_ACCENT="\033[38;5;208m"
            C_BORDER="\033[38;5;130m"
            C_WARN="\033[38;5;220m"
            C_CRIT="\033[38;5;203m"
            C_GOOD="\033[38;5;78m"
            C_MUTED="\033[38;5;246m"
            C_TEXT="\033[38;5;255m"
            C_CARD_HEAD="\033[38;5;222m\033[1m"
            ;;
        monochrome)
            C_RESET=""
            C_BOLD=""
            C_DIM=""
            C_REV=""
            C_PRIMARY=""
            C_ACCENT=""
            C_BORDER=""
            C_WARN=""
            C_CRIT=""
            C_GOOD=""
            C_MUTED=""
            C_TEXT=""
            C_CARD_HEAD=""
            ;;
        default|*)
            C_PRIMARY="\033[38;5;45m"
            C_ACCENT="\033[38;5;75m"
            C_BORDER="\033[38;5;67m"
            C_WARN="\033[38;5;215m"
            C_CRIT="\033[38;5;203m"
            C_GOOD="\033[38;5;78m"
            C_MUTED="\033[38;5;246m"
            C_TEXT="\033[38;5;255m"
            C_CARD_HEAD="\033[38;5;153m\033[1m"
            ;;
    esac
}

# Generate repeated character string
ui_repeat() {
    local ch="${1:-─}"
    local count="${2:-1}"
    local res=""
    for ((k=0; k<count; k++)); do res="${res}${ch}"; done
    printf "%s" "$res"
}

# Query current terminal dimensions and adapt box width
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

    if [[ $TERM_COLS -ge 110 ]]; then
        BOX_WIDTH=104
    elif [[ $TERM_COLS -ge 94 ]]; then
        BOX_WIDTH=90
    else
        BOX_WIDTH=78
    fi
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
