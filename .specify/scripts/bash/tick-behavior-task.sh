#!/usr/bin/env bash
# Tick a specific behavior task as done in tasks.md

set -euo pipefail

# Parse command line arguments
JSON_MODE=false
BEHAVIOR_ID=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --json) JSON_MODE=true; shift ;;
        --behavior)
            BEHAVIOR_ID="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 --behavior <ID> [--json]"
            echo "  --behavior <ID>  Behavior ID to tick (e.g., A1, U5)"
            echo "  --json           Output results in JSON format"
            echo "  --help           Show this help message"
            exit 0
            ;;
        *) echo "ERROR: Unknown option '$1'" >&2; exit 1 ;;
    esac
done

# Validate behavior ID
if [[ -z "$BEHAVIOR_ID" ]]; then
    if $JSON_MODE; then
        echo '{"error":"behavior ID required","status":"missing_argument"}'
    else
        echo "ERROR: --behavior <ID> is required" >&2
    fi
    exit 1
fi

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Get feature paths
_paths_output=$(get_feature_paths) || { echo "ERROR: Failed to resolve feature paths" >&2; exit 1; }
eval "$_paths_output"
unset _paths_output

# Define file path
TASKS_FILE="$FEATURE_DIR/tasks.md"

# Validate required file
if [[ ! -f "$TASKS_FILE" ]]; then
    if $JSON_MODE; then
        echo '{"error":"tasks.md not found","status":"missing"}'
    else
        echo "ERROR: tasks.md not found in $FEATURE_DIR" >&2
    fi
    exit 1
fi

# Check if behavior ID exists in tasks.md
if ! grep -q "\[behavior: $BEHAVIOR_ID\]" "$TASKS_FILE"; then
    if $JSON_MODE; then
        echo "{\"error\":\"behavior ID not found\",\"behavior_id\":\"$BEHAVIOR_ID\",\"status\":\"not_found\"}"
    else
        echo "ERROR: Behavior ID '$BEHAVIOR_ID' not found in tasks.md" >&2
    fi
    exit 1
fi

# Check if already ticked
if grep -q "^- \[x\].*\[behavior: $BEHAVIOR_ID\]" "$TASKS_FILE"; then
    if $JSON_MODE; then
        echo "{\"status\":\"already_done\",\"behavior_id\":\"$BEHAVIOR_ID\",\"message\":\"Task already ticked\"}"
    else
        echo "Behavior $BEHAVIOR_ID is already ticked"
    fi
    exit 0
fi

# Tick the behavior task (three-tier parser cascade)
TEMP_FILE=$(mktemp)
trap 'rm -f "$TEMP_FILE"' EXIT

# Try python3 first
if command -v python3 >/dev/null 2>&1; then
    python3 -c "
import sys, re
with open('$TASKS_FILE', 'r') as f:
    content = f.read()
pattern = r'^- \\[ \\](.*\\[behavior: $BEHAVIOR_ID\\])'
replacement = r'- [x]\\1'
content = re.sub(pattern, replacement, content, flags=re.MULTILINE)
with open('$TEMP_FILE', 'w') as f:
    f.write(content)
" 2>/dev/null || sed "s/^- \\[ \\]\\(.*\\[behavior: $BEHAVIOR_ID\\]\\)/- [x]\\1/" "$TASKS_FILE" > "$TEMP_FILE"
else
    # Fallback to sed
    sed "s/^- \\[ \\]\\(.*\\[behavior: $BEHAVIOR_ID\\]\\)/- [x]\\1/" "$TASKS_FILE" > "$TEMP_FILE"
fi

# Atomic write: move temp to original
mv "$TEMP_FILE" "$TASKS_FILE"

# Output results
if $JSON_MODE; then
    if command -v jq >/dev/null 2>&1; then
        jq -cn \
            --arg status "success" \
            --arg id "$BEHAVIOR_ID" \
            '{status:$status,behavior_id:$id,message:"Task ticked"}'
    else
        echo "{\"status\":\"success\",\"behavior_id\":\"$BEHAVIOR_ID\",\"message\":\"Task ticked\"}"
    fi
else
    echo "Successfully ticked behavior: $BEHAVIOR_ID"
fi
