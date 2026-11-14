#!/usr/bin/env bats
# tests/unit/test_battery_collector.bats

setup() {
    setup_test_env
    source "$PROJECT_ROOT/core/calculations.sh"
    source "$PROJECT_ROOT/collectors/battery.sh"
}

teardown() {
    teardown_test_env
}

@test "battery_collect discovers battery percentage and status" {
    mock_sys="$TEST_TMP_DIR/sys"
    mkdir -p "$mock_sys/class/power_supply/BAT0"

    echo "Battery" > "$mock_sys/class/power_supply/BAT0/type"
    echo "85" > "$mock_sys/class/power_supply/BAT0/capacity"
    echo "Discharging" > "$mock_sys/class/power_supply/BAT0/status"
    echo "Good" > "$mock_sys/class/power_supply/BAT0/health"
    echo "Li-poly" > "$mock_sys/class/power_supply/BAT0/technology"

    battery_collect "$mock_sys"

    [ "$BATTERY_PRESENT" = "true" ]
    [ "$BATTERY_PERCENT" -eq 85 ]
    [ "$BATTERY_STATUS" = "Discharging" ]
    [ "$BATTERY_HEALTH" = "Good" ]
    [ "$BATTERY_TECH" = "Li-poly" ]
}

@test "battery_collect handles desktop / VM environment without battery gracefully" {
    mock_sys="$TEST_TMP_DIR/sys_empty"
    mkdir -p "$mock_sys"

    battery_collect "$mock_sys"

    [ "$BATTERY_PRESENT" = "false" ]
    [ "$BATTERY_PERCENT" = "N/A" ]
    [ "$BATTERY_STATUS" = "Not Present / AC" ]
}
