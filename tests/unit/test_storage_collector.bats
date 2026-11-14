#!/usr/bin/env bats
# tests/unit/test_storage_collector.bats

setup() {
    source "$PROJECT_ROOT/core/calculations.sh"
    source "$PROJECT_ROOT/collectors/storage.sh"
}

@test "storage_parse_diskstats calculates disk I/O delta rates" {
    # Snapshot 1
    storage_collect_io "$FIXTURES_DIR/proc/diskstats_1" 1000
    # Snapshot 2 (1 second later = 1001)
    storage_collect_io "$FIXTURES_DIR/proc/diskstats_2" 1001

    # sda read delta: 4000 sectors * 512 = 2048000 B/s
    # sda write delta: 2000 sectors * 512 = 1024000 B/s
    [ "$STORAGE_TOTAL_READ_BPS" -eq 2048000 ]
    [ "$STORAGE_TOTAL_WRITE_BPS" -eq 1024000 ]
}

@test "storage_collect_filesystems populates filesystem arrays" {
    storage_collect_filesystems

    # Real or test system should have at least 1 filesystem mount
    [ "${#STORAGE_FS_MOUNT[@]}" -ge 1 ]
    [ -n "${STORAGE_FS_DEVICE[0]}" ]
    [ "${STORAGE_FS_PERCENT[0]}" -ge 0 ]
    [ "${STORAGE_FS_PERCENT[0]}" -le 100 ]
}

@test "storage handles missing diskstats gracefully" {
    storage_collect_io "/nonexistent/proc/diskstats" 1000
    [ "$STORAGE_TOTAL_READ_BPS" -eq 0 ]
    [ "$STORAGE_TOTAL_WRITE_BPS" -eq 0 ]
}
