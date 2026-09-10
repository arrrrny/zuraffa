#!/usr/bin/env bash
# Acceptance tests for all 10 acceptance behaviors (A1-A10)
#
# Each test drives the script through its documented CLI (positional paths, not
# SPECIFY_FEATURE_DIRECTORY) and asserts on observable effects, so a green run
# is real evidence for the behavior it certifies.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
SCRIPTS_DIR="$REPO_ROOT/.specify/scripts/bash"
FEATURE_DIR="$REPO_ROOT/specs/1444-spec-kit-boundary-scripts"

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
declare -a FAILED_TEST_IDS=()

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

TEST_ROOT="$(mktemp -d)"
cleanup_test_root() {
    rm -rf "$TEST_ROOT"
}
trap cleanup_test_root EXIT

log_test() {
    local behavior_id="$1"
    local description="$2"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    echo ""
    echo "========================================"
    echo -e "${YELLOW}[$TOTAL_TESTS] Testing $behavior_id: $description${NC}"
    echo "========================================"
}

log_pass() {
    PASSED_TESTS=$((PASSED_TESTS + 1))
    echo -e "${GREEN}✓ PASS${NC}"
}

log_fail() {
    local behavior_id="$1"
    local message="$2"
    FAILED_TESTS=$((FAILED_TESTS + 1))
    FAILED_TEST_IDS+=("$behavior_id")
    echo -e "${RED}✗ FAIL: $message${NC}"
}

require_jq() {
    if ! command -v jq >/dev/null 2>&1; then
        log_fail "$1" "jq is required to run the acceptance suite but was not found"
        return 1
    fi
    return 0
}

# ========================================
# A1: Sync script inserts all behavior markers in dependency order
# ========================================
test_A1() {
    log_test "A1" "Sync script inserts all behavior markers in dependency order"
    require_jq A1 || return 1

    local dir="$TEST_ROOT/a1"
    mkdir -p "$dir/tdd"

    cat > "$dir/tdd/test-list.md" << 'EOF'
# Test List

## Acceptance Behaviors
**A1**: First acceptance
**A2**: Second acceptance

## Unit Behaviors
**U1**: First unit
**U2**: Second unit
**U3**: Third unit
EOF

    cat > "$dir/tasks.md" << 'EOF'
# Tasks

## Phase 1
- [ ] Task 1
EOF

    local rc=0
    "$SCRIPTS_DIR/sync-behaviors-to-tasks.sh" "$dir/tdd/test-list.md" "$dir/tasks.md" --json \
        > "$dir/out.json" 2> "$dir/err.txt" || rc=$?
    if [[ $rc -ne 0 ]]; then
        log_fail "A1" "sync script exited $rc: $(head -n 1 "$dir/err.txt")"
        return 1
    fi

    local found
    found="$(grep -oE '\[behavior: [A-Z][0-9]*\]$' "$dir/tasks.md" 2>/dev/null | sed -E 's/\[behavior: ([A-Z][0-9]*)\]/\1/' | tr '\n' ' ' | sed 's/ *$//' || true)"
    if [[ "$found" != "A1 A2 U1 U2 U3" ]]; then
        log_fail "A1" "expected markers 'A1 A2 U1 U2 U3' in dependency order, found '$found'"
        return 1
    fi

    local count
    count="$(grep -c '\[behavior: ' "$dir/tasks.md" || true)"
    if [[ "$count" -ne 5 ]]; then
        log_fail "A1" "expected exactly 5 markers, found $count"
        return 1
    fi

    log_pass
    return 0
}

# ========================================
# A2: Sync script preserves existing markers and adds new ones
# ========================================
test_A2() {
    log_test "A2" "Sync script preserves existing markers and adds new ones"
    require_jq A2 || return 1

    local dir="$TEST_ROOT/a2"
    mkdir -p "$dir/tdd"

    cat > "$dir/tdd/test-list.md" << 'EOF'
## Acceptance Behaviors
**A1**: Existing acceptance
**A2**: New acceptance

## Unit Behaviors
**U1**: Existing unit
**U2**: New unit
**U3**: Newer unit
EOF

    cat > "$dir/tasks.md" << 'EOF'
# Tasks

- [ ] Existing acceptance task [behavior: A1]
- [ ] Existing unit task [behavior: U1]
EOF
    local a1_before u1_before
    a1_before="$(grep '\[behavior: A1\]' "$dir/tasks.md")"
    u1_before="$(grep '\[behavior: U1\]' "$dir/tasks.md")"

    local rc=0
    "$SCRIPTS_DIR/sync-behaviors-to-tasks.sh" "$dir/tdd/test-list.md" "$dir/tasks.md" --json \
        > "$dir/first.json" 2>/dev/null || rc=$?
    if [[ $rc -ne 0 ]]; then
        log_fail "A2" "first sync exited $rc"
        return 1
    fi

    local added
    added="$(jq -r '.behaviors_added' "$dir/first.json")"
    if [[ "$added" != "3" ]]; then
        log_fail "A2" "expected 3 new markers, behaviors_added=$added"
        return 1
    fi
    if [[ "$(grep '\[behavior: A1\]' "$dir/tasks.md")" != "$a1_before" ]]; then
        log_fail "A2" "existing A1 marker was modified"
        return 1
    fi
    if [[ "$(grep '\[behavior: U1\]' "$dir/tasks.md")" != "$u1_before" ]]; then
        log_fail "A2" "existing U1 marker was modified"
        return 1
    fi

    # Second run must be a no-op (idempotency).
    rc=0
    "$SCRIPTS_DIR/sync-behaviors-to-tasks.sh" "$dir/tdd/test-list.md" "$dir/tasks.md" --json \
        > "$dir/second.json" 2>/dev/null || rc=$?
    if [[ $rc -ne 0 ]]; then
        log_fail "A2" "second sync exited $rc"
        return 1
    fi
    added="$(jq -r '.behaviors_added' "$dir/second.json")"
    local count
    count="$(grep -c '\[behavior: ' "$dir/tasks.md" || true)"
    if [[ "$added" != "0" || "$count" -ne 5 ]]; then
        log_fail "A2" "second run was not idempotent (behaviors_added=$added, markers=$count)"
        return 1
    fi

    log_pass
    return 0
}

# ========================================
# A3: Sync script exits successfully when test-list is empty
# ========================================
test_A3() {
    log_test "A3" "Sync script exits successfully when test-list is empty"

    local dir="$TEST_ROOT/a3"
    mkdir -p "$dir"
    : > "$dir/test-list.md"
    printf '# Tasks\n\n- [ ] existing task\n' > "$dir/tasks.md"
    local before
    before="$(cat "$dir/tasks.md")"

    local rc=0
    "$SCRIPTS_DIR/sync-behaviors-to-tasks.sh" "$dir/test-list.md" "$dir/tasks.md" --json \
        > "$dir/out.json" 2> "$dir/err.txt" || rc=$?

    if [[ $rc -ne 0 ]]; then
        log_fail "A3" "expected exit 0 for an empty test-list, got $rc"
        return 1
    fi
    if [[ "$(cat "$dir/tasks.md")" != "$before" ]]; then
        log_fail "A3" "tasks.md was modified for an empty test-list"
        return 1
    fi

    log_pass
    return 0
}

# ========================================
# A4: Read script emits JSON with correct engine and command
# ========================================
test_A4() {
    log_test "A4" "Read script emits JSON with correct engine and command"
    require_jq A4 || return 1

    local dir="$TEST_ROOT/a4"
    mkdir -p "$dir"
    cat > "$dir/tdd-profile.md" << 'EOF'
---
engine: dart_test
test_command: dart test
verify_command: dart test --coverage
---

# TDD Profile: Dart Test
EOF

    local rc=0
    "$SCRIPTS_DIR/read-tdd-profile.sh" "$dir/tdd-profile.md" --json \
        > "$dir/out.json" 2> "$dir/err.txt" || rc=$?
    if [[ $rc -ne 0 ]]; then
        log_fail "A4" "read-tdd-profile.sh exited $rc: $(head -n 1 "$dir/err.txt")"
        return 1
    fi

    local engine test_command
    engine="$(jq -r '.engine' "$dir/out.json")"
    test_command="$(jq -r '.test_command' "$dir/out.json")"
    if [[ "$engine" != "dart_test" || "$test_command" != "dart test" ]]; then
        log_fail "A4" "expected engine=dart_test/test_command='dart test', got engine=$engine/test_command='$test_command'"
        return 1
    fi

    log_pass
    return 0
}

# ========================================
# A5: Read script errors on missing or malformed profile
# ========================================
test_A5() {
    log_test "A5" "Read script errors on missing or malformed profile"

    local dir="$TEST_ROOT/a5"
    mkdir -p "$dir"

    # Missing file -> non-zero exit, message on stderr.
    local rc=0
    "$SCRIPTS_DIR/read-tdd-profile.sh" "$dir/does-not-exist.md" \
        > "$dir/missing.out" 2> "$dir/missing.err" || rc=$?
    if [[ $rc -eq 0 ]]; then
        log_fail "A5" "expected non-zero exit for a missing profile, got 0"
        return 1
    fi
    if [[ ! -s "$dir/missing.err" ]]; then
        log_fail "A5" "expected an error message on stderr for a missing profile"
        return 1
    fi

    # Malformed (no frontmatter) -> non-zero exit, message on stderr.
    printf '# TDD Profile\n\nNo machine-readable frontmatter here.\n' > "$dir/malformed.md"
    rc=0
    "$SCRIPTS_DIR/read-tdd-profile.sh" "$dir/malformed.md" \
        > "$dir/malformed.out" 2> "$dir/malformed.err" || rc=$?
    if [[ $rc -eq 0 ]]; then
        log_fail "A5" "expected non-zero exit for a malformed profile, got 0"
        return 1
    fi
    if [[ ! -s "$dir/malformed.err" ]]; then
        log_fail "A5" "expected an error message on stderr for a malformed profile"
        return 1
    fi

    log_pass
    return 0
}

# ========================================
# A6: Read script emits array of evidence entries with correct structure
# ========================================
test_A6() {
    log_test "A6" "Read script emits array of evidence entries with correct structure"
    require_jq A6 || return 1

    local dir="$TEST_ROOT/a6"
    mkdir -p "$dir"
    cat > "$dir/cycle-log.md" << 'EOF'
## 2026-09-10 14:23 - RED - A1

Behavior: User can login

Evidence: Test fails with:
```
Expected: true
  Actual: false
```

---

## 2026-09-10 14:45 - GREEN - A1

Behavior: User can login

Evidence: Test passes.

---

## 2026-09-10 15:10 - REFACTOR - A1

Behavior: User can login

Evidence: Extracted validation.
EOF

    local rc=0
    "$SCRIPTS_DIR/read-cycle-evidence.sh" "$dir/cycle-log.md" --json \
        > "$dir/out.json" 2> "$dir/err.txt" || rc=$?
    if [[ $rc -ne 0 ]]; then
        log_fail "A6" "read-cycle-evidence.sh exited $rc"
        return 1
    fi

    local count phases all_fields
    count="$(jq '.evidence | length' "$dir/out.json")"
    if [[ "$count" != "3" ]]; then
        log_fail "A6" "expected 3 evidence entries, got $count"
        return 1
    fi
    phases="$(jq -r '[.evidence[].phase] | join(",")' "$dir/out.json")"
    if [[ "$phases" != "RED,GREEN,REFACTOR" ]]; then
        log_fail "A6" "expected phases RED,GREEN,REFACTOR, got '$phases'"
        return 1
    fi
    all_fields="$(jq -r '[.evidence[] | has("phase") and has("behavior_id") and has("timestamp") and has("evidence_text")] | all' "$dir/out.json")"
    if [[ "$all_fields" != "true" ]]; then
        log_fail "A6" "an evidence entry is missing phase/behavior_id/timestamp/evidence_text"
        return 1
    fi
    if [[ "$(jq -r '.evidence[0].timestamp' "$dir/out.json")" != "2026-09-10T14:23:00" ]]; then
        log_fail "A6" "timestamp was not converted to ISO 8601"
        return 1
    fi

    log_pass
    return 0
}

# ========================================
# A7: Read script returns empty array when cycle-log is empty
# ========================================
test_A7() {
    log_test "A7" "Read script returns empty array when cycle-log is empty"
    require_jq A7 || return 1

    local dir="$TEST_ROOT/a7"
    mkdir -p "$dir"
    : > "$dir/cycle-log.md"

    local rc=0
    "$SCRIPTS_DIR/read-cycle-evidence.sh" "$dir/cycle-log.md" --json \
        > "$dir/out.json" 2> "$dir/err.txt" || rc=$?
    if [[ $rc -ne 0 ]]; then
        log_fail "A7" "expected exit 0 for an empty cycle-log, got $rc"
        return 1
    fi

    local count
    count="$(jq '.evidence | length' "$dir/out.json")"
    if [[ "$count" != "0" ]]; then
        log_fail "A7" "expected {\"evidence\":[]}, got $(cat "$dir/out.json")"
        return 1
    fi

    log_pass
    return 0
}

# ========================================
# A8: Tick script marks specific behavior task as done
# ========================================
test_A8() {
    log_test "A8" "Tick script marks specific behavior task as done"

    local dir="$TEST_ROOT/a8"
    mkdir -p "$dir"
    cat > "$dir/tasks.md" << 'EOF'
# Tasks

## Phase 1
- [ ] Implement login [behavior: A1]
- [ ] Hash passwords [behavior: U2]
- [x] Validate email [behavior: U1]
EOF

    local rc=0
    "$SCRIPTS_DIR/tick-behavior-task.sh" "$dir/tasks.md" --behavior A1 --json \
        > "$dir/out.json" 2> "$dir/err.txt" || rc=$?
    if [[ $rc -ne 0 ]]; then
        log_fail "A8" "tick script exited $rc: $(head -n 1 "$dir/err.txt")"
        return 1
    fi

    if ! grep -q '^- \[x\] Implement login \[behavior: A1\]$' "$dir/tasks.md"; then
        log_fail "A8" "A1 was not ticked"
        return 1
    fi
    if ! grep -q '^- \[ \] Hash passwords \[behavior: U2\]$' "$dir/tasks.md"; then
        log_fail "A8" "U2 must remain untouched"
        return 1
    fi
    if ! grep -q '^- \[x\] Validate email \[behavior: U1\]$' "$dir/tasks.md"; then
        log_fail "A8" "U1 must remain untouched"
        return 1
    fi

    log_pass
    return 0
}

# ========================================
# A9: Tick script exits successfully when task already ticked
# ========================================
test_A9() {
    log_test "A9" "Tick script exits successfully when task already ticked"

    local dir="$TEST_ROOT/a9"
    mkdir -p "$dir"
    cat > "$dir/tasks.md" << 'EOF'
# Tasks

- [x] Implement login [behavior: A1]
EOF
    local before
    before="$(cat "$dir/tasks.md")"

    local rc=0
    "$SCRIPTS_DIR/tick-behavior-task.sh" "$dir/tasks.md" --behavior A1 --json \
        > "$dir/out.json" 2> "$dir/err.txt" || rc=$?
    if [[ $rc -ne 0 ]]; then
        log_fail "A9" "expected exit 0 for an already-ticked task, got $rc"
        return 1
    fi
    if [[ "$(cat "$dir/tasks.md")" != "$before" ]]; then
        log_fail "A9" "tasks.md changed for an already-ticked task"
        return 1
    fi

    log_pass
    return 0
}

# ========================================
# A10: Tick script errors when behavior ID not found
# ========================================
test_A10() {
    log_test "A10" "Tick script errors when behavior ID not found"

    local dir="$TEST_ROOT/a10"
    mkdir -p "$dir"
    printf '# Tasks\n\n- [ ] Implement login [behavior: A1]\n' > "$dir/tasks.md"

    local rc=0
    "$SCRIPTS_DIR/tick-behavior-task.sh" "$dir/tasks.md" --behavior Z99 \
        > "$dir/out.txt" 2> "$dir/err.txt" || rc=$?
    if [[ $rc -eq 0 ]]; then
        log_fail "A10" "expected non-zero exit for an unknown behavior ID, got 0"
        return 1
    fi
    if [[ ! -s "$dir/err.txt" ]]; then
        log_fail "A10" "expected an error message on stderr"
        return 1
    fi

    log_pass
    return 0
}

# ========================================
# Main execution
# ========================================
main() {
    echo "========================================"
    echo "  Spec-Kit Boundary Scripts Test Suite"
    echo "  Feature: 1444-spec-kit-boundary-scripts"
    echo "  Mode: Acceptance Tests (A1-A10)"
    echo "========================================"

    test_A1 || true
    test_A2 || true
    test_A3 || true
    test_A4 || true
    test_A5 || true
    test_A6 || true
    test_A7 || true
    test_A8 || true
    test_A9 || true
    test_A10 || true

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
