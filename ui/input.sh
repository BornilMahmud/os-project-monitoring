#!/usr/bin/env bash
# ui/input.sh - Non-blocking keyboard input listener and escape sequence decoder
# Mutates state directly in parent shell without subshell forks.

UI_ACTION="NONE"

# Read a single keypress or escape sequence with timeout
# Sets global variable: UI_ACTION (QUIT, REFRESH, EXPORT, PAUSE, REDRAW, TAB_CHANGED, NONE)
ui_read_input() {
    local timeout="${1:-0.5}"
    local key=""
    UI_ACTION="NONE"

    # Non-blocking read with sub-second timeout
    if read -rsn1 -t "$timeout" key 2>/dev/null; then
        # Check for Escape sequence (Arrow keys, etc.)
        if [[ "$key" == $'\033' ]]; then
            local rest=""
            read -rsn2 -t 0.05 rest 2>/dev/null || true
            case "$rest" in
                "[A") # Up Arrow
                    nav_scroll_up
                    UI_ACTION="REDRAW"
                    ;;
                "[B") # Down Arrow
                    nav_scroll_down 100
                    UI_ACTION="REDRAW"
                    ;;
                "[C") # Right Arrow
                    nav_next_tab
                    UI_ACTION="TAB_CHANGED"
                    ;;
                "[D") # Left Arrow
                    nav_prev_tab
                    UI_ACTION="TAB_CHANGED"
                    ;;
                *)
                    # Lone Escape key quits help or quits app
                    if [[ "$UI_SHOW_HELP" == "true" ]]; then
                        nav_toggle_help
                        UI_ACTION="REDRAW"
                    else
                        UI_ACTION="QUIT"
                    fi
                    ;;
            esac
        else
            case "$key" in
                q|Q)
                    UI_ACTION="QUIT"
                    ;;
                r|R)
                    UI_ACTION="REFRESH"
                    ;;
                p|P)
                    nav_toggle_pause
                    UI_ACTION="PAUSE"
                    ;;
                e|E)
                    UI_ACTION="EXPORT"
                    ;;
                h|H|\?)
                    nav_toggle_help
                    UI_ACTION="REDRAW"
                    ;;
                $'\t') # Tab key
                    nav_next_tab
                    UI_ACTION="TAB_CHANGED"
                    ;;
                [1-9])
                    nav_set_tab "$key"
                    UI_ACTION="TAB_CHANGED"
                    ;;
                0)
                    nav_set_tab 10
                    UI_ACTION="TAB_CHANGED"
                    ;;
                j|J)
                    nav_scroll_down 100
                    UI_ACTION="REDRAW"
                    ;;
                k|K)
                    nav_scroll_up
                    UI_ACTION="REDRAW"
                    ;;
            esac
        fi
    fi
}
