#!/usr/bin/env bats
# tests/unit/test_ui_components.bats

setup() {
    source "$PROJECT_ROOT/core/calculations.sh"
    source "$PROJECT_ROOT/config/loader.sh"
    source "$PROJECT_ROOT/ui/components.sh"
    source "$PROJECT_ROOT/ui/navigation.sh"
    source "$PROJECT_ROOT/ui/input.sh"
    config_init "$PROJECT_ROOT/config/defaults.conf"
}

@test "ui_theme_apply sets theme color variables" {
    ui_theme_apply "cyan"
    [ -n "$C_PRIMARY" ]
    [ -n "$C_ACCENT" ]

    ui_theme_apply "monochrome"
    [ "$C_PRIMARY" = "" ]
    [ "$C_ACCENT" = "" ]
}

@test "navigation functions switch tabs and clamp bounds" {
    nav_set_tab 1
    [ "$UI_CURRENT_TAB" -eq 1 ]

    nav_next_tab
    [ "$UI_CURRENT_TAB" -eq 2 ]

    nav_prev_tab
    [ "$UI_CURRENT_TAB" -eq 1 ]

    # Prev from 1 wraps or clamps
    nav_prev_tab
    [ "$UI_CURRENT_TAB" -ge 1 ]

    # Tab 10
    nav_set_tab 10
    [ "$UI_CURRENT_TAB" -eq 10 ]
    [ "$UI_TAB_NAME" = "Settings" ]
}

@test "navigation scrolling increments and clamps" {
    nav_scroll_reset
    [ "$NAV_SCROLL_OFFSET" -eq 0 ]

    nav_scroll_down 20
    [ "$NAV_SCROLL_OFFSET" -eq 1 ]

    nav_scroll_up
    [ "$NAV_SCROLL_OFFSET" -eq 0 ]

    # Clamps at 0
    nav_scroll_up
    [ "$NAV_SCROLL_OFFSET" -eq 0 ]
}

@test "ui_read_input updates navigation state in current shell without subshell" {
    nav_set_tab 1
    # Feed key '2' directly to ui_read_input via here-string (no pipeline subshell)
    ui_read_input 0.1 <<< "2"

    [ "$UI_ACTION" = "TAB_CHANGED" ]
    [ "$UI_CURRENT_TAB" -eq 2 ]

    # Feed key 'p' to toggle pause
    ui_read_input 0.1 <<< "p"
    [ "$UI_ACTION" = "PAUSE" ]
    [ "$UI_PAUSED" = "true" ]
}
