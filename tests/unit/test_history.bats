#!/usr/bin/env bats
# tests/unit/test_history.bats

setup() {
    source "$PROJECT_ROOT/core/calculations.sh"
    source "$PROJECT_ROOT/core/history.sh"
}

@test "history_init initializes buffers with specified retention" {
    history_init 10
    [ "$HIST_RETENTION" -eq 10 ]
}

@test "history_push and get_series maintains chronological order and evicts oldest" {
    history_init 3

    history_push "cpu" 10
    history_push "cpu" 20
    history_push "cpu" 30

    series=($(history_get_series "cpu"))
    [ "${series[0]}" -eq 10 ]
    [ "${series[1]}" -eq 20 ]
    [ "${series[2]}" -eq 30 ]

    # Push 4th item: 10 should be evicted, [20, 30, 40]
    history_push "cpu" 40
    series=($(history_get_series "cpu"))
    [ "${#series[@]}" -eq 3 ]
    [ "${series[0]}" -eq 20 ]
    [ "${series[1]}" -eq 30 ]
    [ "${series[2]}" -eq 40 ]
}

@test "history stats calculates min, max, and average accurately" {
    history_init 5

    history_push "mem" 20
    history_push "mem" 80
    history_push "mem" 50

    [ "$(history_get_min "mem")" -eq 20 ]
    [ "$(history_get_max "mem")" -eq 80 ]
    [ "$(history_get_avg "mem")" -eq 50 ]
}
