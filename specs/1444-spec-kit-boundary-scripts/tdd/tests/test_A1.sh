#!/usr/bin/env bash
# Test A1: Sync script inserts all behavior markers in dependency order

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
SCRIPTS_DIR="$REPO_ROOT/.specify/scripts/bash"
TEST_FEATURE_DIR="$REPO_ROOT/specs/1444-spec-kit-boundary-scripts"

# Set up feature context for the script
export SPECIFY_FEATURE_DIRECTORY="$TEST_FEATURE_DIR"

# Create test fixture
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

# Create test-list.md with 5 behaviors
cat > "$TEMP_DIR/test-list.md" << 'EOF'
# Test List

## Acceptance Behaviors
**A1**: First acceptance test
**A2**: Second acceptance test

## Unit Behaviors
**U1**: First unit test
**U2**: Second unit test
**U3**: Third unit test
EOF

# Create minimal tasks.md
cat > "$TEMP_DIR/tasks.md" << 'EOF'
# Tasks

## Phase 1: Implementation

- [ ] Task 1
EOF

# Override feature directory to point to our temp dir
cd "$TEMP_DIR"
export SPECIFY_FEATURE_DIRECTORY="$TEMP_DIR"

# Run sync script
if ! "$SCRIPTS_DIR/sync-behaviors-to-tasks.sh" 2>&1; then
    echo "FAIL: sync-behaviors-to-tasks.sh failed or does not exist"
    exit 1
fi

# Verify all 5 behavior markers were inserted
for id in A1 A2 U1 U2 U3; do
    if ! grep -q "\[behavior: $id\]" tasks.md; then
        echo "FAIL: tasks.md missing [behavior: $id]"
        exit 1
    fi
done

echo "PASS: A1 - All 5 behavior markers inserted"
exit 0
