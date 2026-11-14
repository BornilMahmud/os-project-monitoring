#!/usr/bin/env bats
# tests/unit/test_graphs.bats

setup() {
    source "$PROJECT_ROOT/core/calculations.sh"
    source "$PROJECT_ROOT/ui/graphs.sh"
}

@test "render_gauge_bar renders proportional filled and empty segments" {
    bar=$(render_gauge_bar 50 10 "ascii")
    # For width 10 at 50%: 5 filled, 5 empty
    [ "$bar" = "[=====-----] 50%" ]

    bar=$(render_gauge_bar 100 10 "ascii")
    [ "$bar" = "[==========] 100%" ]

    bar=$(render_gauge_bar 0 10 "ascii")
    [ "$bar" = "[----------] 0%" ]
}

@test "render_sparkline renders unicode block characters or ascii fallback" {
    data=(0 25 50 75 100)
    spark=$(render_sparkline "blocks" "${data[@]}")
    [ -n "$spark" ]

    spark_ascii=$(render_sparkline "ascii" "${data[@]}")
    [ "$spark_ascii" = "_.-*#" ]
}
