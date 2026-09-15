#!/usr/bin/env bash
# run_tests.sh — aggregate runner + shellcheck gate for the boundary scripts.
#
# Usage: bash .specify/scripts/bash/tests/run_tests.sh
#
# Gates (in order):
#   1. shellcheck -x -S warning on the four boundary scripts (FR-6/SC-2).
#      Missing shellcheck => loud SKIP, never a silent pass.
#   2. Every tests/test_*.sh in a subshell; per-file output is echoed and its
#      trailing SUITE line is aggregated into one final summary (FR-5).
#
# Exit codes: 0 all green; 1 any gate/test failure or missing suite files.

set -u

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "$TESTS_DIR/.." && pwd)"

GATE_SCRIPTS=(
    sync-behaviors-to-tasks.sh
    read-tdd-profile.sh
    read-cycle-evidence.sh
    tick-behavior-task.sh
)

echo "=========================================="
echo " Boundary Script Test Suite (feature 1466)"
echo " Scripts: $SCRIPTS_DIR"
echo "=========================================="

# ---------------------------------------------------------------------------
# Gate 1: shellcheck
# ---------------------------------------------------------------------------
if command -v shellcheck >/dev/null 2>&1; then
    gate_failed=0
    for script in "${GATE_SCRIPTS[@]}"; do
        if shellcheck -x -S warning "$SCRIPTS_DIR/$script"; then
            echo "shellcheck OK: $script"
        else
            echo "shellcheck FAILED: $script" >&2
            gate_failed=1
        fi
    done
    if [[ $gate_failed -ne 0 ]]; then
        echo ""
        echo "VERDICT: shellcheck gate FAILED"
        exit 1
    fi
else
    echo "SKIP: shellcheck not installed — gate NOT run (install shellcheck to enable)"
fi

# ---------------------------------------------------------------------------
# Gate 2: test files
# ---------------------------------------------------------------------------
shopt -s nullglob
test_files=("$TESTS_DIR"/test_*.sh)
if [[ ${#test_files[@]} -eq 0 ]]; then
    echo "ERROR: no test_*.sh files found in $TESTS_DIR" >&2
    exit 1
fi

total_passed=0
total_failed=0
files_failed=0

for tf in "${test_files[@]}"; do
    out_file="$(mktemp)"
    echo ""
    echo "=== $(basename "$tf") ==="
    if bash "$tf" >"$out_file" 2>&1; then
        cat "$out_file"
    else
        cat "$out_file"
        files_failed=$((files_failed + 1))
    fi

    suite_line="$(grep -E '^SUITE cases_passed=' "$out_file" | tail -n 1 || true)"
    if [[ "$suite_line" =~ ^SUITE\ cases_passed=([0-9]+)\ cases_failed=([0-9]+)$ ]]; then
        total_passed=$((total_passed + BASH_REMATCH[1]))
        total_failed=$((total_failed + BASH_REMATCH[2]))
    else
        # A test file that never printed a SUITE line is itself broken.
        echo "ERROR: $(basename "$tf") produced no SUITE summary line" >&2
        total_failed=$((total_failed + 1))
        files_failed=$((files_failed + 1))
    fi
    rm -f "$out_file"
done

total=$((total_passed + total_failed))
echo ""
echo "=========================================="
echo "  Test Summary"
echo "=========================================="
echo "Passed: $total_passed/$total"
echo "Failed: $total_failed/$total"

if [[ $total_failed -ne 0 || $files_failed -ne 0 ]]; then
    echo ""
    echo "VERDICT: FAIL"
    exit 1
fi
echo ""
echo "VERDICT: ALL GREEN"
exit 0
