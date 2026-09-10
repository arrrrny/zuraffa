#!/usr/bin/env bash
# Read TDD profile and emit test engine configuration
#
# Contract: specs/1444-spec-kit-boundary-scripts/contracts/read-tdd-profile.md
#   read-tdd-profile.sh <tdd-profile-path> [--json]

set -euo pipefail

JSON_MODE=false
PROFILE_ARG=""

usage() {
    cat <<'EOF'
Usage: read-tdd-profile.sh <tdd-profile-path> [--json]

  <tdd-profile-path>  Path to tdd-profile.md (default: .specify/memory/tdd-profile.md)
  --json              Output results in JSON format
  --help, -h          Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --json) JSON_MODE=true; shift ;;
        --help|-h) usage; exit 0 ;;
        -*) echo "ERROR: Unknown option '$1'" >&2; exit 1 ;;
        *) PROFILE_ARG="$1"; shift ;;
    esac
done

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# The documented positional path wins; otherwise use the repo-level profile that
# the tdd extension writes (`.specify/memory/tdd-profile.md`).
if [[ -n "$PROFILE_ARG" ]]; then
    TDD_PROFILE="$PROFILE_ARG"
else
    REPO_ROOT="$(get_repo_root)"
    TDD_PROFILE="$REPO_ROOT/.specify/memory/tdd-profile.md"
fi

json_escape() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\r'/\\r}"
    s="${s//$'\t'/\\t}"
    printf '%s' "$s"
}

if [[ ! -f "$TDD_PROFILE" ]]; then
    if $JSON_MODE; then
        echo "{\"error\":\"tdd-profile.md not found\",\"path\":\"$(json_escape "$TDD_PROFILE")\",\"status\":\"missing\"}"
    fi
    echo "ERROR: tdd-profile.md not found: $TDD_PROFILE" >&2
    exit 1
fi

# Emit the YAML frontmatter block (between the leading `---` and the next `---`).
# A missing closing delimiter is tolerated: the block then runs to EOF.
extract_frontmatter() {
    local file="$1"
    local first
    first="$(head -n 1 "$file" || true)"
    if [[ "$first" != "---" ]]; then
        return 1
    fi
    awk 'NR > 1 && /^---[[:space:]]*$/ { exit } NR > 1 { print }' "$file"
    return 0
}

# Three-tier cascade: yq -> python3 (PyYAML) -> grep/sed. The first declaration
# of a field wins.
extract_field() {
    local field="$1"
    local value=""

    if command -v yq >/dev/null 2>&1; then
        if value="$(printf '%s\n' "$FRONTMATTER" | yq -r ".${field} // \"\"" 2>/dev/null)"; then
            if [[ -n "$value" && "$value" != "null" ]]; then
                printf '%s' "$value"
                return 0
            fi
        fi
        value=""
    fi

    if command -v python3 >/dev/null 2>&1; then
        if value="$(printf '%s\n' "$FRONTMATTER" | python3 -c '
import sys
field = sys.argv[1]
try:
    import yaml
except Exception:
    sys.exit(2)
try:
    data = yaml.safe_load(sys.stdin.read())
except Exception:
    sys.exit(2)
if not isinstance(data, dict):
    sys.exit(2)
value = data.get(field)
if value is None:
    sys.exit(0)
print(value)
' "$field" 2>/dev/null)"; then
            if [[ -n "$value" ]]; then
                printf '%s' "$value"
                return 0
            fi
        fi
        value=""
    fi

    value="$(printf '%s\n' "$FRONTMATTER" \
        | grep -E "^[[:space:]]*${field}[[:space:]]*:" \
        | head -n 1 \
        | sed -E "s/^[[:space:]]*${field}[[:space:]]*:[[:space:]]*//" \
        | sed -E "s/[[:space:]]+#.*$//" \
        | sed -E "s/^['\"]//; s/['\"]\$//" \
        || true)"
    if [[ -n "$value" ]]; then
        printf '%s' "$value"
        return 0
    fi
    return 1
}

if ! FRONTMATTER="$(extract_frontmatter "$TDD_PROFILE")"; then
    echo "ERROR: No YAML frontmatter found in $TDD_PROFILE" >&2
    echo "Expected format:" >&2
    echo "---" >&2
    echo "engine: <engine_type>" >&2
    echo "test_command: <command>" >&2
    echo "---" >&2
    exit 1
fi

ENGINE="$(extract_field engine || true)"
TEST_COMMAND="$(extract_field test_command || true)"
VERIFY_COMMAND="$(extract_field verify_command || true)"
PLAN_COMMAND="$(extract_field plan_command || true)"

if [[ -z "$ENGINE" ]]; then
    echo "ERROR: Missing required field 'engine' in $TDD_PROFILE" >&2
    exit 1
fi
if [[ -z "$TEST_COMMAND" ]]; then
    echo "ERROR: Missing required field 'test_command' in $TDD_PROFILE" >&2
    exit 1
fi

if $JSON_MODE; then
    if command -v jq >/dev/null 2>&1; then
        jq -cn \
            --arg engine "$ENGINE" \
            --arg test_command "$TEST_COMMAND" \
            --arg verify_command "$VERIFY_COMMAND" \
            --arg plan_command "$PLAN_COMMAND" \
            '{engine:$engine,test_command:$test_command,
              verify_command:(if $verify_command == "" then null else $verify_command end),
              plan_command:(if $plan_command == "" then null else $plan_command end)}'
    else
        optional_json() {
            if [[ -z "$1" ]]; then
                printf 'null'
            else
                printf '"%s"' "$(json_escape "$1")"
            fi
        }
        printf '{"engine":"%s","test_command":"%s","verify_command":%s,"plan_command":%s}\n' \
            "$(json_escape "$ENGINE")" \
            "$(json_escape "$TEST_COMMAND")" \
            "$(optional_json "$VERIFY_COMMAND")" \
            "$(optional_json "$PLAN_COMMAND")"
    fi
else
    printf 'TDD Profile: %s\n\n' "$TDD_PROFILE"
    echo "Engine: $ENGINE"
    echo "Test Command: $TEST_COMMAND"
    echo "Verify Command: ${VERIFY_COMMAND:-(not configured)}"
    echo "Plan Command: ${PLAN_COMMAND:-(not configured)}"
fi
