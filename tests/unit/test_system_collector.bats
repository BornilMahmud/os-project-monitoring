#!/usr/bin/env bats
# tests/unit/test_system_collector.bats

setup() {
    setup_test_env
    source "$PROJECT_ROOT/core/calculations.sh"
    source "$PROJECT_ROOT/collectors/system.sh"
}

teardown() {
    teardown_test_env
}

@test "system_collect_os parses distro name, version, and pretty name" {
    system_collect_os "$FIXTURES_DIR/etc/os-release"

    [ "$SYS_DISTRO_NAME" = "Ubuntu" ]
    [ "$SYS_DISTRO_VERSION" = "24.04.1 LTS (Noble Numbat)" ]
    [ "$SYS_DISTRO_PRETTY" = "Ubuntu 24.04.1 LTS" ]
}

@test "system_collect_uptime parses seconds and formats uptime" {
    mock_uptime="$TEST_TMP_DIR/mock_uptime"
    mkdir -p "$TEST_TMP_DIR"
    echo "90061.25 180000.50" > "$mock_uptime"

    system_collect_uptime "$mock_uptime"

    [ "$SYS_UPTIME_SEC" -eq 90061 ]
    [ "$SYS_UPTIME_PRETTY" = "1d 01h 01m 01s" ]
    rm -f "$mock_uptime"
}

@test "system_collect populates hostname, architecture, and kernel" {
    system_collect

    [ -n "$SYS_HOSTNAME" ]
    [ -n "$SYS_KERNEL" ]
    [ -n "$SYS_ARCH" ]
}
