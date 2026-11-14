#!/usr/bin/env bats
# tests/unit/test_alerts.bats

setup() {
    source "$PROJECT_ROOT/core/calculations.sh"
    source "$PROJECT_ROOT/config/loader.sh"
    source "$PROJECT_ROOT/core/alerts.sh"
    config_init "$PROJECT_ROOT/config/defaults.conf"
    alerts_init
}

@test "alerts_evaluate triggers alert when threshold exceeded" {
    # Default CPU threshold is 85%
    alerts_evaluate 92 50 "N/A" 40

    [ "$ALERTS_ACTIVE_COUNT" -ge 1 ]
    [ "${ALERT_METRIC[0]}" = "CPU" ]
    [ "${ALERT_LEVEL[0]}" = "WARNING" ]
    [ "${ALERT_VALUE[0]}" = "92%" ]
}

@test "alerts_evaluate does not trigger when metrics are normal" {
    alerts_evaluate 25 40 "N/A" 50

    [ "$ALERTS_ACTIVE_COUNT" -eq 0 ]
}

@test "alerts_evaluate handles N/A temperature without false alert" {
    alerts_evaluate 10 20 "N/A" 30

    [ "$ALERTS_ACTIVE_COUNT" -eq 0 ]
}
