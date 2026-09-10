# Research: Bash Scripting Best Practices for Spec-Kit Boundary Operations

**Feature**: 1444-spec-kit-boundary-scripts  
**Date**: 2026-09-10  
**Purpose**: Research bash scripting patterns, three-tier parser cascades, and atomic file operations for deterministic spec-kit boundary scripts

---

## 1. Bash Scripting Best Practices

### 1.1 Fail-Fast Pattern: `set -euo pipefail`

The reference implementation `setup-tasks.sh` uses `set -e` only. For the new scripts, we should use the full fail-fast pattern:

```bash
#!/usr/bin/env bash
set -euo pipefail
```

**What each flag does**:
- `set -e`: Exit immediately if any command exits with non-zero status
- `set -u`: Treat unset variables as errors (prevents silent bugs from typos)
- `set -o pipefail`: Fail if any command in a pipeline fails (not just the last one)

**Exception**: The reference implementation uses `set -e` without `-u` because it explicitly checks for unset variables like `${SPECIFY_INIT_DIR:-}`. We should follow this pattern for compatibility with the existing `common.sh` helpers.

**Recommendation**: Use `set -e` (matching `setup-tasks.sh`) and rely on explicit `${VAR:-}` expansions for optional variables.

### 1.2 Argument Parsing Pattern

From `setup-tasks.sh`:

```bash
JSON_MODE=false

for arg in "$@"; do
    case "$arg" in
        --json) JSON_MODE=true ;;
        --help|-h)
            echo "Usage: $0 [--json]"
            echo "  --json    Output results in JSON format"
            echo "  --help    Show this help message"
            exit 0
            ;;
        *) echo "ERROR: Unknown option '$arg'" >&2; exit 1 ;;
    esac
done
```

**Pattern**:
- Use a `for` loop instead of `while` + `shift` for simplicity
- Boolean flags default to `false`
- Unknown options trigger errors with `>&2` (stderr) and `exit 1`
- Help text shows usage and exits with `exit 0`

**For our scripts**: Add behavior-specific flags like `--behavior <id>` for `tick-behavior-task.sh`

### 1.3 Error Messages to stderr

All error messages MUST go to stderr (`>&2`) so JSON output on stdout remains parseable:

```bash
echo "ERROR: file not found: $path" >&2
exit 1
```

**Pattern from setup-tasks.sh**:
```bash
if [[ ! -f "$IMPL_PLAN" ]]; then
    echo "ERROR: plan.md not found in $FEATURE_DIR" >&2
    echo "Run /speckit-plan first to create the implementation plan." >&2
    exit 1
fi
```

### 1.4 Sourcing Common Functions

All scripts should source `common.sh` for shared utilities:

```bash
SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
```

**Why `CDPATH=""`**: Prevents `cd` from echoing to stdout when CDPATH is set in user's environment, which would corrupt captured paths.

---

## 2. Three-Tier Parser Cascade

### 2.1 The Cascade Pattern

From `read_feature_json_feature_directory()` in `common.sh`:

**Tier 1: jq (preferred)**
- Fastest, most robust JSON parser
- Handles pretty-printed/multi-line JSON correctly
- Available on most dev machines

**Tier 2: python3 (fallback)**
- Slower but still robust
- **Caveat**: On Windows, `command -v python3` may resolve to Microsoft Store stub that fails at runtime (exit 49)
- Must test by *actually running* the parser, not just checking availability

**Tier 3: grep/sed (last resort)**
- Works only for simple, single-line patterns
- Fragile but always available
- Use `|| true` to prevent `set -e` from aborting on no match

### 2.2 Implementation Pattern

```bash
local result=''

# Tier 1: jq
if command -v jq >/dev/null 2>&1; then
    if ! result=$(jq -r '.field // empty' "$file" 2>/dev/null); then
        result=''
    fi
fi

# Tier 2: python3
if [[ -z "$result" ]] && command -v python3 >/dev/null 2>&1; then
    if ! result=$(python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(d.get('field', ''))" "$file" 2>/dev/null); then
        result=''
    fi
fi

# Tier 3: grep/sed
if [[ -z "$result" ]]; then
    result=$( { grep -E '"field"[[:space:]]*:' "$file" 2>/dev/null || true; } \
        | head -n 1 \
        | sed -E 's/^[^:]*:[[:space:]]*"([^"]*)".*$/\1/' )
fi

printf '%s' "$result"
```

**Key insights**:
1. Selection is by *parse success*, not mere availability
2. Each tier returns empty string on failure and falls through
3. Use `2>/dev/null` to silence errors from failed parsers
4. The `|| true` guards against `set -e` aborting on grep no-match

### 2.3 JSON Construction with jq

**CRITICAL SECURITY PATTERN**: Use `jq --arg` to safely construct JSON, never string interpolation.

```bash
# GOOD: Safe from injection
jq -cn \
    --arg behavior_id "$BEHAVIOR_ID" \
    --arg status "$STATUS" \
    '{behavior_id:$behavior_id,status:$status}'

# BAD: Vulnerable to injection if $BEHAVIOR_ID contains quotes
echo "{\"behavior_id\":\"$BEHAVIOR_ID\",\"status\":\"$STATUS\"}"
```

**For arrays**:
```bash
# Convert bash array to JSON array
if [[ ${#items[@]} -eq 0 ]]; then
    json_items="[]"
else
    json_items=$(printf '%s\n' "${items[@]}" | jq -R . | jq -s .)
fi

jq -cn --argjson items "$json_items" '{items:$items}'
```

**Fallback without jq**:
```bash
# Helper function from common.sh
json_escape() {
    local str="$1"
    str="${str//\\/\\\\}"  # escape backslashes
    str="${str//\"/\\\"}"  # escape quotes
    str="${str//$'\n'/\\n}" # escape newlines
    str="${str//$'\r'/\\r}" # escape carriage returns
    str="${str//$'\t'/\\t}" # escape tabs
    printf '%s' "$str"
}

# Construct JSON manually
printf '{"behavior_id":"%s","status":"%s"}\n' \
    "$(json_escape "$BEHAVIOR_ID")" "$(json_escape "$STATUS")"
```

---

## 3. Atomic File Operations

### 3.1 The Write-Temp-Then-Move Pattern

**Problem**: Direct writes (`>` redirection) can corrupt files if interrupted.

**Solution**: Write to temp file, then atomic move:

```bash
local temp_file
temp_file=$(mktemp) || { echo "ERROR: Failed to create temp file" >&2; exit 1; }

# Write to temp file
{
    echo "# Updated content"
    cat existing_content.md
} > "$temp_file"

# Atomic move (rename is atomic on POSIX systems)
mv "$temp_file" "$target_file" || {
    echo "ERROR: Failed to update $target_file" >&2
    rm -f "$temp_file"
    exit 1
}
```

**Why this works**:
1. `mktemp` creates a unique temp file in `/tmp` (or `$TMPDIR`)
2. All writes go to temp file (if interrupted, original is unchanged)
3. `mv` is atomic: either fully succeeds or fully fails
4. No partial writes visible to concurrent readers

### 3.2 Preserving File Content During Partial Updates

**Pattern**: Read entire file, modify in memory, write atomically

```bash
# Read current content
local content
content=$(cat "$file") || { echo "ERROR: Failed to read $file" >&2; exit 1; }

# Modify specific lines
local updated_content
updated_content=$(echo "$content" | sed 's/\[ \] \(.*\[behavior: '"$behavior_id"'\]\)/[x] \1/')

# Write atomically
local temp_file
temp_file=$(mktemp)
echo "$updated_content" > "$temp_file"
mv "$temp_file" "$file"
```

**For large files**: Use `awk` or `sed -i.bak` with atomic move

```bash
# Create backup, modify in place, verify, clean up
cp "$file" "$file.bak"
sed -i.tmp 's/pattern/replacement/' "$file"
# Verify modification succeeded
if grep -q "expected_result" "$file"; then
    rm -f "$file.bak" "$file.tmp"
else
    echo "ERROR: Modification failed, restoring backup" >&2
    mv "$file.bak" "$file"
    rm -f "$file.tmp"
    exit 1
fi
```

### 3.3 Cleanup Traps

**Pattern**: Always clean up temp files, even on error

```bash
temp_file=$(mktemp)
trap "rm -f '$temp_file'" EXIT

# ... do work with temp_file ...

# Trap ensures cleanup even if script exits early
```

**Multiple temp files**:
```bash
temp_dir=$(mktemp -d)
trap "rm -rf '$temp_dir'" EXIT

# Create temp files in temp dir
temp_file1="$temp_dir/file1"
temp_file2="$temp_dir/file2"
# ... work ...
```

---

## 4. Markdown Parsing Strategies

### 4.1 Parsing Behavior Markers

**Pattern**: `[behavior: <id>]` markers in tasks.md

```bash
# Extract all behavior IDs
grep -o '\[behavior: [^]]*\]' tasks.md | sed 's/\[behavior: \([^]]*\)\]/\1/'

# Find specific behavior marker line
grep -n '\[behavior: '"$behavior_id"'\]' tasks.md | cut -d: -f1

# Check if behavior task is done
grep '\[x\].*\[behavior: '"$behavior_id"'\]' tasks.md >/dev/null
```

**Edge cases**:
- Markers without IDs: `\[behavior: [^]]+\]` ensures at least one char
- Malformed markers: Skip lines without proper `- [ ]` or `- [x]` checkbox
- Case sensitivity: Use `-i` flag for case-insensitive matching if needed

### 4.2 Parsing Test List (test-list.md)

**Structure** (from TDD profile conventions):

```markdown
## Acceptance Tests

- **A1**: User can login with email and password
- **A2**: User sees error message on invalid credentials

## Unit Tests

- **U1**: `validateEmail` returns true for valid emails
- **U2**: `validateEmail` returns false for invalid emails
```

**Parsing pattern**:

```bash
# Extract behavior IDs (A1, A2, U1, U2)
grep -E '^- \*\*[A-Z0-9]+\*\*:' test-list.md | sed -E 's/^- \*\*([A-Z0-9]+)\*\*:.*/\1/'

# Extract full behavior entries
grep -E '^- \*\*[A-Z0-9]+\*\*:' test-list.md
```

### 4.3 Parsing TDD Profile (tdd-profile.md)

**Structure** (YAML frontmatter + markdown):

```markdown
---
engine: dart_test
test_command: dart test
verify_command: dart test --coverage
---

# TDD Profile: Dart Test
...
```

**Parsing YAML frontmatter**:

```bash
# Extract YAML block (between --- delimiters)
sed -n '/^---$/,/^---$/p' tdd-profile.md | sed '1d;$d'

# Parse specific field
sed -n '/^---$/,/^---$/p' tdd-profile.md \
    | grep '^engine:' \
    | sed 's/^engine:[[:space:]]*//'
```

**With three-tier cascade**:

```bash
# Tier 1: yq (YAML processor, like jq for YAML)
if command -v yq >/dev/null 2>&1; then
    engine=$(yq -r '.engine' tdd-profile.md 2>/dev/null)
fi

# Tier 2: python3 with pyyaml
if [[ -z "$engine" ]] && command -v python3 >/dev/null 2>&1; then
    engine=$(python3 -c "import yaml,sys; print(yaml.safe_load(open(sys.argv[1]))['engine'])" tdd-profile.md 2>/dev/null)
fi

# Tier 3: grep/sed
if [[ -z "$engine" ]]; then
    engine=$(sed -n '/^---$/,/^---$/p' tdd-profile.md | grep '^engine:' | sed 's/^engine:[[:space:]]*//')
fi
```

### 4.4 Parsing Cycle Evidence (cycle-log.md)

**Structure** (evidence entries):

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
```

**Parsing pattern**:

```bash
# Extract evidence entries (split on --- delimiter)
awk '/^## [0-9]{4}-[0-9]{2}-[0-9]{2}/ {
    if (entry) print entry;
    entry=$0;
    next;
}
/^---$/ {
    if (entry) print entry;
    entry="";
    next;
}
{
    if (entry) entry=entry"\n"$0;
}
END {
    if (entry) print entry;
}' cycle-log.md
```

**Extracting structured data**:

```bash
# Parse header: timestamp, phase, behavior_id
echo "## 2026-09-10 14:23 - RED - A1" \
    | sed -E 's/^## ([0-9 :-]+) - ([A-Z]+) - ([A-Z0-9]+)$/\1|\2|\3/'
# Output: 2026-09-10 14:23|RED|A1
```

---

## 5. Common Pitfalls and Solutions

### 5.1 Quoting Variables

**Always quote variables** to prevent word splitting:

```bash
# BAD: Breaks if $file contains spaces
if [ -f $file ]; then

# GOOD: Works with spaces
if [[ -f "$file" ]]; then
```

### 5.2 Using `[[` vs `[`

Prefer `[[` over `[` for conditionals:

- `[[` is a bash keyword (more features, safer)
- `[` is a POSIX command (fewer features, more portable)

**Recommendation**: Use `[[` since we're already bash-specific

### 5.3 Command Substitution

Prefer `$(cmd)` over backticks:

```bash
# GOOD: Nestable, clear
result=$(command arg)

# BAD: Hard to nest, confusing
result=`command arg`
```

### 5.4 Checking Exit Status

Check command success explicitly:

```bash
# Pattern 1: Inline check
if ! command; then
    echo "ERROR: command failed" >&2
    exit 1
fi

# Pattern 2: Capture output and check
output=$(command) || { echo "ERROR: command failed" >&2; exit 1; }
```

---

## 6. Testing Strategy

### 6.1 Manual Testing with Sample Inputs

Create test fixtures in `test/fixtures/bash_scripts/`:

```text
test/fixtures/bash_scripts/
├── test-list-sample.md
├── tdd-profile-sample.md
├── cycle-log-sample.md
└── tasks-sample.md
```

Run scripts against fixtures:

```bash
.specify/scripts/bash/read-tdd-profile.sh \
    test/fixtures/bash_scripts/tdd-profile-sample.md \
    --json | jq .
```

### 6.2 Integration Tests in Dart

Use Dart's `Process.run()` to spawn scripts and verify output:

```dart
test('read-tdd-profile emits valid JSON', () async {
  final result = await Process.run(
    '.specify/scripts/bash/read-tdd-profile.sh',
    ['test/fixtures/bash_scripts/tdd-profile-sample.md', '--json'],
  );
  
  expect(result.exitCode, 0);
  
  final json = jsonDecode(result.stdout);
  expect(json['engine'], 'dart_test');
  expect(json['test_command'], 'dart test');
});
```

### 6.3 Error Case Testing

Verify scripts handle malformed input gracefully:

```bash
# Test missing file
.specify/scripts/bash/read-tdd-profile.sh nonexistent.md
# Expected: error message to stderr, exit 1

# Test malformed file
echo "invalid content" > /tmp/bad-profile.md
.specify/scripts/bash/read-tdd-profile.sh /tmp/bad-profile.md --json
# Expected: error message to stderr, exit 1
```

---

## 7. Summary: Key Patterns to Follow

1. **Fail-fast**: Use `set -e` (matching `setup-tasks.sh`)
2. **Three-tier cascade**: jq → python3 → grep/sed for parsing
3. **Safe JSON construction**: Use `jq --arg`, never string interpolation
4. **Atomic writes**: Write to temp file, then `mv`
5. **Error messages to stderr**: All `echo "ERROR: ..." >&2`
6. **Source common.sh**: Reuse shared helpers
7. **Quote all variables**: `"$var"`, not `$var`
8. **Trap cleanup**: `trap "rm -f '$temp'" EXIT`
9. **Explicit exit codes**: `exit 0` on success, `exit 1` on error
10. **Help text**: Support `--help` flag for all scripts

---

## References

- `scripts/bash/setup-tasks.sh`: Reference implementation for argument parsing, JSON output, common.sh usage
- `scripts/bash/common.sh`: Shared helpers for repo root, feature paths, three-tier parsing
- Bash manual: https://www.gnu.org/software/bash/manual/
- jq manual: https://stedolan.github.io/jq/manual/
