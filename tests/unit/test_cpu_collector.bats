#!/usr/bin/env bats
# tests/unit/test_cpu_collector.bats

setup() {
    source "$PROJECT_ROOT/core/calculations.sh"
    source "$PROJECT_ROOT/collectors/cpu.sh"
}

@test "cpu_collect_info parses model, cores, and frequency accurately" {
    PROC_CPUINFO="$FIXTURES_DIR/proc/cpuinfo"
    cpu_collect_info "$PROC_CPUINFO"

    [ "$CPU_INFO_MODEL" = "Intel(R) Core(TM) i7-8550U CPU @ 1.80GHz" ]
    [ "$CPU_INFO_CORES" -eq 2 ]
    [ "$CPU_INFO_MHZ" = "1992" ]
}

@test "cpu_collect_load parses 1m, 5m, 15m load and procs" {
    PROC_LOADAVG="$FIXTURES_DIR/proc/loadavg"
    cpu_collect_load "$PROC_LOADAVG"

    [ "$CPU_LOAD_1M" = "0.75" ]
    [ "$CPU_LOAD_5M" = "1.20" ]
    [ "$CPU_LOAD_15M" = "1.05" ]
    [ "$CPU_LOAD_RUNNABLE" -eq 2 ]
    [ "$CPU_LOAD_TOTAL_PROCS" -eq 450 ]
}

@test "cpu_collect_usage calculates delta utilization accurately" {
    # Snapshot 1
    cpu_collect_stat "$FIXTURES_DIR/proc/stat_1"
    # Snapshot 2
    cpu_collect_stat "$FIXTURES_DIR/proc/stat_2"

    # Delta:
    # user=100, nice=20, sys=80, idle=800 -> active=200, idle=800, total=1000 -> 20%
    [ "$CPU_USAGE_TOTAL" -eq 20 ]
    [ "${CPU_USAGE_CORES[0]}" -eq 20 ]
    [ "${CPU_USAGE_CORES[1]}" -eq 20 ]
}

@test "cpu handles missing files gracefully" {
    cpu_collect_info "/nonexistent/proc/cpuinfo"
    [ "$CPU_INFO_MODEL" = "Unknown CPU" ]
    [ "$CPU_INFO_CORES" -ge 1 ]

    cpu_collect_load "/nonexistent/proc/loadavg"
    [ "$CPU_LOAD_1M" = "0.00" ]
}
