# Contract: sync-behaviors-to-tasks.sh

**Script**: `.specify/scripts/bash/sync-behaviors-to-tasks.sh`  
**Purpose**: Insert/update `[behavior: <id>]` markers in `tasks.md` based on behaviors defined in `test-list.md`

---

## Synopsis

```bash
sync-behaviors-to-tasks.sh <test-list-path> <tasks-path> [--json]
```

---

## Description

Reads behavior definitions from `test-list.md` and ensures that corresponding `[behavior: <id>]` markers exist in `tasks.md`. This replaces fragile LLM-based file operations with deterministic synchronization.

The script:
1. Parses all behavior IDs from `test-list.md` (acceptance, unit, characterization tests)
2. Scans `tasks.md` for existing `[behavior: <id>]` markers
3. For each behavior in `test-list.md`:
   - If marker exists in `tasks.md`: skip (preserve existing task)
   - If marker missing: insert new task with marker at appropriate location
4. Writes updated `tasks.md` atomically (temp file + mv)

---

## Arguments

### Positional Arguments

| Argument | Required | Description |
|----------|----------|-------------|
| `<test-list-path>` | Yes | Path to `test-list.md` containing behavior definitions |
| `<tasks-path>` | Yes | Path to `tasks.md` to update with behavior markers |

### Flags

| Flag | Description |
|------|-------------|
| `--json` | Emit JSON output instead of human-readable text |
| `--help`, `-h` | Show usage information and exit |

---

## Input Format

### test-list.md

```markdown
## Acceptance Tests

- **A1**: User can login with email and password
- **A2**: User sees error message on invalid credentials

## Unit Tests

- **U1**: `validateEmail` returns true for valid emails
- **U2**: `validateEmail` returns false for invalid emails
```

**Parsing rules**:
- Section headers define category: `## Acceptance Tests`, `## Unit Tests`, `## Characterization Tests`
- Entry pattern: `- **<id>**: <description>`
- ID format: uppercase letter + digits (e.g., `A1`, `U12`, `C3`)

### tasks.md (before sync)

```markdown
# Implementation Tasks

## Phase 1: Setup

- [ ] Initialize project structure
- [ ] Set up authentication module

## Phase 2: Features

- [ ] Implement login flow [behavior: A1]
- [ ] Add email validation
```

---

## Output Format

### Human-Readable (default)

```text
Syncing behaviors from test-list.md to tasks.md...

Found 4 behaviors in test-list.md:
  - A1: User can login with email and password
  - A2: User sees error message on invalid credentials
  - U1: validateEmail returns true for valid emails
  - U2: validateEmail returns false for invalid emails

Existing markers in tasks.md: 1
  - A1 (line 10)

Changes:
  [INSERT] A2: User sees error message on invalid credentials
  [INSERT] U1: validateEmail returns true for valid emails
  [INSERT] U2: validateEmail returns false for invalid emails

Updated tasks.md successfully.
```

### JSON Output (--json)

```json
{
  "inserted": 3,
  "updated": 0,
  "skipped": 1,
  "behaviors": [
    {
      "id": "A1",
      "description": "User can login with email and password",
      "action": "skipped",
      "reason": "marker already exists at line 10"
    },
    {
      "id": "A2",
      "description": "User sees error message on invalid credentials",
      "action": "inserted",
      "line_number": 15
    },
    {
      "id": "U1",
      "description": "validateEmail returns true for valid emails",
      "action": "inserted",
      "line_number": 16
    },
    {
      "id": "U2",
      "description": "validateEmail returns false for invalid emails",
      "action": "inserted",
      "line_number": 17
    }
  ],
  "errors": []
}
```

---

## Exit Codes

| Code | Meaning |
|------|---------|
| `0` | Success: synchronization completed (even if no changes made) |
| `1` | Error: missing required arguments, file not found, or parse failure |
| `2` | Error: duplicate behavior IDs in test-list.md |

---

## Behavior Details

### Insertion Strategy

When inserting new behavior markers:

1. **Acceptance tests** (`A*`): Insert in "Acceptance Behaviors" section (create if missing)
2. **Unit tests** (`U*`): Insert in "Unit Behaviors" section (create if missing)
3. **Characterization tests** (`C*`): Insert in "Characterization Behaviors" section (create if missing)

**Section creation**:
```markdown
## Acceptance Behaviors

- [ ] User can login with email and password [behavior: A1]
- [ ] User sees error message on invalid credentials [behavior: A2]
```

**Insertion location**:
- If section exists: append to end of section
- If section missing: create section at end of file
- Preserve all existing task structure and order

### Duplicate Handling

**Duplicate IDs in test-list.md**:
- **Policy**: Error with exit code 2
- **Rationale**: Ambiguous which behavior definition is canonical

**Multiple markers for same ID in tasks.md**:
- **Policy**: Keep first occurrence, ignore subsequent
- **Log warning** to stderr about duplicate markers

### Preservation Rules

The script MUST preserve:
- All existing tasks (with or without behavior markers)
- Task hierarchy and indentation
- Section headers and structure
- Checkboxes (done/pending state)
- Non-behavior task content

### Atomic Write Guarantee

All writes use the atomic pattern:
```bash
temp_file=$(mktemp)
# ... write to temp_file ...
mv "$temp_file" "$tasks_path"
```

If script is interrupted (SIGINT, SIGTERM), original `tasks.md` remains unchanged.

---

## Error Handling

### Missing Files

```bash
$ sync-behaviors-to-tasks.sh nonexistent.md tasks.md
ERROR: test-list.md not found: nonexistent.md
Exit code: 1
```

### Malformed test-list.md

**Missing behavior descriptions**:
```markdown
- **A1**:
```
→ Skip entry, log warning to stderr

**Invalid ID format**:
```markdown
- **abc**: Invalid ID format
```
→ Skip entry, log warning to stderr

**No behaviors found**:
```bash
$ sync-behaviors-to-tasks.sh empty-test-list.md tasks.md
No behaviors found in test-list.md. Nothing to sync.
Exit code: 0
```

### Duplicate Behavior IDs

```bash
$ sync-behaviors-to-tasks.sh test-list.md tasks.md
ERROR: Duplicate behavior ID 'A1' found in test-list.md at lines 5 and 12
Exit code: 2
```

---

## Examples

### Example 1: Initial Sync

**test-list.md**:
```markdown
## Acceptance Tests
- **A1**: User can login
```

**tasks.md** (before):
```markdown
# Tasks
- [ ] Setup project
```

**Command**:
```bash
sync-behaviors-to-tasks.sh specs/042/tdd/test-list.md specs/042/tasks.md
```

**tasks.md** (after):
```markdown
# Tasks
- [ ] Setup project

## Acceptance Behaviors
- [ ] User can login [behavior: A1]
```

### Example 2: Update Existing

**test-list.md**:
```markdown
## Acceptance Tests
- **A1**: User can login
- **A2**: User can logout
```

**tasks.md** (before):
```markdown
# Tasks
- [ ] User can login [behavior: A1]
```

**Command**:
```bash
sync-behaviors-to-tasks.sh specs/042/tdd/test-list.md specs/042/tasks.md
```

**tasks.md** (after):
```markdown
# Tasks
- [ ] User can login [behavior: A1]
- [ ] User can logout [behavior: A2]
```

### Example 3: JSON Output

**Command**:
```bash
sync-behaviors-to-tasks.sh specs/042/tdd/test-list.md specs/042/tasks.md --json | jq .
```

**Output**:
```json
{
  "inserted": 1,
  "updated": 0,
  "skipped": 1,
  "behaviors": [
    {
      "id": "A1",
      "description": "User can login",
      "action": "skipped",
      "reason": "marker already exists at line 3"
    },
    {
      "id": "A2",
      "description": "User can logout",
      "action": "inserted",
      "line_number": 4
    }
  ],
  "errors": []
}
```

---

## Implementation Notes

### Three-Tier Parser Cascade

Use the three-tier cascade for robustness:

1. **jq**: Not applicable (parsing markdown, not JSON)
2. **python3**: Parse markdown with regex/string operations
3. **grep/sed**: Fallback for simple pattern extraction

### Safe Construction

When building the updated `tasks.md`:
- Read entire file into memory
- Construct new sections in-memory
- Write complete result to temp file
- Atomic move to final location

### Idempotency

Running the script multiple times with same input produces same output:
```bash
sync-behaviors-to-tasks.sh test-list.md tasks.md
sync-behaviors-to-tasks.sh test-list.md tasks.md  # No changes on second run
```

---

## Integration with TDD Workflow

This script is invoked by the `speckit-tdd-plan` skill after `test-list.md` is generated:

```bash
# 1. Generate test list (zfa or LLM)
zfa tdd plan specs/042-feature/spec.md --output specs/042-feature/tdd/test-list.md

# 2. Sync behaviors to tasks (this script)
.specify/scripts/bash/sync-behaviors-to-tasks.sh \
  specs/042-feature/tdd/test-list.md \
  specs/042-feature/tasks.md

# 3. Continue with red-green-refactor loop
```

This ensures `tasks.md` always reflects the current test plan before implementation begins.
