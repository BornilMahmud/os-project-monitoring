#!/usr/bin/env bash
# tests/test_helper.bash - Test helper and mocking environment for SMD-TUI

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$TESTS_DIR/.." && pwd)"
FIXTURES_DIR="$TESTS_DIR/fixtures"

# Setup temporary sandbox for test isolation
setup_test_env() {
    export TEST_TMP_DIR="$(mktemp -d /tmp/smd-tui-test.XXXXXX)"
    export XDG_CONFIG_HOME="$TEST_TMP_DIR/config"
    export XDG_DATA_HOME="$TEST_TMP_DIR/data"
    export XDG_STATE_HOME="$TEST_TMP_DIR/state"
    mkdir -p "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_STATE_HOME"
}

teardown_test_env() {
    if [[ -n "${TEST_TMP_DIR:-}" && -d "$TEST_TMP_DIR" ]]; then
        rm -rf "$TEST_TMP_DIR"
    fi
}
