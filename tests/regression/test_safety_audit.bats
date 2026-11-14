#!/usr/bin/env bats
# tests/regression/test_safety_audit.bats
# Automated static safety audit verifying strict read-only compliance

setup() {
    # Scan all project source files excluding tests and git directories
    PROJECT_SCRIPTS=()
    while IFS= read -r -d '' f; do
        PROJECT_SCRIPTS+=("$f")
    done < <(find "$PROJECT_ROOT" -maxdepth 3 \( -name "*.sh" -o -name "*.conf" \) -not -path "*/.*/*" -not -path "*/tests/*" -print0)
}

@test "safety: zero sudo usage anywhere in application code" {
    violations=0
    for f in "${PROJECT_SCRIPTS[@]}"; do
        if grep -w "sudo" "$f" 2>/dev/null; then
            echo "Violation in: $f"
            violations=$((violations + 1))
        fi
    done
    [ "$violations" -eq 0 ]
}

@test "safety: zero write operations to /proc or /sys" {
    violations=0
    for f in "${PROJECT_SCRIPTS[@]}"; do
        # Check for redirection patterns like > /proc, >> /sys, tee /proc, tee /sys
        if grep -E '>[[:space:]]*/(proc|sys)' "$f" 2>/dev/null; then
            echo "Write redirection violation in: $f"
            violations=$((violations + 1))
        fi
        if grep -E 'tee[[:space:]]+/(proc|sys)' "$f" 2>/dev/null; then
            echo "Tee write violation in: $f"
            violations=$((violations + 1))
        fi
    done
    [ "$violations" -eq 0 ]
}

@test "safety: zero process kill commands in monitoring code" {
    violations=0
    for f in "${PROJECT_SCRIPTS[@]}"; do
        if grep -E '\b(kill|pkill|killall)\b' "$f" 2>/dev/null; then
            echo "Process kill violation in: $f"
            violations=$((violations + 1))
        fi
    done
    [ "$violations" -eq 0 ]
}

@test "safety: zero destructive system commands (reboot, shutdown, mkfs)" {
    violations=0
    for f in "${PROJECT_SCRIPTS[@]}"; do
        if grep -E '\b(reboot|shutdown|poweroff|halt|mkfs|fdisk|parted)\b' "$f" 2>/dev/null; then
            echo "Destructive command violation in: $f"
            violations=$((violations + 1))
        fi
    done
    [ "$violations" -eq 0 ]
}

@test "safety: only application-owned directories under XDG are created" {
    violations=0
    for f in "${PROJECT_SCRIPTS[@]}"; do
        # Check for mkdir not pointing to variable or XDG/tmp
        if grep -E 'mkdir[[:space:]]+(-p[[:space:]]+)?/(etc|usr|bin|sbin|var|sys|proc|root)' "$f" 2>/dev/null; then
            echo "System directory mkdir violation in: $f"
            violations=$((violations + 1))
        fi
    done
    [ "$violations" -eq 0 ]
}
