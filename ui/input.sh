#!/usr/bin/env bash
# ui/input.sh - Non-blocking keyboard input listener and escape sequence decoder

# Read a single keypress or escape sequence with timeout
# Returns action string via echo: QUIT, REFRESH, EXPORT, PAUSE, REDRAW, NONE
ui_read_input() {
    local timeout="${1:-0.5}"
    local key=""
    local action="NONE"

    # Non-blocking read with sub-second timeout
    if read -rsn1 -t "$timeout" key 2>/dev/null; then
        # Check for Escape sequence (Arrow keys, etc.)
        if [[ "$key" == $'\033' ]]; then
            local rest=""
            read -rsn2 -t 0.05 rest 2>/dev/null || true
            case "$rest" in
                "[A") # Up Arrow
                    nav_scroll_up
                    action="REDRAW"
                    ;;
                "[B") # Down Arrow
                    nav_scroll_down 100
                    action="REDRAW"
                    ;;
                "[C") # Right Arrow
                    nav_next_tab
                    action="TAB_CHANGED"
                    ;;
                "[D") # Left Arrow
                    nav_prev_tab
                    action="TAB_CHANGED"
                    ;;
                *)
                    # Lone Escape key quits help or quits app
                    if [[ "$UI_SHOW_HELP" == "true" ]]; then
                        nav_toggle_help
                        action="REDRAW"
                    else
                        action="QUIT"
                    fi
                    ;;
            esac
        else
            case "$key" in
                q|Q)
                    action="QUIT"
                    ;;
                r|R)
                    action="REFRESH"
                    ;;
                p|P)
                    nav_toggle_pause
                    action="PAUSE"
                    ;;
                e|E)
                    action="EXPORT"
                    ;;
                h|H|\?)
                    nav_toggle_help
                    action="REDRAW"
                    ;;
                $'\t') # Tab key
                    nav_next_tab
                    action="TAB_CHANGED"
                    ;;
                [1-9])
                    nav_set_tab "$key"
                    action="TAB_CHANGED"
                    ;;
                0)
                    nav_set_tab 10
                    action="TAB_CHANGED"
                    ;;
                j|J)
                    nav_scroll_down 100
                    action="REDRAW"
                    ;;
                k|K)
                    nav_scroll_up
                    action="REDRAW"
                    ;;
            esac
        fi
    fi

    echo "$action"
}
