#!/usr/bin/env bash
# tests/run_tests.sh - Test runner for SMD-TUI
# Supports standalone execution and bats-core delegation

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ANSI Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# Run ShellCheck if installed
run_shellcheck() {
    echo -e "${BLUE}${BOLD}[1/2] Checking Bash syntax & ShellCheck...${NC}"
    local files=()
    while IFS= read -r -d '' f; do
        files+=("$f")
    done < <(find "$PROJECT_ROOT" -maxdepth 4 -name "*.sh" -not -path "*/.*/*" -print0)

    local err_count=0
    for f in "${files[@]}"; do
        if ! bash -n "$f"; then
            echo -e "  ${RED}✗ Syntax error in: $f${NC}"
            err_count=$((err_count + 1))
        fi
    done

    if command -v shellcheck >/dev/null 2>&1; then
        echo "  Running shellcheck on all scripts..."
        for f in "${files[@]}"; do
            if ! shellcheck -x "$f"; then
                echo -e "  ${RED}✗ ShellCheck warning/error in: $f${NC}"
                err_count=$((err_count + 1))
            fi
        done
    else
        echo "  (shellcheck not installed in current environment; bash -n syntax checks passed)"
    fi

    if [[ $err_count -gt 0 ]]; then
        echo -e "${RED}${BOLD}Syntax checks failed with $err_count errors.${NC}"
        return 1
    fi
    echo -e "  ${GREEN}✓ All syntax checks passed.${NC}"
}

# Standalone BATS-compatible runner for environments without bats-core
run_bats_file() {
    local test_file="$1"
    local rel_file="${test_file#"$PROJECT_ROOT/"}"
    echo -e "\n${BOLD}Running: ${rel_file}${NC}"

    # Extract all test names and bodies
    local total=0
    local passed=0
    local failed=0

    # Source the test file inside a subshell for each test
    local test_names=()
    while IFS= read -r line; do
        if [[ "$line" =~ ^@test[[:space:]]+\"([^\"]+)\" ]]; then
            test_names+=("${BASH_REMATCH[1]}")
        elif [[ "$line" =~ ^@test[[:space:]]+\'([^\']+)\' ]]; then
            test_names+=("${BASH_REMATCH[1]}")
        fi
    done < "$test_file"

    for tname in "${test_names[@]}"; do
        total=$((total + 1))
        local output_file
        output_file="$(mktemp /tmp/smd_test_out.XXXXXX)"

        local runner_script
        runner_script="$(mktemp /tmp/smd_runner.XXXXXX)"

        cat << 'EOF_RUNNER_HEADER' > "$runner_script"
#!/usr/bin/env bash
set -e
export LC_ALL=C
run() {
    set +e
    output="$("$@" 2>&1)"
    status=$?
    set -e
    return 0
}
EOF_RUNNER_HEADER

        echo "export PROJECT_ROOT=\"$PROJECT_ROOT\"" >> "$runner_script"
        echo "export BATS_TEST_DIRNAME=\"$(dirname "$test_file")\"" >> "$runner_script"
        echo "export BATS_TEST_FILENAME=\"$test_file\"" >> "$runner_script"
        echo "export BATS_TEST_DESCRIPTION=\"$tname\"" >> "$runner_script"
        echo "source \"$SCRIPT_DIR/test_helper.bash\"" >> "$runner_script"

        # If setup exists in test file, include it
        if grep -q "setup()" "$test_file"; then
            awk '/^setup\(\)/,/^\}/' "$test_file" >> "$runner_script"
            echo "setup" >> "$runner_script"
        fi

        # Append extracted test body
        awk -v test="$tname" '
            BEGIN { in_test = 0; depth = 0; }
            $0 ~ ("^@test [\"\x27]" test "[\"\x27]") { in_test = 1; next; }
            in_test {
                for (i = 1; i <= length($0); i++) {
                    c = substr($0, i, 1);
                    if (c == "{") depth++;
                    if (c == "}") depth--;
                }
                if (depth > 0 || (depth == 0 && index($0, "}") == 0)) {
                    print $0;
                } else if (in_test && depth <= 0) {
                    exit;
                }
            }
        ' "$test_file" >> "$runner_script"

        # If teardown exists in test file, include it
        if grep -q "teardown()" "$test_file"; then
            awk '/^teardown\(\)/,/^\}/' "$test_file" >> "$runner_script"
            echo "teardown" >> "$runner_script"
        fi

        local test_status=0
        bash -e "$runner_script" > "$output_file" 2>&1 || test_status=$?

        if [[ $test_status -eq 0 ]]; then
            passed=$((passed + 1))
            echo -e "  ${GREEN}✓${NC} $tname"
        else
            failed=$((failed + 1))
            echo -e "  ${RED}✗${NC} $tname"
            sed 's/^/    /' "$output_file"
        fi
        rm -f "$output_file" "$runner_script" 2>/dev/null || true
    done

    echo -e "  Summary: ${GREEN}$passed passed${NC}, ${RED}$failed failed${NC}, $total total"
    if [[ $failed -gt 0 ]]; then
        return 1
    fi
    return 0
}

main() {
    run_shellcheck

    echo -e "\n${BLUE}${BOLD}[2/2] Running automated test suites...${NC}"

    local test_files=()
    if [[ $# -gt 0 ]]; then
        test_files=("$@")
    else
        while IFS= read -r -d '' f; do
            test_files+=("$f")
        done < <(find "$SCRIPT_DIR" -name "*.bats" -print0 | sort -z)
    fi

    if [[ ${#test_files[@]} -eq 0 ]]; then
        echo "No test files found."
        exit 0
    fi

    local file_failures=0
    for tf in "${test_files[@]}"; do
        if command -v bats >/dev/null 2>&1; then
            bats "$tf" || file_failures=$((file_failures + 1))
        else
            run_bats_file "$tf" || file_failures=$((file_failures + 1))
        fi
    done

    echo "=================================================="
    if [[ $file_failures -eq 0 ]]; then
        echo -e "${GREEN}${BOLD}ALL TEST SUITES PASSED!${NC}"
        exit 0
    else
        echo -e "${RED}${BOLD}$file_failures TEST SUITE(S) FAILED!${NC}"
        exit 1
    fi
}

main "$@"
