#!/usr/bin/env bats
# tests/unit/test_network_collector.bats

setup() {
    source "$PROJECT_ROOT/core/calculations.sh"
    source "$PROJECT_ROOT/collectors/network.sh"
}

@test "network_collect_dev calculates interface download and upload speeds" {
    # Snapshot 1 at t=1000
    network_collect_dev "$FIXTURES_DIR/proc/net_dev_1" 1000
    # Snapshot 2 at t=1001 (1 sec elapsed)
    network_collect_dev "$FIXTURES_DIR/proc/net_dev_2" 1001

    # In fixture: eth0 delta rx=1048576, tx=524288
    # Total non-loopback RX = 1048576 B/s, TX = 524288 B/s
    [ "$NET_TOTAL_RX_BPS" -eq 1048576 ]
    [ "$NET_TOTAL_TX_BPS" -eq 524288 ]

    # Verify eth0 specific entry
    [ "$NET_ETH0_RX_BPS" -eq 1048576 ]
    [ "$NET_ETH0_TX_BPS" -eq 524288 ]
}

@test "network handles missing net_dev gracefully" {
    network_collect_dev "/nonexistent/proc/net/dev" 1000
    [ "$NET_TOTAL_RX_BPS" -eq 0 ]
    [ "$NET_TOTAL_TX_BPS" -eq 0 ]
    [ "$NET_STATUS" = "UNAVAILABLE" ]
}
