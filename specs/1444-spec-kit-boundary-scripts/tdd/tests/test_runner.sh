#!/usr/bin/env bash
# Simple bash test runner for spec-kit boundary scripts

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_PASSED=0
TESTS_FAILED=0
FAILED_TESTS=()

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test assertion helpers
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-}"

    if [[ "$expected" == "$actual" ]]; then
        return 0
    else
        echo "  Expected: $expected"
        echo "  Actual:   $actual"
        [[ -n "$message" ]] && echo "  Message:  $message"
        return 1
    fi
}

assert_file_exists() {
    local file="$1"
    [[ -f "$file" ]] || { echo "  File does not exist: $file"; return 1; }
}

assert_file_contains() {
    local file="$1"
    local pattern="$2"
    grep -qF "$pattern" "$file" || { echo "  File $file does not contain: $pattern"; return 1; }
}

assert_exit_code() {
    local expected="$1"
    local actual="$2"
    [[ "$expected" -eq "$actual" ]] || { echo "  Expected exit code $expected, got $actual"; return 1; }
}

# Run a single test file
run_test_file() {
    local test_file="$1"
    local test_name="$(basename "$test_file" .sh)"

    echo -e "${YELLOW}Running: $test_name${NC}"

    if bash "$test_file"; then
        echo -e "${GREEN}✓ PASSED: $test_name${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAILED: $test_name${NC}"
        ((TESTS_FAILED++))
        FAILED_TESTS+=("$test_name")
    fi
    echo ""
}

# Main execution
main() {
    echo "========================================"
    echo "  Spec-Kit Boundary Scripts Test Suite"
    echo "========================================"
    echo ""

    # Find and run all test files
    for test_file in "$SCRIPT_DIR"/*_test.sh; do
        [[ -f "$test_file" ]] || continue
        run_test_file "$test_file"
    done

    # Summary
    echo "========================================"
    echo "  Test Summary"
    echo "========================================"
    echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"

    if [[ $TESTS_FAILED -gt 0 ]]; then
        echo ""
        echo "Failed tests:"
        for test in "${FAILED_TESTS[@]}"; do
            echo -e "  ${RED}✗ $test${NC}"
        done
        exit 1
    fi

    exit 0
}

main "$@"
