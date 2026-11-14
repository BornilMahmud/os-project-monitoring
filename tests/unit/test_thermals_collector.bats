#!/usr/bin/env bats
# tests/unit/test_thermals_collector.bats

setup() {
    setup_test_env
    source "$PROJECT_ROOT/core/calculations.sh"
    source "$PROJECT_ROOT/collectors/thermals.sh"
}

teardown() {
    teardown_test_env
}

@test "thermal_collect discovers thermal zones and converts millidegrees" {
    mock_sys="$TEST_TMP_DIR/sys"
    mkdir -p "$mock_sys/class/thermal/thermal_zone0" "$mock_sys/class/thermal/thermal_zone1"

    echo "x86_pkg_temp" > "$mock_sys/class/thermal/thermal_zone0/type"
    echo "52000" > "$mock_sys/class/thermal/thermal_zone0/temp"

    echo "acpitz" > "$mock_sys/class/thermal/thermal_zone1/type"
    echo "48000" > "$mock_sys/class/thermal/thermal_zone1/temp"

    thermal_collect "$mock_sys"

    [ "$THERMAL_STATUS" = "OK" ]
    [ "$THERMAL_COUNT" -eq 2 ]
    [ "$THERMAL_CPU_TEMP" -eq 52 ]
    [ "${THERMAL_NAMES[0]}" = "x86_pkg_temp" ]
    [ "${THERMAL_TEMPS[0]}" -eq 52 ]
    [ "${THERMAL_NAMES[1]}" = "acpitz" ]
    [ "${THERMAL_TEMPS[1]}" -eq 48 ]
}

@test "thermal_collect discovers hwmon fans and temperatures" {
    mock_sys="$TEST_TMP_DIR/sys"
    mkdir -p "$mock_sys/class/hwmon/hwmon0"

    echo "coretemp" > "$mock_sys/class/hwmon/hwmon0/name"
    echo "Package id 0" > "$mock_sys/class/hwmon/hwmon0/temp1_label"
    echo "61000" > "$mock_sys/class/hwmon/hwmon0/temp1_input"
    echo "2400" > "$mock_sys/class/hwmon/hwmon0/fan1_input"

    thermal_collect "$mock_sys"

    [ "$THERMAL_STATUS" = "OK" ]
    [ "$THERMAL_COUNT" -ge 1 ]
    [ "$THERMAL_FAN_COUNT" -eq 1 ]
    [ "${THERMAL_FAN_RPM[0]}" -eq 2400 ]
}

@test "thermal_collect handles virtual or missing sensors gracefully" {
    mock_sys="$TEST_TMP_DIR/sys_empty"
    mkdir -p "$mock_sys"

    thermal_collect "$mock_sys"

    [ "$THERMAL_STATUS" = "UNAVAILABLE" ]
    [ "$THERMAL_COUNT" -eq 0 ]
    [ "$THERMAL_CPU_TEMP" = "N/A" ]
}
