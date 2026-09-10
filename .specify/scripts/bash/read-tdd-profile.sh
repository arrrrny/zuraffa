#!/usr/bin/env bash
# Read TDD profile and emit test engine configuration

set -euo pipefail

# Parse command line arguments
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

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Get feature paths
_paths_output=$(get_feature_paths) || { echo "ERROR: Failed to resolve feature paths" >&2; exit 1; }
eval "$_paths_output"
unset _paths_output

# Define file path
TDD_PROFILE="$FEATURE_DIR/tdd-profile.md"

# Validate required file
if [[ ! -f "$TDD_PROFILE" ]]; then
    if $JSON_MODE; then
        echo '{"error":"tdd-profile.md not found","status":"missing"}'
    else
        echo "ERROR: tdd-profile.md not found in $FEATURE_DIR" >&2
    fi
    exit 1
fi

# Extract engine and test_command from tdd-profile.md (three-tier parser cascade)
extract_profile() {
    local file="$1"

    # Try python3 parser
    if command -v python3 >/dev/null 2>&1; then
        python3 -c "
import re, sys, json
with open('$file', 'r') as f:
    content = f.read()

    # Extract engine type
    engine_match = re.search(r'^\*\*Engine\*\*:\s*\`?([^\`\n]+)\`?', content, re.MULTILINE | re.IGNORECASE)
    engine = engine_match.group(1).strip() if engine_match else ''

    # Extract test command
    cmd_match = re.search(r'^\*\*Test Command\*\*:\s*\`?([^\`\n]+)\`?', content, re.MULTILINE | re.IGNORECASE)
    test_command = cmd_match.group(1).strip() if cmd_match else ''

    if not engine or not test_command:
        sys.exit(1)

    result = {'engine': engine, 'test_command': test_command}
    print(json.dumps(result))
" 2>/dev/null && return 0
    fi

    # Fallback to grep/sed
    local engine=$(grep -iE '^\*\*Engine\*\*:' "$file" | head -n 1 | sed -E 's/^\*\*Engine\*\*:[[:space:]]*`?([^`[:space:]]+).*/\1/' || true)
    local test_command=$(grep -iE '^\*\*Test Command\*\*:' "$file" | head -n 1 | sed -E 's/^\*\*Test Command\*\*:[[:space:]]*`?([^`]+)`?.*/\1/' | sed 's/`$//' || true)

    if [[ -z "$engine" ]] || [[ -z "$test_command" ]]; then
        return 1
    fi

    if command -v jq >/dev/null 2>&1; then
        jq -cn --arg engine "$engine" --arg cmd "$test_command" '{engine:$engine,test_command:$cmd}'
    else
        printf '{"engine":"%s","test_command":"%s"}\n' "$engine" "$test_command"
    fi
}

# Extract profile data
if ! profile_json=$(extract_profile "$TDD_PROFILE"); then
    if $JSON_MODE; then
        echo '{"error":"malformed tdd-profile.md","status":"parse_error"}'
    else
        echo "ERROR: tdd-profile.md is malformed or missing required fields" >&2
    fi
    exit 1
fi

# Output results
if $JSON_MODE; then
    echo "$profile_json"
else
    if command -v jq >/dev/null 2>&1; then
        engine=$(echo "$profile_json" | jq -r '.engine')
        test_command=$(echo "$profile_json" | jq -r '.test_command')
    else
        engine=$(echo "$profile_json" | grep -o '"engine":"[^"]*"' | cut -d'"' -f4)
        test_command=$(echo "$profile_json" | grep -o '"test_command":"[^"]*"' | cut -d'"' -f4)
    fi
    echo "Engine: $engine"
    echo "Test Command: $test_command"
fi
