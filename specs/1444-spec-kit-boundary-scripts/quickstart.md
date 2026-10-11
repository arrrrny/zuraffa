# Quickstart Guide: Spec-Kit Boundary Scripts

**Feature**: 1444-spec-kit-boundary-scripts  
**Date**: 2026-09-10  
**Purpose**: Quick reference for using the four bash boundary scripts

---

## Overview

The spec-kit boundary scripts provide deterministic operations for spec-kit ↔ zuraffa data synchronization. All scripts follow consistent patterns:

- **Location**: `.specify/scripts/bash/`
- **JSON output**: Add `--json` flag
- **Help text**: Add `--help` or `-h` flag
- **Error handling**: Non-zero exit codes on failure, errors to stderr

---

## Quick Reference

### sync-behaviors-to-tasks.sh

**Purpose**: Sync behavior markers from `test-list.md` to `tasks.md`

**Basic Usage**:
```bash
.specify/scripts/bash/sync-behaviors-to-tasks.sh \
  specs/042-feature/tdd/test-list.md \
  specs/042-feature/tasks.md
```

**JSON Output**:
```bash
.specify/scripts/bash/sync-behaviors-to-tasks.sh \
  specs/042-feature/tdd/test-list.md \
  specs/042-feature/tasks.md \
  --json | jq .
```

**Example Output**:
```json
{
  "inserted": 3,
  "updated": 0,
  "skipped": 1,
  "behaviors": [
    {"id": "A1", "action": "skipped", "reason": "marker already exists at line 10"},
    {"id": "A2", "action": "inserted", "line_number": 15},
    {"id": "U1", "action": "inserted", "line_number": 16}
  ],
  "errors": []
}
```

---

### read-tdd-profile.sh

**Purpose**: Parse TDD profile configuration and emit JSON

**Basic Usage**:
```bash
.specify/scripts/bash/read-tdd-profile.sh \
  .specify/memory/tdd-profile.md
```

**JSON Output**:
```bash
.specify/scripts/bash/read-tdd-profile.sh \
  .specify/memory/tdd-profile.md \
  --json | jq .
```

**Example Output**:
```json
{
  "engine": "dart_test",
  "test_command": "dart test",
  "verify_command": "dart test --coverage",
  "plan_command": "dart test --list"
}
```

**Extract Specific Field**:
```bash
test_command=$(
  .specify/scripts/bash/read-tdd-profile.sh \
    .specify/memory/tdd-profile.md \
    --json | jq -r '.test_command'
)
echo "Running tests with: $test_command"
```

---

### read-cycle-evidence.sh

**Purpose**: Extract red-green-refactor evidence from cycle log

**Basic Usage**:
```bash
.specify/scripts/bash/read-cycle-evidence.sh \
  specs/042-feature/tdd/cycle-log.md
```

**JSON Output**:
```bash
.specify/scripts/bash/read-cycle-evidence.sh \
  specs/042-feature/tdd/cycle-log.md \
  --json | jq .
```

**Example Output**:
```json
{
  "evidence": [
    {
      "phase": "RED",
      "behavior_id": "A1",
      "timestamp": "2026-09-10T14:23:00",
      "evidence_text": "Test fails with assertion error..."
    },
    {
      "phase": "GREEN",
      "behavior_id": "A1",
      "timestamp": "2026-09-10T14:45:00",
      "evidence_text": "All tests pass."
    }
  ]
}
```

**Filter by Phase**:
```bash
.specify/scripts/bash/read-cycle-evidence.sh \
  specs/042-feature/tdd/cycle-log.md \
  --json | jq '.evidence[] | select(.phase == "GREEN")'
```

**Count Evidence Entries**:
```bash
.specify/scripts/bash/read-cycle-evidence.sh \
  specs/042-feature/tdd/cycle-log.md \
  --json | jq '.evidence | length'
```

---

### tick-behavior-task.sh

**Purpose**: Mark a behavior task as done in `tasks.md`

**Basic Usage**:
```bash
.specify/scripts/bash/tick-behavior-task.sh \
  specs/042-feature/tasks.md \
  --behavior A1
```

**JSON Output**:
```bash
.specify/scripts/bash/tick-behavior-task.sh \
  specs/042-feature/tasks.md \
  --behavior A1 \
  --json | jq .
```

**Example Output**:
```json
{
  "behavior_id": "A1",
  "previous_status": "pending",
  "new_status": "done",
  "line_number": 15,
  "task_text": "Implement user login [behavior: A1]"
}
```

---

## Common Workflows

### Workflow 1: TDD Planning

```bash
# 1. Generate test list (via zfa or LLM)
zfa tdd plan specs/042-feature/spec.md \
  --output specs/042-feature/tdd/test-list.md

# 2. Sync behaviors to tasks
.specify/scripts/bash/sync-behaviors-to-tasks.sh \
  specs/042-feature/tdd/test-list.md \
  specs/042-feature/tasks.md

# 3. Verify sync
grep '\[behavior:' specs/042-feature/tasks.md
```

### Workflow 2: Running Tests

```bash
# 1. Read TDD profile
profile_json=$(.specify/scripts/bash/read-tdd-profile.sh \
  .specify/memory/tdd-profile.md \
  --json)

# 2. Extract test command
test_command=$(echo "$profile_json" | jq -r '.test_command')

# 3. Run tests
eval "$test_command"
```

### Workflow 3: Red-Green-Refactor Loop

```bash
behavior_id="A1"

# 1. Write failing test (RED)
# ... (manual or zfa-driven)

# 2. Record RED evidence in cycle-log.md
echo "## $(date +%Y-%m-%d\ %H:%M) - RED - $behavior_id" >> cycle-log.md
echo "Evidence: Test fails..." >> cycle-log.md
echo "---" >> cycle-log.md

# 3. Implement to make test pass (GREEN)
# ... (manual or zfa-driven)

# 4. Record GREEN evidence
echo "## $(date +%Y-%m-%d\ %H:%M) - GREEN - $behavior_id" >> cycle-log.md
echo "Evidence: Test passes." >> cycle-log.md
echo "---" >> cycle-log.md

# 5. Tick the behavior task
.specify/scripts/bash/tick-behavior-task.sh \
  specs/042-feature/tasks.md \
  --behavior "$behavior_id"
```

### Workflow 4: Verifying TDD Discipline

```bash
# 1. Read cycle evidence
evidence_json=$(.specify/scripts/bash/read-cycle-evidence.sh \
  specs/042-feature/tdd/cycle-log.md \
  --json)

# 2. Check for RED → GREEN sequence for behavior A1
echo "$evidence_json" | jq '.evidence[] | select(.behavior_id == "A1") | .phase'

# Expected output:
# "RED"
# "GREEN"
# "REFACTOR"  (optional)

# 3. Verify evidence quality (non-empty evidence text)
echo "$evidence_json" | jq '.evidence[] | select(.evidence_text | length < 10)'
# Should return empty if all evidence is sufficient
```

---

## Integration with TDD Skills

### speckit-tdd-plan

```bash
# Called by the TDD skill after test-list.md is generated
.specify/scripts/bash/sync-behaviors-to-tasks.sh \
  "$TEST_LIST_PATH" \
  "$TASKS_PATH"
```

### speckit-tdd-run

```bash
# 1. Read profile to get test command
test_cmd=$(.specify/scripts/bash/read-tdd-profile.sh \
  "$TDD_PROFILE_PATH" --json | jq -r '.test_command')

# 2. Run tests
eval "$test_cmd"

# 3. If green, tick the behavior
if [[ $? -eq 0 ]]; then
    .specify/scripts/bash/tick-behavior-task.sh \
      "$TASKS_PATH" \
      --behavior "$BEHAVIOR_ID"
fi
```

### speckit-tdd-verify

```bash
# Read evidence for audit
evidence=$(.specify/scripts/bash/read-cycle-evidence.sh \
  "$CYCLE_LOG_PATH" --json)

# Verify each behavior has RED → GREEN sequence
for behavior_id in $(echo "$evidence" | jq -r '.evidence[].behavior_id' | sort -u); do
    phases=$(echo "$evidence" | jq -r ".evidence[] | select(.behavior_id == \"$behavior_id\") | .phase")
    # Check phases contain RED followed by GREEN
    echo "$phases" | grep -q "RED" && echo "$phases" | grep -q "GREEN"
done
```

---

## Error Handling

### Handling Missing Files

```bash
if ! .specify/scripts/bash/read-tdd-profile.sh tdd-profile.md 2>/dev/null; then
    echo "ERROR: TDD profile not found or invalid" >&2
    echo "Run: speckit-tdd-setup to create the profile" >&2
    exit 1
fi
```

### Handling Empty Results

```bash
evidence=$(.specify/scripts/bash/read-cycle-evidence.sh cycle-log.md --json)

if [[ $(echo "$evidence" | jq '.evidence | length') -eq 0 ]]; then
    echo "WARNING: No evidence found in cycle-log.md" >&2
    echo "The RED-GREEN-REFACTOR cycle has not started yet." >&2
fi
```

### Handling Behavior Not Found

```bash
if ! .specify/scripts/bash/tick-behavior-task.sh tasks.md --behavior A1 2>/dev/null; then
    echo "ERROR: Behavior A1 not found in tasks.md" >&2
    echo "Run sync-behaviors-to-tasks.sh first to create behavior markers" >&2
    exit 1
fi
```

---

## Testing the Scripts

### Manual Testing with Sample Data

Create test fixtures:

```bash
mkdir -p test/fixtures/bash_scripts

# Create sample test-list.md
cat > test/fixtures/bash_scripts/test-list-sample.md << 'EOF'
## Acceptance Tests

- **A1**: User can login with email and password
- **A2**: User sees error message on invalid credentials

## Unit Tests

- **U1**: validateEmail returns true for valid emails
EOF

# Create sample tasks.md
cat > test/fixtures/bash_scripts/tasks-sample.md << 'EOF'
# Implementation Tasks

- [ ] Setup authentication module
EOF

# Test sync script
.specify/scripts/bash/sync-behaviors-to-tasks.sh \
  test/fixtures/bash_scripts/test-list-sample.md \
  test/fixtures/bash_scripts/tasks-sample.md

# Verify result
cat test/fixtures/bash_scripts/tasks-sample.md
```

### Automated Testing

Run integration tests:

```bash
dart test test/integration/bash_scripts_test.dart
```

---

## Performance Notes

### Typical Performance

- **sync-behaviors-to-tasks.sh**: ~50ms for 20 behaviors
- **read-tdd-profile.sh**: ~10ms
- **read-cycle-evidence.sh**: ~100ms for 50 evidence entries
- **tick-behavior-task.sh**: ~20ms

### Large File Performance

For files >1000 lines:
- Scripts may take 200-500ms
- Still acceptable for TDD workflow (not performance-critical)
- Atomic writes prevent data loss even if interrupted

---

## Troubleshooting

### Problem: Script outputs "command not found"

**Solution**: Ensure scripts are executable

```bash
chmod +x .specify/scripts/bash/*.sh
```

### Problem: JSON output is malformed

**Solution**: Check if `jq` is installed (Tier 1 parser)

```bash
which jq || echo "jq not found, falling back to python3/grep"
```

### Problem: Script hangs or times out

**Solution**: Check for very large files (>10,000 lines) or circular symlinks

```bash
# Check file size
wc -l specs/042-feature/tdd/cycle-log.md

# Check for symlinks
ls -la specs/042-feature/tdd/
```

### Problem: Behavior not synced to tasks.md

**Solution**: Check test-list.md format

```bash
# Verify behavior format: - **<ID>**: <description>
grep '^\- \*\*[A-Z][0-9]\+\*\*:' specs/042-feature/tdd/test-list.md
```

---

## Best Practices

1. **Always run sync after updating test-list.md** to keep tasks.md in sync
2. **Use JSON output for programmatic consumption** (piping to jq, parsing in Dart)
3. **Use human-readable output for debugging** (easier to read logs)
4. **Check exit codes** to detect errors in automation scripts
5. **Preserve cycle-log.md** as the source of truth for TDD evidence
6. **Never edit behavior markers manually** in tasks.md — always use the sync script

---

## Next Steps

After reading this quickstart:

1. **Review contracts**: Read `contracts/*.md` for detailed API documentation
2. **Check data model**: Read `data-model.md` to understand entities
3. **Read research**: Read `research.md` for implementation patterns
4. **Run /speckit-tasks**: Generate the task breakdown for implementation
5. **Run /speckit-implement**: Build the scripts and tests

---

## Additional Resources

- **Reference Implementation**: `.specify/scripts/bash/setup-tasks.sh`
- **Common Helpers**: `.specify/scripts/bash/common.sh`
- **Three-Tier Parser Pattern**: `research.md` section 2
- **Atomic Write Pattern**: `research.md` section 3
