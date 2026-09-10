#!/usr/bin/env bash
# Comprehensive test suite for all 20 behaviors

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
SCRIPTS_DIR="$REPO_ROOT/.specify/scripts/bash"
FEATURE_DIR="$REPO_ROOT/specs/1444-spec-kit-boundary-scripts"

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
declare -a FAILED_TEST_IDS

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_test() {
    local behavior_id="$1"
    local description="$2"
    ((TOTAL_TESTS++))
    echo ""
    echo "========================================"
    echo -e "${YELLOW}[$TOTAL_TESTS] Testing $behavior_id: $description${NC}"
    echo "========================================"
}

log_pass() {
    ((PASSED_TESTS++))
    echo -e "${GREEN}✓ PASS${NC}"
}

log_fail() {
    local behavior_id="$1"
    local message="$2"
    ((FAILED_TESTS++))
    FAILED_TEST_IDS+=("$behavior_id")
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
# U1: System provides sync-behaviors-to-tasks.sh script
# ========================================
test_U1() {
    log_test "U1" "System provides sync-behaviors-to-tasks.sh script"

    if [[ -f "$SCRIPTS_DIR/sync-behaviors-to-tasks.sh" ]] && [[ -x "$SCRIPTS_DIR/sync-behaviors-to-tasks.sh" ]]; then
        log_pass
        return 0
    else
        log_fail "U1" "sync-behaviors-to-tasks.sh missing or not executable"
        return 1
    fi
}

# ========================================
# U2: System provides read-tdd-profile.sh script
# ========================================
test_U2() {
    log_test "U2" "System provides read-tdd-profile.sh script"

    if [[ -f "$SCRIPTS_DIR/read-tdd-profile.sh" ]] && [[ -x "$SCRIPTS_DIR/read-tdd-profile.sh" ]]; then
        log_pass
        return 0
    else
        log_fail "U2" "read-tdd-profile.sh missing or not executable"
        return 1
    fi
}

# ========================================
# U3: System provides read-cycle-evidence.sh script
# ========================================
test_U3() {
    log_test "U3" "System provides read-cycle-evidence.sh script"

    if [[ -f "$SCRIPTS_DIR/read-cycle-evidence.sh" ]] && [[ -x "$SCRIPTS_DIR/read-cycle-evidence.sh" ]]; then
        log_pass
        return 0
    else
        log_fail "U3" "read-cycle-evidence.sh missing or not executable"
        return 1
    fi
}

# ========================================
# U4: System provides tick-behavior-task.sh script
# ========================================
test_U4() {
    log_test "U4" "System provides tick-behavior-task.sh script"

    if [[ -f "$SCRIPTS_DIR/tick-behavior-task.sh" ]] && [[ -x "$SCRIPTS_DIR/tick-behavior-task.sh" ]]; then
        log_pass
        return 0
    else
        log_fail "U4" "tick-behavior-task.sh missing or not executable"
        return 1
    fi
}

# ========================================
# U5: All scripts use three-tier parser cascade
# ========================================
test_U5() {
    log_test "U5" "All scripts use three-tier parser cascade"

    local all_good=true
    for script in sync-behaviors-to-tasks.sh read-tdd-profile.sh read-cycle-evidence.sh tick-behavior-task.sh; do
        if ! grep -q "python3" "$SCRIPTS_DIR/$script" || ! grep -q "grep\|sed" "$SCRIPTS_DIR/$script"; then
            log_fail "U5" "$script missing three-tier parser cascade (python3 → grep/sed)"
            all_good=false
        fi
    done

    if $all_good; then
        log_pass
        return 0
    else
        return 1
    fi
}

# ========================================
# U6: All scripts emit JSON with --json flag
# ========================================
test_U6() {
    log_test "U6" "All scripts emit JSON with --json flag"

    local all_good=true
    for script in sync-behaviors-to-tasks.sh read-tdd-profile.sh read-cycle-evidence.sh tick-behavior-task.sh; do
        if ! grep -q "JSON_MODE" "$SCRIPTS_DIR/$script" || ! grep -q "\-\-json" "$SCRIPTS_DIR/$script"; then
            log_fail "U6" "$script missing --json flag support"
            all_good=false
        fi
    done

    if $all_good; then
        log_pass
        return 0
    else
        return 1
    fi
}

# ========================================
# U7: All scripts use jq --arg for safe JSON construction
# ========================================
test_U7() {
    log_test "U7" "All scripts use jq --arg for safe JSON construction"

    local all_good=true
    for script in sync-behaviors-to-tasks.sh read-tdd-profile.sh read-cycle-evidence.sh tick-behavior-task.sh; do
        # Check if script uses both jq and --arg (may be on different lines)
        if ! grep -q "jq" "$SCRIPTS_DIR/$script" || ! grep -q -- "--arg" "$SCRIPTS_DIR/$script"; then
            log_fail "U7" "$script missing jq --arg usage"
            all_good=false
        fi
    done

    if $all_good; then
        log_pass
        return 0
    else
        return 1
    fi
}

# ========================================
# U8: All scripts follow set -euo pipefail pattern
# ========================================
test_U8() {
    log_test "U8" "All scripts follow set -euo pipefail pattern"

    local all_good=true
    for script in sync-behaviors-to-tasks.sh read-tdd-profile.sh read-cycle-evidence.sh tick-behavior-task.sh; do
        if ! grep -q "set -euo pipefail" "$SCRIPTS_DIR/$script"; then
            log_fail "U8" "$script missing 'set -euo pipefail'"
            all_good=false
        fi
    done

    if $all_good; then
        log_pass
        return 0
    else
        return 1
    fi
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
            log_fail "U9" "Missing script: $SCRIPTS_DIR/$script"
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
# U10: Scripts share common helpers via common.sh
# ========================================
test_U10() {
    log_test "U10" "Scripts share common helpers via common.sh"

    local all_good=true
    for script in sync-behaviors-to-tasks.sh read-tdd-profile.sh read-cycle-evidence.sh tick-behavior-task.sh; do
        if ! grep -q "source.*common.sh" "$SCRIPTS_DIR/$script"; then
            log_fail "U10" "$script missing 'source common.sh'"
            all_good=false
        fi
    done

    if $all_good; then
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
    echo "  Mode: Unit Tests (U1-U10)"
    echo "========================================"

    # Run all unit tests
    test_U1 || true
    test_U2 || true
    test_U3 || true
    test_U4 || true
    test_U5 || true
    test_U6 || true
    test_U7 || true
    test_U8 || true
    test_U9 || true
    test_U10 || true

    # Summary
    echo ""
    echo "========================================"
    echo "  Test Summary"
    echo "========================================"
    echo -e "${GREEN}Passed: $PASSED_TESTS/$TOTAL_TESTS${NC}"
    echo -e "${RED}Failed: $FAILED_TESTS/$TOTAL_TESTS${NC}"

    if [[ $FAILED_TESTS -gt 0 ]]; then
        echo ""
        echo "Failed tests: ${FAILED_TEST_IDS[*]}"
        exit 1
    fi

    exit 0
}

main "$@"
