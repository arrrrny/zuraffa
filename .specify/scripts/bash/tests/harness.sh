#!/usr/bin/env bash
# harness.sh — minimal zero-dependency test harness for the boundary scripts.
#
# Design constraints (spec 1466, plan Decision 1):
#   - no external test framework; plain bash 3.2+ constructs only
#   - case-level tallying: a case passes only when every assertion in it passes
#   - fixtures live under mktemp -d; the suite never mutates repo files
#
# Test files source this harness, register cases with `t_case`, assert with
# `t_assert_*`, and finish with `t_report`. `t_report` prints the
# machine-parsable line `SUITE cases_passed=N cases_failed=M` that
# run_tests.sh aggregates.
#
# To point the suite at a sandbox copy of the scripts (mutation testing,
# fault-injection RED evidence), set BOUNDARY_SCRIPTS_DIR before running.

set -u

# Directory of the scripts under test. Default: the tests directory's parent
# (.specify/scripts/bash). Override for sandboxed mutation runs.
if [[ -n "${BOUNDARY_SCRIPTS_DIR:-}" ]]; then
    SCRIPTS_DIR="$BOUNDARY_SCRIPTS_DIR"
else
    SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

T_CASES_PASS=0
T_CASES_FAIL=0
T_CURRENT=""
T_CASE_FAILED=0
T_FAILED_IDS=()

# Begin a test case. Flushes the previous case first.
t_case() {
    t_end_case
    T_CURRENT="$1"
    T_CASE_FAILED=0
    echo ""
    echo "Testing $1"
}

# Flush the current case into the tally.
t_end_case() {
    [[ -z "$T_CURRENT" ]] && return 0
    if [[ $T_CASE_FAILED -eq 0 ]]; then
        T_CASES_PASS=$((T_CASES_PASS + 1))
    else
        T_CASES_FAIL=$((T_CASES_FAIL + 1))
        T_FAILED_IDS+=("$T_CURRENT")
    fi
    T_CURRENT=""
    return 0
}

t_pass() {
    echo "  ✓ PASS: $1"
}

t_fail() {
    T_CASE_FAILED=1
    echo "  ✗ FAIL: $1"
}

t_assert_eq() { # <desc> <expected> <actual>
    if [[ "$2" == "$3" ]]; then
        t_pass "$1"
    else
        t_fail "$1"
        echo "      expected: [$2]"
        echo "      actual:   [$3]"
    fi
    return 0
}

t_assert_contains() { # <desc> <haystack> <needle>
    if [[ "$2" == *"$3"* ]]; then
        t_pass "$1"
    else
        t_fail "$1"
        echo "      haystack did not contain: [$3]"
    fi
    return 0
}

t_assert_not_contains() { # <desc> <haystack> <needle>
    if [[ "$2" != *"$3"* ]]; then
        t_pass "$1"
    else
        t_fail "$1"
        echo "      haystack unexpectedly contained: [$3]"
    fi
    return 0
}

t_assert_exit() { # <desc> <expected_exit> <actual_exit>
    t_assert_eq "$1 (exit code)" "$2" "$3"
    return 0
}

# True when jq is available; JSON assertions prefer jq and fall back to
# fixed-string checks otherwise (mirrors the scripts' own cascade).
t_have_jq() {
    command -v jq >/dev/null 2>&1
}

t_json_get() { # <json> <jq-expr> -> value or empty
    printf '%s' "$1" | jq -r "$2" 2>/dev/null
}

# Temp fixture root. Caller registers cleanup: trap 'rm -rf "$ROOT"' EXIT
t_fixture_dir() {
    mktemp -d "${TMPDIR:-/tmp}/boundary-suite-XXXXXX"
}

# Per-file summary + machine-parsable SUITE line. Exits non-zero on failure.
t_report() {
    t_end_case
    echo ""
    echo "----------------------------------------"
    local total=$((T_CASES_PASS + T_CASES_FAIL))
    echo "  File Summary: Passed: $T_CASES_PASS/$total, Failed: $T_CASES_FAIL/$total"
    if [[ $T_CASES_FAIL -gt 0 ]]; then
        echo "  Failed cases: ${T_FAILED_IDS[*]}"
    fi
    echo "SUITE cases_passed=$T_CASES_PASS cases_failed=$T_CASES_FAIL"
    [[ $T_CASES_FAIL -eq 0 ]]
}
