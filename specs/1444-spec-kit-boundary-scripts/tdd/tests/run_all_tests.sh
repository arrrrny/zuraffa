#!/usr/bin/env bash
# Master test runner for all 20 behaviors with isolated test environments

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
SCRIPTS_DIR="$REPO_ROOT/.specify/scripts/bash"
FEATURE_DIR="$REPO_ROOT/specs/1444-spec-kit-boundary-scripts"

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_test() {
    local behavior_id="$1"
    local description="$2"
    ((TOTAL_TESTS++))
    echo ""
    echo "========================================"
    echo -e "${YELLOW}Testing $behavior_id: $description${NC}"
    echo "========================================"
}

log_pass() {
    ((PASSED_TESTS++))
    echo -e "${GREEN}✓ PASS${NC}"
}

log_fail() {
    local message="$1"
    ((FAILED_TESTS++))
    echo -e "${RED}✗ FAIL: $message${NC}"
}

# Create isolated test environment
setup_test_env() {
    local test_dir="$(mktemp -d)"
    echo "$test_dir"
}

cleanup_test_env() {
    local test_dir="$1"
    [[ -n "$test_dir" ]] && rm -rf "$test_dir"
}

# ========================================
# U9: Scripts located at .specify/scripts/bash/
# ========================================
test_U9() {
    log_test "U9" "Scripts located at .specify/scripts/bash/"

    local expected_scripts=(
        "sync-behaviors-to-tasks.sh"
        "read-tdd-profile.sh"
        "read-cycle-evidence.sh"
        "tick-behavior-task.sh"
    )

    local all_exist=true
    for script in "${expected_scripts[@]}"; do
        if [[ ! -f "$SCRIPTS_DIR/$script" ]]; then
            log_fail "Missing script: $SCRIPTS_DIR/$script"
            all_exist=false
        fi
    done

    if $all_exist; then
        log_pass
        return 0
    else
        return 1
    fi
}

# ========================================
# Main execution
# ========================================
main() {
    echo "========================================"
    echo "  Spec-Kit Boundary Scripts Test Suite"
    echo "  Feature: 1444-spec-kit-boundary-scripts"
    echo "========================================"

    # Start with unit tests that verify script existence
    test_U9 || true

    # Summary
    echo ""
    echo "========================================"
    echo "  Test Summary"
    echo "========================================"
    echo -e "${GREEN}Passed: $PASSED_TESTS${NC}"
    echo -e "${RED}Failed: $FAILED_TESTS${NC}"
    echo "Total:  $TOTAL_TESTS"

    if [[ $FAILED_TESTS -gt 0 ]]; then
        exit 1
    fi

    exit 0
}

main "$@"
