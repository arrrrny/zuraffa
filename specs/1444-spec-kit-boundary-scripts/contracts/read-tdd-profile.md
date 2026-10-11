# Contract: read-tdd-profile.sh

**Script**: `.specify/scripts/bash/read-tdd-profile.sh`  
**Purpose**: Parse `tdd-profile.md` and emit JSON with test engine type and commands

---

## Synopsis

```bash
read-tdd-profile.sh <tdd-profile-path> [--json]
```

---

## Description

Reads the TDD stack configuration from `tdd-profile.md` and extracts the test engine type and associated commands. This replaces fragile LLM-based markdown parsing with deterministic YAML frontmatter extraction using the three-tier parser cascade (yq → python3 → grep/sed).

The script:
1. Locates YAML frontmatter between `---` delimiters
2. Parses required fields: `engine`, `test_command`
3. Parses optional fields: `verify_command`, `plan_command`
4. Emits structured output (JSON or human-readable)

---

## Arguments

### Positional Arguments

| Argument | Required | Description |
|----------|----------|-------------|
| `<tdd-profile-path>` | Yes | Path to `tdd-profile.md` containing TDD configuration |

### Flags

| Flag | Description |
|------|-------------|
| `--json` | Emit JSON output instead of human-readable text |
| `--help`, `-h` | Show usage information and exit |

---

## Input Format

### tdd-profile.md

```markdown
---
engine: dart_test
test_command: dart test
verify_command: dart test --coverage
plan_command: dart test --list
---

# TDD Profile: Dart Test

This project uses Dart's built-in test framework for unit and integration testing.

## Usage

Run tests with:
```bash
dart test
```
```

**YAML Frontmatter Rules**:
- Must be enclosed between `---` delimiters at file start
- Required fields: `engine`, `test_command`
- Optional fields: `verify_command`, `plan_command`
- Field format: `key: value` (standard YAML)

---

## Output Format

### Human-Readable (default)

```text
TDD Profile: .specify/memory/tdd-profile.md

Engine: dart_test
Test Command: dart test
Verify Command: dart test --coverage
Plan Command: dart test --list
```

### JSON Output (--json)

```json
{
  "engine": "dart_test",
  "test_command": "dart test",
  "verify_command": "dart test --coverage",
  "plan_command": "dart test --list"
}
```

**Field Descriptions**:
- `engine`: Test framework identifier (e.g., `dart_test`, `flutter_test`, `jest`, `pytest`)
- `test_command`: Command to run tests
- `verify_command`: Command to run verification/coverage (optional, may be `null`)
- `plan_command`: Command to list/plan tests (optional, may be `null`)

---

## Exit Codes

| Code | Meaning |
|------|---------|
| `0` | Success: profile parsed and emitted |
| `1` | Error: file not found, missing YAML frontmatter, or required fields missing |

---

## Behavior Details

### YAML Parsing with Three-Tier Cascade

**Tier 1: yq (YAML processor)**
```bash
if command -v yq >/dev/null 2>&1; then
    engine=$(yq -r '.engine' "$profile_path" 2>/dev/null)
fi
```

**Tier 2: python3 with yaml module**
```bash
if [[ -z "$engine" ]] && command -v python3 >/dev/null 2>&1; then
    engine=$(python3 -c "import yaml,sys; print(yaml.safe_load(open(sys.argv[1]))['engine'])" "$profile_path" 2>/dev/null)
fi
```

**Tier 3: grep/sed fallback**
```bash
if [[ -z "$engine" ]]; then
    engine=$(sed -n '/^---$/,/^---$/p' "$profile_path" | grep '^engine:' | sed 's/^engine:[[:space:]]*//')
fi
```

### Missing File Handling

```bash
$ read-tdd-profile.sh nonexistent.md
ERROR: tdd-profile.md not found: nonexistent.md
Exit code: 1
```

### Missing YAML Frontmatter

```bash
$ read-tdd-profile.sh no-frontmatter.md
ERROR: No YAML frontmatter found in no-frontmatter.md
Expected format:
---
engine: <engine_type>
test_command: <command>
---
Exit code: 1
```

### Missing Required Fields

```bash
$ read-tdd-profile.sh incomplete.md
ERROR: Missing required field 'test_command' in incomplete.md
Exit code: 1
```

### Multiple Engine Declarations

**Policy**: Take the first engine declaration, ignore subsequent

```yaml
---
engine: dart_test
test_command: dart test
engine: flutter_test  # Ignored
---
```

Result: `engine: dart_test`

---

## Examples

### Example 1: Dart Test Profile

**Input**: `.specify/memory/tdd-profile.md`
```markdown
---
engine: dart_test
test_command: dart test
verify_command: dart test --coverage
---

# TDD Profile: Dart Test
...
```

**Command**:
```bash
read-tdd-profile.sh .specify/memory/tdd-profile.md
```

**Output**:
```text
TDD Profile: .specify/memory/tdd-profile.md

Engine: dart_test
Test Command: dart test
Verify Command: dart test --coverage
Plan Command: (not configured)
```

### Example 2: JSON Output

**Command**:
```bash
read-tdd-profile.sh .specify/memory/tdd-profile.md --json | jq .
```

**Output**:
```json
{
  "engine": "dart_test",
  "test_command": "dart test",
  "verify_command": "dart test --coverage",
  "plan_command": null
}
```

### Example 3: Flutter Test Profile

**Input**: `tdd-profile.md`
```markdown
---
engine: flutter_test
test_command: flutter test
verify_command: flutter test --coverage
plan_command: flutter test --dry-run
---
```

**Command**:
```bash
read-tdd-profile.sh tdd-profile.md --json
```

**Output**:
```json
{
  "engine": "flutter_test",
  "test_command": "flutter test",
  "verify_command": "flutter test --coverage",
  "plan_command": "flutter test --dry-run"
}
```

---

## Implementation Notes

### Safe JSON Construction

Use `jq --arg` for safe JSON output:

```bash
jq -cn \
    --arg engine "$ENGINE" \
    --arg test_cmd "$TEST_COMMAND" \
    --arg verify_cmd "${VERIFY_COMMAND:-null}" \
    --arg plan_cmd "${PLAN_COMMAND:-null}" \
    '{
        engine: $engine,
        test_command: $test_cmd,
        verify_command: ($verify_cmd | if . == "null" then null else . end),
        plan_command: ($plan_cmd | if . == "null" then null else . end)
    }'
```

### Fallback without jq

```bash
json_escape() {
    local str="$1"
    str="${str//\\/\\\\}"
    str="${str//\"/\\\"}"
    printf '%s' "$str"
}

printf '{"engine":"%s","test_command":"%s","verify_command":%s,"plan_command":%s}\n' \
    "$(json_escape "$ENGINE")" \
    "$(json_escape "$TEST_COMMAND")" \
    "${VERIFY_COMMAND:+\"$(json_escape "$VERIFY_COMMAND")\"}" \
    "${PLAN_COMMAND:+\"$(json_escape "$PLAN_COMMAND")\"}"
```

### YAML Extraction Pattern

```bash
extract_yaml_frontmatter() {
    local file="$1"
    sed -n '/^---$/,/^---$/p' "$file" | sed '1d;$d'
}

parse_yaml_field() {
    local yaml_content="$1"
    local field="$2"
    echo "$yaml_content" | grep "^$field:" | sed "s/^$field:[[:space:]]*//"
}
```

---

## Integration with TDD Workflow

This script is invoked by the `speckit-tdd-run` and `speckit-tdd-verify` skills to determine which test commands to execute:

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

This ensures test execution is always consistent with the configured TDD stack.

---

## Error Handling

### Malformed YAML

**Invalid YAML syntax**:
```yaml
---
engine: dart_test
test_command dart test  # Missing colon
---
```

→ **Tier 1 (yq) fails**, fall back to **Tier 2 (python3)**  
→ **Tier 2 fails**, fall back to **Tier 3 (grep/sed)**  
→ **Tier 3** extracts `engine` successfully, but `test_command` is empty  
→ **Error**: Missing required field 'test_command'

### Empty File

```bash
$ read-tdd-profile.sh empty.md
ERROR: No YAML frontmatter found in empty.md
Exit code: 1
```

### Partial Frontmatter

```markdown
---
engine: dart_test
```
(missing closing `---`)

→ **Tier 1/2 fail**, **Tier 3** matches everything from first `---` to EOF  
→ May extract fields successfully if they're present  
→ Otherwise, error on missing required fields

---

## Validation

### Field Validation

The script does NOT validate:
- Engine type validity (any string is accepted)
- Command executability (commands are not tested)
- Command syntax (strings are passed through as-is)

**Rationale**: Validation is the responsibility of the caller (TDD skills). This script only parses and emits structured data.

### Optional Fields

Optional fields are emitted as `null` in JSON when missing:

```json
{
  "engine": "dart_test",
  "test_command": "dart test",
  "verify_command": null,
  "plan_command": null
}
```

In human-readable format, they show as `(not configured)`.
