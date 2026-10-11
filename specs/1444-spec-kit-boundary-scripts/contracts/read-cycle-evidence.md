# Contract: read-cycle-evidence.sh

**Script**: `.specify/scripts/bash/read-cycle-evidence.sh`  
**Purpose**: Extract red-green-refactor evidence entries from `cycle-log.md` as structured JSON array

---

## Synopsis

```bash
read-cycle-evidence.sh <cycle-log-path> [--json]
```

---

## Description

Reads the TDD cycle log and extracts structured evidence entries for each red-green-refactor phase. This replaces fragile LLM-based log parsing with deterministic markdown extraction using the three-tier parser cascade (python3 → grep/sed).

The script:
1. Splits `cycle-log.md` into evidence entries (delimited by `---`)
2. Parses each entry header: `## <timestamp> - <phase> - <behavior_id>`
3. Extracts evidence body text
4. Emits structured output (JSON array or human-readable)

---

## Arguments

### Positional Arguments

| Argument | Required | Description |
|----------|----------|-------------|
| `<cycle-log-path>` | Yes | Path to `cycle-log.md` containing cycle evidence |

### Flags

| Flag | Description |
|------|-------------|
| `--json` | Emit JSON output instead of human-readable text |
| `--help`, `-h` | Show usage information and exit |

---

## Input Format

### cycle-log.md

```markdown
## 2026-09-10 14:23 - RED - A1

Behavior: User can login with email and password

Evidence: Test `test/features/auth/login_test.dart` fails with:
```
Expected: true
  Actual: false
```

---

## 2026-09-10 14:45 - GREEN - A1

Behavior: User can login with email and password

Evidence: Test `test/features/auth/login_test.dart` passes.

---

## 2026-09-10 15:10 - REFACTOR - A1

Behavior: User can login with email and password

Evidence: Extracted password validation into separate function. All tests still pass.

---
```

**Entry Format**:
- Header: `## <timestamp> - <phase> - <behavior_id>`
- Timestamp: `YYYY-MM-DD HH:MM` (local time, no timezone)
- Phase: `RED`, `GREEN`, or `REFACTOR`
- Separator: `---` between entries
- Body: All content between header and next `---`

---

## Output Format

### Human-Readable (default)

```text
Cycle Evidence: specs/042-feature/tdd/cycle-log.md

Found 3 evidence entries:

[1] 2026-09-10 14:23 - RED - A1
    Behavior: User can login with email and password
    Evidence: Test `test/features/auth/login_test.dart` fails with...

[2] 2026-09-10 14:45 - GREEN - A1
    Behavior: User can login with email and password
    Evidence: Test `test/features/auth/login_test.dart` passes.

[3] 2026-09-10 15:10 - REFACTOR - A1
    Behavior: User can login with email and password
    Evidence: Extracted password validation into separate function...
```

### JSON Output (--json)

```json
{
  "evidence": [
    {
      "phase": "RED",
      "behavior_id": "A1",
      "timestamp": "2026-09-10T14:23:00",
      "evidence_text": "Test `test/features/auth/login_test.dart` fails with:\n```\nExpected: true\n  Actual: false\n```"
    },
    {
      "phase": "GREEN",
      "behavior_id": "A1",
      "timestamp": "2026-09-10T14:45:00",
      "evidence_text": "Test `test/features/auth/login_test.dart` passes."
    },
    {
      "phase": "REFACTOR",
      "behavior_id": "A1",
      "timestamp": "2026-09-10T15:10:00",
      "evidence_text": "Extracted password validation into separate function. All tests still pass."
    }
  ]
}
```

**Field Descriptions**:
- `phase`: Red-green-refactor phase (RED | GREEN | REFACTOR)
- `behavior_id`: Behavior this evidence relates to (e.g., A1, U2)
- `timestamp`: ISO 8601 timestamp (converted from `YYYY-MM-DD HH:MM` format)
- `evidence_text`: Full evidence description (everything after "Evidence:" line)

---

## Exit Codes

| Code | Meaning |
|------|---------|
| `0` | Success: evidence parsed and emitted (even if empty) |
| `1` | Error: file not found or unreadable |

---

## Behavior Details

### Entry Parsing Algorithm

```bash
# 1. Split on --- delimiters
entries=$(awk '/^## [0-9]{4}-[0-9]{2}-[0-9]{2}/ { if (entry) print entry; entry=$0; next } /^---$/ { if (entry) print entry; entry=""; next } { if (entry) entry=entry"\n"$0 } END { if (entry) print entry }' cycle-log.md)

# 2. Parse each entry header
parse_entry_header() {
    local entry="$1"
    local header=$(echo "$entry" | head -n 1)
    # Extract: 2026-09-10 14:23 - RED - A1
    local timestamp=$(echo "$header" | sed -E 's/^## ([0-9 :-]+) - .*/\1/')
    local phase=$(echo "$header" | sed -E 's/^## [0-9 :-]+ - ([A-Z]+) - .*/\1/')
    local behavior_id=$(echo "$header" | sed -E 's/^## [0-9 :-]+ - [A-Z]+ - ([A-Z0-9]+).*/\1/')
}

# 3. Extract evidence body
parse_evidence_body() {
    local entry="$1"
    # Everything after "Evidence:" line
    echo "$entry" | sed -n '/^Evidence:/,$ p' | sed '1d'
}
```

### Timestamp Conversion

Input format: `2026-09-10 14:23`  
Output format: `2026-09-10T14:23:00` (ISO 8601, local time)

```bash
convert_timestamp() {
    local ts="$1"
    # 2026-09-10 14:23 → 2026-09-10T14:23:00
    echo "$ts" | sed 's/ /T/' | sed 's/$/:00/'
}
```

### Empty Log Handling

```bash
$ read-cycle-evidence.sh empty-cycle-log.md --json
{"evidence":[]}
Exit code: 0
```

### Malformed Entries

**Missing phase**:
```markdown
## 2026-09-10 14:23 - A1
```
→ Skip entry, log warning to stderr

**Invalid phase**:
```markdown
## 2026-09-10 14:23 - YELLOW - A1
```
→ Skip entry, log warning to stderr (valid phases: RED, GREEN, REFACTOR)

**Missing behavior ID**:
```markdown
## 2026-09-10 14:23 - RED
```
→ Skip entry, log warning to stderr

**Partial entries**: If file ends without final `---`, include the last entry

---

## Examples

### Example 1: Basic Usage

**Input**: `cycle-log.md`
```markdown
## 2026-09-10 14:23 - RED - A1
Behavior: User can login
Evidence: Test fails.
---
```

**Command**:
```bash
read-cycle-evidence.sh specs/042/tdd/cycle-log.md
```

**Output**:
```text
Cycle Evidence: specs/042/tdd/cycle-log.md

Found 1 evidence entry:

[1] 2026-09-10 14:23 - RED - A1
    Behavior: User can login
    Evidence: Test fails.
```

### Example 2: JSON Output

**Command**:
```bash
read-cycle-evidence.sh specs/042/tdd/cycle-log.md --json | jq .
```

**Output**:
```json
{
  "evidence": [
    {
      "phase": "RED",
      "behavior_id": "A1",
      "timestamp": "2026-09-10T14:23:00",
      "evidence_text": "Test fails."
    }
  ]
}
```

### Example 3: Multiple Entries

**Input**: `cycle-log.md` with 3 complete cycles (RED → GREEN → REFACTOR)

**Command**:
```bash
read-cycle-evidence.sh cycle-log.md --json | jq '.evidence | length'
```

**Output**:
```text
3
```

### Example 4: Filter by Phase

**Command**:
```bash
read-cycle-evidence.sh cycle-log.md --json | jq '.evidence[] | select(.phase == "GREEN")'
```

**Output**: Only GREEN evidence entries

---

## Implementation Notes

### Three-Tier Parser Cascade

**Tier 1: Not applicable** (no jq — parsing markdown, not JSON input)

**Tier 2: python3**
```bash
if command -v python3 >/dev/null 2>&1; then
    evidence_json=$(python3 << 'PYTHON'
import re, json, sys
content = open(sys.argv[1]).read()
entries = re.split(r'^---$', content, flags=re.MULTILINE)
result = []
for entry in entries:
    match = re.match(r'^## ([0-9 :-]+) - ([A-Z]+) - ([A-Z0-9]+)', entry.strip())
    if match:
        ts, phase, bid = match.groups()
        evidence = re.search(r'^Evidence:(.*)', entry, re.DOTALL | re.MULTILINE)
        result.append({
            'phase': phase,
            'behavior_id': bid,
            'timestamp': ts.replace(' ', 'T') + ':00',
            'evidence_text': evidence.group(1).strip() if evidence else ''
        })
print(json.dumps({'evidence': result}))
PYTHON
"$cycle_log_path")
fi
```

**Tier 3: grep/sed/awk fallback**
```bash
if [[ -z "$evidence_json" ]]; then
    # Use awk to split entries, sed to parse headers, grep to extract evidence
    # (implementation details in research.md)
fi
```

### Safe JSON Construction

Use `jq --arg` for safe construction:

```bash
jq -cn --arg phase "$PHASE" --arg bid "$BID" --arg ts "$TIMESTAMP" --arg ev "$EVIDENCE" \
    '{phase:$phase,behavior_id:$bid,timestamp:$ts,evidence_text:$ev}'
```

### Handling Multiline Evidence

Evidence text may contain newlines, code blocks, and special characters:

```markdown
Evidence: Test fails with:
```
Expected: true
  Actual: false
```
```

**Solution**: Capture entire evidence body, preserve newlines:

```bash
evidence_text=$(echo "$entry" | sed -n '/^Evidence:/,$ p' | sed '1d')
# Use jq --arg to safely encode newlines
jq -cn --arg ev "$evidence_text" '{evidence_text:$ev}'
```

---

## Integration with TDD Workflow

This script is invoked by the `speckit-tdd-verify` skill to audit TDD discipline:

```bash
# 1. Read cycle evidence
evidence_json=$(.specify/scripts/bash/read-cycle-evidence.sh \
    specs/042-feature/tdd/cycle-log.md \
    --json)

# 2. Verify RED → GREEN → REFACTOR sequence
echo "$evidence_json" | jq '.evidence[] | select(.behavior_id == "A1") | .phase'
# Expected: "RED", "GREEN", "REFACTOR" in order

# 3. Check evidence quality
echo "$evidence_json" | jq '.evidence[] | select(.phase == "RED" and (.evidence_text | length) < 10)'
# Flags entries with insufficient evidence
```

---

## Error Handling

### Missing File

```bash
$ read-cycle-evidence.sh nonexistent.md
ERROR: cycle-log.md not found: nonexistent.md
Exit code: 1
```

### Unreadable File

```bash
$ read-cycle-evidence.sh /root/protected.md
ERROR: Cannot read file: /root/protected.md
Exit code: 1
```

### Malformed Entries (Non-Fatal)

Malformed entries are skipped with warnings to stderr, but script continues:

```bash
$ read-cycle-evidence.sh malformed.md 2>&1 | grep WARNING
WARNING: Skipping malformed entry at line 5: missing phase
WARNING: Skipping malformed entry at line 12: invalid phase 'YELLOW'
```

JSON output includes only valid entries:
```json
{
  "evidence": [
    // Only well-formed entries
  ]
}
```

---

## Validation

### Evidence Integrity Checks

The script does NOT validate:
- Whether behavior IDs exist in `test-list.md`
- Whether evidence text is sufficient/meaningful
- Whether phases follow correct RED → GREEN → REFACTOR sequence
- Whether timestamps are chronological

**Rationale**: Validation is the responsibility of the caller (`speckit-tdd-verify`). This script only parses and emits structured data.

### Empty Evidence

Evidence text can be empty (e.g., minimal logging):

```json
{
  "phase": "GREEN",
  "behavior_id": "A1",
  "timestamp": "2026-09-10T14:45:00",
  "evidence_text": ""
}
```

This is valid output — the caller decides if empty evidence is acceptable.

---

## Performance

### Large Logs

For logs with 100+ entries (~1000+ lines):
- **Tier 2 (python3)**: ~100ms
- **Tier 3 (awk/sed)**: ~500ms

The script is optimized for typical logs (10-50 entries).

### Memory Usage

Entire file is read into memory. For very large logs (>10MB):
- Consider streaming approach (future enhancement)
- Current implementation: acceptable for logs <1MB
