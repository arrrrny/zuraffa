# Contract: tick-behavior-task.sh

**Script**: `.specify/scripts/bash/tick-behavior-task.sh`  
**Purpose**: Mark a specific `[behavior: <id>]` task as done in `tasks.md` when the red-green-refactor cycle completes

---

## Synopsis

```bash
tick-behavior-task.sh <tasks-path> --behavior <behavior-id> [--json]
```

---

## Description

Updates the completion status of a specific behavior task in `tasks.md` from pending `[ ]` to done `[x]`. This replaces fragile LLM-based task ticking with deterministic file modification using atomic writes.

The script:
1. Searches `tasks.md` for the line containing `[behavior: <id>]`
2. Verifies the task has a checkbox (`- [ ]` or `- [x]`)
3. Updates `- [ ]` → `- [x]` for the specified behavior
4. Writes updated `tasks.md` atomically (temp file + mv)
5. Reports the change (or no-op if already done)

---

## Arguments

### Positional Arguments

| Argument | Required | Description |
|----------|----------|-------------|
| `<tasks-path>` | Yes | Path to `tasks.md` containing behavior tasks |

### Required Flags

| Flag | Description |
|------|-------------|
| `--behavior <id>` | Behavior ID to mark as done (e.g., `A1`, `U2`) |

### Optional Flags

| Flag | Description |
|------|-------------|
| `--json` | Emit JSON output instead of human-readable text |
| `--help`, `-h` | Show usage information and exit |

---

## Input Format

### tasks.md

```markdown
# Implementation Tasks

## Phase 1: Authentication

- [ ] Implement login endpoint [behavior: A1]
- [x] Validate email format [behavior: U1]
- [ ] Hash passwords securely [behavior: U2]

## Phase 2: Authorization

- [ ] Implement role-based access control [behavior: A2]
```

**Task Format**:
- Checkbox patterns: `- [ ]` (pending) or `- [x]` (done)
- Behavior marker: `[behavior: <id>]` at end of task line
- Task can have any indentation level

---

## Output Format

### Human-Readable (default)

```text
Ticking behavior task: A1

Found behavior A1 at line 5: "Implement login endpoint"
Status changed: pending → done

Updated tasks.md successfully.
```

### JSON Output (--json)

```json
{
  "behavior_id": "A1",
  "previous_status": "pending",
  "new_status": "done",
  "line_number": 5,
  "task_text": "Implement login endpoint [behavior: A1]"
}
```

**Field Descriptions**:
- `behavior_id`: The behavior ID that was ticked
- `previous_status`: Status before tick (`pending` or `done`)
- `new_status`: Status after tick (always `done`)
- `line_number`: Line number in tasks.md where the change was made
- `task_text`: Full task description (without checkbox, with behavior marker)

---

## Exit Codes

| Code | Meaning |
|------|---------|
| `0` | Success: task ticked (or already done) |
| `1` | Error: missing arguments, file not found, or behavior not found in tasks.md |

---

## Behavior Details

### Finding the Behavior Task

```bash
# Search for behavior marker
line_number=$(grep -n '\[behavior: '"$behavior_id"'\]' "$tasks_path" | cut -d: -f1)

if [[ -z "$line_number" ]]; then
    echo "ERROR: Behavior '$behavior_id' not found in $tasks_path" >&2
    exit 1
fi
```

### Checking Current Status

```bash
# Get the line content
line_content=$(sed -n "${line_number}p" "$tasks_path")

# Check if already done
if echo "$line_content" | grep -q '\[x\]'; then
    echo "Behavior '$behavior_id' is already marked as done"
    exit 0
fi

# Check if pending
if ! echo "$line_content" | grep -q '\[ \]'; then
    echo "ERROR: Behavior '$behavior_id' does not have a valid checkbox" >&2
    exit 1
fi
```

### Ticking the Task

```bash
# Update [ ] → [x] on the specific line
sed "${line_number}s/\[ \]/[x]/" "$tasks_path" > "$temp_file"
mv "$temp_file" "$tasks_path"
```

### Atomic Write Guarantee

All writes use the atomic pattern:
```bash
temp_file=$(mktemp)
trap "rm -f '$temp_file'" EXIT

# Read entire file, modify specific line, write to temp
sed "${line_number}s/\[ \]/[x]/" "$tasks_path" > "$temp_file"

# Atomic move
mv "$temp_file" "$tasks_path"
```

If script is interrupted (SIGINT, SIGTERM), original `tasks.md` remains unchanged.

---

## Examples

### Example 1: Tick Pending Task

**Input**: `tasks.md`
```markdown
- [ ] Implement login [behavior: A1]
- [ ] Add error handling [behavior: A2]
```

**Command**:
```bash
tick-behavior-task.sh specs/042/tasks.md --behavior A1
```

**Output**:
```text
Ticking behavior task: A1
Found behavior A1 at line 1: "Implement login"
Status changed: pending → done
Updated tasks.md successfully.
```

**Result**: `tasks.md`
```markdown
- [x] Implement login [behavior: A1]
- [ ] Add error handling [behavior: A2]
```

### Example 2: Already Done

**Input**: `tasks.md`
```markdown
- [x] Implement login [behavior: A1]
```

**Command**:
```bash
tick-behavior-task.sh specs/042/tasks.md --behavior A1
```

**Output**:
```text
Ticking behavior task: A1
Found behavior A1 at line 1: "Implement login"
Behavior A1 is already marked as done. No changes needed.
```

**Exit code**: `0` (success, idempotent)

### Example 3: Behavior Not Found

**Input**: `tasks.md`
```markdown
- [ ] Implement login [behavior: A1]
```

**Command**:
```bash
tick-behavior-task.sh specs/042/tasks.md --behavior X99
```

**Output**:
```text
ERROR: Behavior 'X99' not found in specs/042/tasks.md
Exit code: 1
```

### Example 4: JSON Output

**Command**:
```bash
tick-behavior-task.sh specs/042/tasks.md --behavior A1 --json
```

**Output**:
```json
{
  "behavior_id": "A1",
  "previous_status": "pending",
  "new_status": "done",
  "line_number": 5,
  "task_text": "Implement login [behavior: A1]"
}
```

### Example 5: Nested Task

**Input**: `tasks.md`
```markdown
- [ ] Authentication module
  - [ ] Implement login [behavior: A1]
  - [ ] Implement logout [behavior: A2]
```

**Command**:
```bash
tick-behavior-task.sh specs/042/tasks.md --behavior A1
```

**Result**: Only the nested task is ticked
```markdown
- [ ] Authentication module
  - [x] Implement login [behavior: A1]
  - [ ] Implement logout [behavior: A2]
```

---

## Error Handling

### Missing Required Flag

```bash
$ tick-behavior-task.sh specs/042/tasks.md
ERROR: Missing required flag --behavior <id>
Usage: tick-behavior-task.sh <tasks-path> --behavior <id> [--json]
Exit code: 1
```

### Missing File

```bash
$ tick-behavior-task.sh nonexistent.md --behavior A1
ERROR: tasks.md not found: nonexistent.md
Exit code: 1
```

### Behavior Not Found

```bash
$ tick-behavior-task.sh tasks.md --behavior X99
ERROR: Behavior 'X99' not found in tasks.md
Exit code: 1
```

### Malformed Task (No Checkbox)

```markdown
Some text [behavior: A1]
```
(missing `- [ ]` or `- [x]` prefix)

```bash
$ tick-behavior-task.sh tasks.md --behavior A1
ERROR: Behavior 'A1' found at line 1 but does not have a valid checkbox
Exit code: 1
```

### Multiple Markers for Same Behavior

**Policy**: Tick only the first occurrence, log warning about duplicates

```markdown
- [ ] Implement login [behavior: A1]
- [ ] Duplicate task [behavior: A1]
```

```bash
$ tick-behavior-task.sh tasks.md --behavior A1
WARNING: Multiple markers found for behavior A1 (lines 1, 2). Ticking first occurrence only.
Ticking behavior task: A1
Found behavior A1 at line 1: "Implement login"
Status changed: pending → done
Updated tasks.md successfully.
```

---

## Implementation Notes

### Safe Line-Based Modification

```bash
# Read entire file into memory
content=$(cat "$tasks_path")

# Find line number
line_number=$(echo "$content" | grep -n '\[behavior: '"$behavior_id"'\]' | head -n 1 | cut -d: -f1)

# Update specific line using sed
temp_file=$(mktemp)
echo "$content" | sed "${line_number}s/\[ \]/[x]/" > "$temp_file"

# Atomic move
mv "$temp_file" "$tasks_path"
```

### Preserving Indentation

The script preserves all whitespace, including indentation:

```markdown
  - [ ] Nested task [behavior: A1]
```

Becomes:

```markdown
  - [x] Nested task [behavior: A1]
```

The two-space prefix is untouched.

### JSON Construction

Use `jq --arg` for safe JSON:

```bash
jq -cn \
    --arg bid "$behavior_id" \
    --arg prev "$previous_status" \
    --arg new "$new_status" \
    --arg line "$line_number" \
    --arg text "$task_text" \
    '{
        behavior_id: $bid,
        previous_status: $prev,
        new_status: $new,
        line_number: ($line | tonumber),
        task_text: $text
    }'
```

### Fallback without jq

```bash
printf '{"behavior_id":"%s","previous_status":"%s","new_status":"%s","line_number":%d,"task_text":"%s"}\n' \
    "$(json_escape "$behavior_id")" \
    "$(json_escape "$previous_status")" \
    "$(json_escape "$new_status")" \
    "$line_number" \
    "$(json_escape "$task_text")"
```

---

## Integration with TDD Workflow

This script is invoked by the `speckit-tdd-run` skill when a behavior completes the red-green-refactor cycle:

```bash
# 1. Run tests until green
zfa tdd run specs/042-feature/spec.md --behavior A1

# 2. Verify green evidence in cycle-log.md
evidence=$(grep "GREEN - A1" specs/042-feature/tdd/cycle-log.md)

# 3. If green, tick the behavior task
if [[ -n "$evidence" ]]; then
    .specify/scripts/bash/tick-behavior-task.sh \
        specs/042-feature/tasks.md \
        --behavior A1
fi
```

This ensures `tasks.md` reflects the actual TDD progress.

---

## Idempotency

The script is fully idempotent — running it multiple times with the same inputs produces the same result:

```bash
tick-behavior-task.sh tasks.md --behavior A1  # Tick A1
tick-behavior-task.sh tasks.md --behavior A1  # No-op: already done
tick-behavior-task.sh tasks.md --behavior A1  # No-op: already done
```

All three invocations succeed (exit code 0), but only the first makes a change.

---

## Performance

### Typical Performance

For tasks.md files with 50-100 tasks (~500-1000 lines):
- **Search**: ~5ms (grep)
- **Modify**: ~10ms (sed + temp file write)
- **Move**: ~1ms (atomic mv)
- **Total**: ~20ms

### Large Files

For tasks.md with 500+ tasks (~5000+ lines):
- **Total**: ~100ms

The script reads the entire file into memory, so very large files (>10,000 lines) may be slower, but this is rare in practice.

---

## Validation

### File Integrity

After ticking, verify:
1. Only the specified behavior's checkbox changed
2. All other tasks remain unchanged
3. File structure (headers, indentation) is preserved
4. No data loss or corruption

### Test with diff

```bash
cp tasks.md tasks.md.backup
tick-behavior-task.sh tasks.md --behavior A1
diff tasks.md.backup tasks.md
# Expected: Only one line changed ([ ] → [x])
```

---

## Alternatives Not Used

### Why Not In-Place Editing (`sed -i`)?

```bash
# NOT USED: sed -i
sed -i "${line_number}s/\[ \]/[x]/" "$tasks_path"
```

**Reason**: `sed -i` is not atomic. If interrupted mid-write, the file can be corrupted.

### Why Not Appending to File?

```bash
# NOT USED: rewrite entire file
grep -v '\[behavior: A1\]' tasks.md > temp
echo "- [x] Updated task [behavior: A1]" >> temp
mv temp tasks.md
```

**Reason**: This would require re-parsing and re-formatting the entire file, losing all structure, comments, and ordering.

---

## Future Enhancements

### Untick Support

Currently the script only ticks (pending → done). Future versions could support:

```bash
tick-behavior-task.sh tasks.md --behavior A1 --untick
# Result: [x] → [ ]
```

### Batch Ticking

```bash
tick-behavior-task.sh tasks.md --behaviors A1,A2,A3
# Tick multiple behaviors in one operation
```

### Verbose Mode

```bash
tick-behavior-task.sh tasks.md --behavior A1 --verbose
# Show full line context before and after
```

These are not implemented in the initial version but could be added if needed.
