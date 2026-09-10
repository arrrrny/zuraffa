#!/usr/bin/env bash
# Sync behaviors from test-list.md to tasks.md

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

# Define file paths
TEST_LIST="$FEATURE_DIR/tdd/test-list.md"
TASKS_FILE="$FEATURE_DIR/tasks.md"

# Validate required files
if [[ ! -f "$TEST_LIST" ]]; then
    if $JSON_MODE; then
        echo '{"error":"test-list.md not found","status":"missing"}'
    else
        echo "ERROR: test-list.md not found in $FEATURE_DIR/tdd/" >&2
    fi
    exit 1
fi

if [[ ! -f "$TASKS_FILE" ]]; then
    if $JSON_MODE; then
        echo '{"error":"tasks.md not found","status":"missing"}'
    else
        echo "ERROR: tasks.md not found in $FEATURE_DIR" >&2
    fi
    exit 1
fi

# Extract behavior IDs from test-list.md (three-tier parser cascade)
extract_behavior_ids() {
    local file="$1"
    local ids=()

    # Try jq first (not applicable for markdown, skip)
    # Try python3 next
    if command -v python3 >/dev/null 2>&1; then
        readarray -t ids < <(python3 -c "
import re, sys
with open('$file', 'r') as f:
    content = f.read()
    # Match **A1**: or **U1**: patterns
    matches = re.findall(r'^\*\*([AU]\d+)\*\*:', content, re.MULTILINE)
    for match in matches:
        print(match)
" 2>/dev/null || true)
    fi

    # Fallback to grep/sed
    if [[ ${#ids[@]} -eq 0 ]]; then
        readarray -t ids < <(grep -E '^\*\*[AU][0-9]+\*\*:' "$file" | sed -E 's/^\*\*([AU][0-9]+)\*\*:.*/\1/' || true)
    fi

    printf '%s\n' "${ids[@]}"
}

# Get existing behavior markers from tasks.md
get_existing_markers() {
    grep -o '\[behavior: [AU][0-9]\+\]' "$TASKS_FILE" | sed 's/\[behavior: \(.*\)\]/\1/' || true
}

# Extract behavior IDs
behavior_ids=($(extract_behavior_ids "$TEST_LIST"))

# Check if test-list is empty
if [[ ${#behavior_ids[@]} -eq 0 ]]; then
    if $JSON_MODE; then
        echo '{"status":"success","message":"No behaviors found in test-list.md","behaviors_added":0}'
    else
        echo "No behaviors found in test-list.md"
    fi
    exit 0
fi

# Get existing markers
existing_markers=($(get_existing_markers))

# Find behaviors that need to be added
behaviors_to_add=()
for id in "${behavior_ids[@]}"; do
    found=false
    for existing in "${existing_markers[@]}"; do
        if [[ "$id" == "$existing" ]]; then
            found=true
            break
        fi
    done
    if [[ "$found" == false ]]; then
        behaviors_to_add+=("$id")
    fi
done

# If no new behaviors, exit successfully
if [[ ${#behaviors_to_add[@]} -eq 0 ]]; then
    if $JSON_MODE; then
        echo '{"status":"success","message":"All behaviors already present","behaviors_added":0}'
    else
        echo "All behaviors already present in tasks.md"
    fi
    exit 0
fi

# Insert behavior markers into tasks.md
# Strategy: Find a good insertion point (after first ## Phase header) and insert tasks
TEMP_FILE=$(mktemp)
trap 'rm -f "$TEMP_FILE"' EXIT

# Find insertion point: after the first phase header
insertion_done=false
while IFS= read -r line; do
    echo "$line" >> "$TEMP_FILE"

    # Insert after first phase header that contains tasks
    if [[ ! "$insertion_done" == true ]] && echo "$line" | grep -qE '^## Phase'; then
        # Read ahead to find where to insert (after the task list starts)
        echo "" >> "$TEMP_FILE"
        for behavior_id in "${behaviors_to_add[@]}"; do
            echo "- [ ] Implement behavior $behavior_id [behavior: $behavior_id]" >> "$TEMP_FILE"
        done
        insertion_done=true
    fi
done < "$TASKS_FILE"

# Atomic write: move temp to original
mv "$TEMP_FILE" "$TASKS_FILE"

# Output results
if $JSON_MODE; then
    if command -v jq >/dev/null 2>&1; then
        behaviors_json=$(printf '%s\n' "${behaviors_to_add[@]}" | jq -R . | jq -s .)
        jq -cn \
            --arg status "success" \
            --arg count "${#behaviors_to_add[@]}" \
            --argjson behaviors "$behaviors_json" \
            '{status:$status,behaviors_added:($count|tonumber),behaviors:$behaviors}'
    else
        behaviors_json=$(printf '"%s",' "${behaviors_to_add[@]}")
        behaviors_json="[${behaviors_json%,}]"
        echo "{\"status\":\"success\",\"behaviors_added\":${#behaviors_to_add[@]},\"behaviors\":$behaviors_json}"
    fi
else
    echo "Successfully added ${#behaviors_to_add[@]} behavior marker(s) to tasks.md:"
    for id in "${behaviors_to_add[@]}"; do
        echo "  - $id"
    done
fi
