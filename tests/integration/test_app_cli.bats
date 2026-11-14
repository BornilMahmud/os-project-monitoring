#!/usr/bin/env bats
# tests/integration/test_app_cli.bats

setup() {
    setup_test_env
}

teardown() {
    teardown_test_env
}

@test "app.sh --help displays usage guide and exits with code 0" {
    run bash "$PROJECT_ROOT/app.sh" --help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "SMD-TUI 2.0" ]]
    [[ "$output" =~ "Usage:" ]]
}

@test "app.sh --version displays version and exits with code 0" {
    run bash "$PROJECT_ROOT/app.sh" --version
    [ "$status" -eq 0 ]
    [[ "$output" =~ "2.0" ]]
}

@test "app.sh --check-deps verifies system utilities" {
    run bash "$PROJECT_ROOT/app.sh" --check-deps
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Dependency Check" ]]
}

@test "app.sh headless export generates valid report file" {
    out_file="$TEST_TMP_DIR/test_report.txt"
    run bash "$PROJECT_ROOT/app.sh" --export-report "$out_file"
    [ "$status" -eq 0 ]
    [ -f "$out_file" ]
    [ -s "$out_file" ]

    # Verify report content
    grep -q "SMD-TUI 2.0 System Intelligence Report" "$out_file"
    grep -q "CPU METRICS" "$out_file"
    grep -q "MEMORY & SWAP" "$out_file"
}

@test "app.sh headless export generates valid CSV metrics file" {
    out_csv="$TEST_TMP_DIR/test_metrics.csv"
    run bash "$PROJECT_ROOT/app.sh" --export-csv "$out_csv"
    [ "$status" -eq 0 ]
    [ -f "$out_csv" ]
    [ -s "$out_csv" ]

    # Verify CSV header
    grep -q "Timestamp,CPU_Usage,RAM_Used_MB" "$out_csv"
}
