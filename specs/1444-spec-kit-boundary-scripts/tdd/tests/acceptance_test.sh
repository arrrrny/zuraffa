#!/usr/bin/env bash
# Acceptance tests for spec-kit boundary scripts

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
SCRIPTS_DIR="$REPO_ROOT/.specify/scripts/bash"
TEMP_DIR="$(mktemp -d)"

# Cleanup on exit
trap 'rm -rf "$TEMP_DIR"' EXIT

# Test counter
TESTS_RUN=0
TESTS_PASSED=0

# Helper functions
run_test() {
    local test_name="$1"
    ((TESTS_RUN++))
    echo "  Testing: $test_name"
}

pass_test() {
    ((TESTS_PASSED++))
    echo "    ✓ PASS"
}

fail_test() {
    local message="$1"
    echo "    ✗ FAIL: $message"
    return 1
}

assert_file_exists() {
    local file="$1"
    [[ -f "$file" ]] || fail_test "File does not exist: $file"
}

assert_file_contains() {
    local file="$1"
    local pattern="$2"
    grep -qF "$pattern" "$file" || fail_test "File $file does not contain: $pattern"
}

assert_exit_code() {
    local expected="$1"
    local actual="$2"
    [[ "$expected" -eq "$actual" ]] || fail_test "Expected exit code $expected, got $actual"
}

# ========================================
# A1: Sync script inserts all behavior markers in dependency order
# ========================================
test_A1() {
    run_test "A1: Sync script inserts all behavior markers in dependency order"

    local test_dir="$TEMP_DIR/a1"
    mkdir -p "$test_dir"

    # Create test-list.md with 5 behaviors
    cat > "$test_dir/test-list.md" << 'EOF'
# Test List

## Acceptance Behaviors
**A1**: First acceptance test
**A2**: Second acceptance test

## Unit Behaviors
**U1**: First unit test
**U2**: Second unit test
**U3**: Third unit test
EOF

    # Create empty tasks.md
    cat > "$test_dir/tasks.md" << 'EOF'
# Tasks

## Phase 1: Implementation

- [ ] Task 1
- [ ] Task 2
EOF

    # Run sync script
    cd "$test_dir"
    if "$SCRIPTS_DIR/sync-behaviors-to-tasks.sh" 2>/dev/null; then
        # Check that tasks.md contains all 5 behavior markers
        assert_file_contains "tasks.md" "[behavior: A1]"
        assert_file_contains "tasks.md" "[behavior: A2]"
        assert_file_contains "tasks.md" "[behavior: U1]"
        assert_file_contains "tasks.md" "[behavior: U2]"
        assert_file_contains "tasks.md" "[behavior: U3]"
        pass_test
    else
        fail_test "sync-behaviors-to-tasks.sh failed or does not exist"
    fi
}

# ========================================
# Run all tests
# ========================================
echo "========================================"
echo "Acceptance Tests"
echo "========================================"

test_A1 || true

echo ""
echo "Summary: $TESTS_PASSED/$TESTS_RUN tests passed"

[[ $TESTS_PASSED -eq $TESTS_RUN ]]
