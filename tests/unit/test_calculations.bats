#!/usr/bin/env bats
# tests/unit/test_calculations.bats

setup() {
    source "$PROJECT_ROOT/core/calculations.sh"
}

@test "calc_percent calculates accurate integer percentage" {
    result=$(calc_percent 50 100)
    [ "$result" -eq 50 ]

    result=$(calc_percent 1 4)
    [ "$result" -eq 25 ]

    result=$(calc_percent 2 3)
    [ "$result" -eq 66 ]
}

@test "calc_percent handles division by zero safely" {
    result=$(calc_percent 10 0)
    [ "$result" -eq 0 ]
}

@test "calc_rate calculates delta per second safely" {
    # 2048 bytes in 2 seconds = 1024 B/s
    result=$(calc_rate 2048 2)
    [ "$result" -eq 1024 ]

    # Zero elapsed time safeguard
    result=$(calc_rate 2048 0)
    [ "$result" -eq 0 ]
}

@test "format_bytes formats B, KB, MB, GB, TB accurately" {
    run format_bytes 512
    [ "$output" = "512 B" ]

    run format_bytes 1024
    [ "$output" = "1.00 KB" ]

    run format_bytes 1048576
    [ "$output" = "1.00 MB" ]

    run format_bytes 1073741824
    [ "$output" = "1.00 GB" ]

    run format_bytes 1099511627776
    [ "$output" = "1.00 TB" ]
}

@test "format_speed formats bytes per second" {
    run format_speed 500
    [ "$output" = "500 B/s" ]

    run format_speed 204800
    [ "$output" = "200.00 KB/s" ]

    run format_speed 52428800
    [ "$output" = "50.00 MB/s" ]
}

@test "format_duration formats seconds into days hours minutes seconds" {
    run format_duration 45
    [ "$output" = "45s" ]

    run format_duration 125
    [ "$output" = "2m 05s" ]

    run format_duration 3665
    [ "$output" = "1h 01m 05s" ]

    run format_duration 90061
    [ "$output" = "1d 01h 01m 01s" ]
}

@test "clamp restricts values within bounds" {
    result=$(clamp -5 0 100)
    [ "$result" -eq 0 ]

    result=$(clamp 150 0 100)
    [ "$result" -eq 100 ]

    result=$(clamp 42 0 100)
    [ "$result" -eq 42 ]
}
