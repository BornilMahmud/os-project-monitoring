#!/usr/bin/env bats
# tests/unit/test_memory_collector.bats

setup() {
    source "$PROJECT_ROOT/core/calculations.sh"
    source "$PROJECT_ROOT/collectors/memory.sh"
}

@test "mem_collect parses total, available, free, cached, and swap correctly" {
    mem_collect "$FIXTURES_DIR/proc/meminfo"

    # In fixture: MemTotal=16777216 kB, MemAvailable=8388608 kB
    # Used = 16777216 - 8388608 = 8388608 kB = 50%
    [ "$MEM_TOTAL_KB" -eq 16777216 ]
    [ "$MEM_AVAIL_KB" -eq 8388608 ]
    [ "$MEM_USED_KB" -eq 8388608 ]
    [ "$MEM_USAGE_PERCENT" -eq 50 ]

    # Swap in fixture: SwapTotal=4194304 kB, SwapFree=2097152 kB -> 50%
    [ "$MEM_SWAP_TOTAL_KB" -eq 4194304 ]
    [ "$MEM_SWAP_FREE_KB" -eq 2097152 ]
    [ "$MEM_SWAP_USED_KB" -eq 2097152 ]
    [ "$MEM_SWAP_PERCENT" -eq 50 ]

    [ "$MEM_BUFFERS_KB" -eq 524288 ]
    [ "$MEM_CACHED_KB" -eq 4194304 ]
}

@test "mem_collect handles missing meminfo gracefully" {
    mem_collect "/nonexistent/proc/meminfo"

    [ "$MEM_TOTAL_KB" -eq 0 ]
    [ "$MEM_USED_KB" -eq 0 ]
    [ "$MEM_USAGE_PERCENT" -eq 0 ]
    [ "$MEM_STATUS" = "UNAVAILABLE" ]
}
