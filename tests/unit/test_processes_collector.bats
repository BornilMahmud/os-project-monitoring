#!/usr/bin/env bats
# tests/unit/test_processes_collector.bats

setup() {
    setup_test_env
    source "$PROJECT_ROOT/core/calculations.sh"
    source "$PROJECT_ROOT/collectors/processes.sh"
}

teardown() {
    teardown_test_env
}

@test "process_collect retrieves top CPU and Memory processes" {
    process_collect 10

    [ "${#PROC_CPU_PID[@]}" -ge 1 ]
    [ -n "${PROC_CPU_COMM[0]}" ]
    [ "${#PROC_MEM_PID[@]}" -ge 1 ]
    [ -n "${PROC_MEM_COMM[0]}" ]
}

@test "process_parse_output parses standard ps columns accurately" {
    mock_ps_out="$TEST_TMP_DIR/mock_ps.txt"
    cat << 'EOF' > "$mock_ps_out"
  PID USER     %CPU %MEM COMMAND
 1234 root     25.5  5.0 systemd
 5678 bornil   12.0 15.2 bash
 9999 daemon    2.1  1.0 dbus-daemon
EOF

    process_parse_file "$mock_ps_out" "cpu"

    [ "${#PROC_CPU_PID[@]}" -eq 3 ]
    [ "${PROC_CPU_PID[0]}" -eq 1234 ]
    [ "${PROC_CPU_USER[0]}" = "root" ]
    [ "${PROC_CPU_PCT[0]}" = "25.5" ]
    [ "${PROC_CPU_MEM[0]}" = "5.0" ]
    [ "${PROC_CPU_COMM[0]}" = "systemd" ]

    [ "${PROC_CPU_PID[1]}" -eq 5678 ]
    [ "${PROC_CPU_COMM[1]}" = "bash" ]
}
