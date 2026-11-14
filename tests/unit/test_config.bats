#!/usr/bin/env bats
# tests/unit/test_config.bats

setup() {
    setup_test_env
    source "$PROJECT_ROOT/config/loader.sh"
}

teardown() {
    teardown_test_env
}

@test "config_init loads defaults correctly" {
    config_init "$PROJECT_ROOT/config/defaults.conf"

    [ "$CFG_REFRESH_INTERVAL" -eq 2 ]
    [ "$CFG_THEME" = "default" ]
    [ "$CFG_CPU_ALERT_THRESHOLD" -eq 85 ]
    [ "$CFG_MEM_ALERT_THRESHOLD" -eq 90 ]
    [ "$CFG_TEMP_ALERT_THRESHOLD" -eq 80 ]
    [ "$CFG_DISK_ALERT_THRESHOLD" -eq 90 ]
    [ "$CFG_HISTORY_RETENTION" -eq 60 ]
    [ "$CFG_GRAPH_STYLE" = "braille" ]
    [ "$CFG_ENABLE_ALERTS" = "true" ]
}

@test "config_load_file overrides defaults safely" {
    config_init "$PROJECT_ROOT/config/defaults.conf"

    custom_cfg="$TEST_TMP_DIR/custom.conf"
    cat << 'EOF' > "$custom_cfg"
REFRESH_INTERVAL=5
THEME=cyan
CPU_ALERT_THRESHOLD=75
GRAPH_STYLE=ascii
ENABLE_ALERTS=false
EOF

    config_load_file "$custom_cfg"

    [ "$CFG_REFRESH_INTERVAL" -eq 5 ]
    [ "$CFG_THEME" = "cyan" ]
    [ "$CFG_CPU_ALERT_THRESHOLD" -eq 75 ]
    [ "$CFG_GRAPH_STYLE" = "ascii" ]
    [ "$CFG_ENABLE_ALERTS" = "false" ]
}

@test "config_load_file strictly rejects shell injection and commands" {
    config_init "$PROJECT_ROOT/config/defaults.conf"

    malicious_cfg="$TEST_TMP_DIR/malicious.conf"
    cat << 'EOF' > "$malicious_cfg"
REFRESH_INTERVAL=2; touch /tmp/smd_hacked_marker
THEME=$(touch /tmp/smd_hacked_marker2)
CPU_ALERT_THRESHOLD=80 `touch /tmp/smd_hacked_marker3`
EOF

    config_load_file "$malicious_cfg"

    # Verify no malicious commands executed
    [ ! -f "/tmp/smd_hacked_marker" ]
    [ ! -f "/tmp/smd_hacked_marker2" ]
    [ ! -f "/tmp/smd_hacked_marker3" ]

    # Values must remain unchanged or fallback safely
    [ "$CFG_REFRESH_INTERVAL" -eq 2 ]
    [ "$CFG_THEME" = "default" ]
    [ "$CFG_CPU_ALERT_THRESHOLD" -eq 85 ]
}

@test "config_load_file validates numeric bounds" {
    config_init "$PROJECT_ROOT/config/defaults.conf"

    invalid_cfg="$TEST_TMP_DIR/invalid.conf"
    cat << 'EOF' > "$invalid_cfg"
REFRESH_INTERVAL=0
CPU_ALERT_THRESHOLD=150
MEM_ALERT_THRESHOLD=-10
THEME=unknown_invalid_theme
EOF

    config_load_file "$invalid_cfg"

    # Out of bounds values must be ignored and fallback to defaults
    [ "$CFG_REFRESH_INTERVAL" -eq 2 ]
    [ "$CFG_CPU_ALERT_THRESHOLD" -eq 85 ]
    [ "$CFG_MEM_ALERT_THRESHOLD" -eq 90 ]
    [ "$CFG_THEME" = "default" ]
}

@test "config_init ensures XDG directories exist" {
    config_init "$PROJECT_ROOT/config/defaults.conf"

    [ -d "$XDG_CONFIG_HOME/smd-tui" ]
    [ -d "$XDG_DATA_HOME/smd-tui" ]
    [ -d "$XDG_STATE_HOME/smd-tui" ]
}
