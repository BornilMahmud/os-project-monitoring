#!/usr/bin/env bash
# ui/navigation.sh - Navigation state, tabs, scrolling, and view router for SMD-TUI

UI_CURRENT_TAB=1
UI_TAB_NAME="Overview"
NAV_SCROLL_OFFSET=0
UI_PAUSED="false"
UI_SHOW_HELP="false"

UI_TAB_NAMES=(
    "Overview"
    "CPU"
    "Memory"
    "Processes"
    "Thermals"
    "Storage"
    "Network"
    "Battery"
    "Alerts"
    "Settings"
)

nav_init() {
    UI_CURRENT_TAB=1
    UI_TAB_NAME="${UI_TAB_NAMES[0]}"
    NAV_SCROLL_OFFSET=0
    UI_PAUSED="false"
    UI_SHOW_HELP="false"
}

nav_set_tab() {
    local target="$1"
    if [[ "$target" =~ ^[0-9]+$ ]]; then
        if [[ $target -ge 1 && $target -le 10 ]]; then
            UI_CURRENT_TAB="$target"
            UI_TAB_NAME="${UI_TAB_NAMES[$((target - 1))]}"
            NAV_SCROLL_OFFSET=0
        fi
    fi
}

nav_next_tab() {
    local next=$(( UI_CURRENT_TAB + 1 ))
    if [[ $next -gt 10 ]]; then
        next=1
    fi
    nav_set_tab "$next"
}

nav_prev_tab() {
    local prev=$(( UI_CURRENT_TAB - 1 ))
    if [[ $prev -lt 1 ]]; then
        prev=10
    fi
    nav_set_tab "$prev"
}

nav_scroll_down() {
    local max_items="${1:-100}"
    if [[ $(( NAV_SCROLL_OFFSET + 1 )) -lt $max_items ]]; then
        NAV_SCROLL_OFFSET=$(( NAV_SCROLL_OFFSET + 1 ))
    fi
}

nav_scroll_up() {
    if [[ $NAV_SCROLL_OFFSET -gt 0 ]]; then
        NAV_SCROLL_OFFSET=$(( NAV_SCROLL_OFFSET - 1 ))
    fi
}

nav_scroll_reset() {
    NAV_SCROLL_OFFSET=0
}

nav_toggle_pause() {
    if [[ "$UI_PAUSED" == "true" ]]; then
        UI_PAUSED="false"
    else
        UI_PAUSED="true"
    fi
}

nav_toggle_help() {
    if [[ "$UI_SHOW_HELP" == "true" ]]; then
        UI_SHOW_HELP="false"
    else
        UI_SHOW_HELP="true"
    fi
}
