#!/usr/bin/env bash
# Tick a specific behavior task as done in tasks.md
#
# Contract: specs/1444-spec-kit-boundary-scripts/contracts/tick-behavior-task.md
#   tick-behavior-task.sh <tasks-path> --behavior <id> [--json]

set -euo pipefail

JSON_MODE=false
BEHAVIOR_ID=""
TASKS_ARG=""

usage() {
    cat <<'EOF'
Usage: tick-behavior-task.sh <tasks-path> --behavior <id> [--json]

  <tasks-path>      Path to tasks.md containing behavior tasks
  --behavior <id>   Behavior ID to tick (e.g., A1, U5)
  --json            Output results in JSON format
  --help, -h        Show this help message
EOF
}

json_escape() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\r'/\\r}"
    s="${s//$'\t'/\\t}"
    printf '%s' "$s"
}

# Missing/invalid arguments: the message goes to stderr, JSON (when requested) to stdout.
fail_missing_argument() {
    if $JSON_MODE; then
        echo '{"error":"behavior ID required","status":"missing_argument"}'
    fi
    echo "ERROR: Missing required flag --behavior <id>" >&2
    echo "Usage: tick-behavior-task.sh <tasks-path> --behavior <id> [--json]" >&2
    exit 1
}

fail_not_found() {
    local message="$1"
    if $JSON_MODE; then
        echo "{\"status\":\"not_found\",\"behavior_id\":\"$(json_escape "$BEHAVIOR_ID")\",\"message\":\"$(json_escape "$message")\"}"
    fi
    echo "ERROR: $message" >&2
    exit 1
}

pos_count=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        --json) JSON_MODE=true; shift ;;
        --behavior)
            # `--behavior` with no value, or with the next flag as its value,
            # must fail loudly instead of reading an unbound $2 or swallowing a flag.
            if [[ -z "${2:-}" || "${2}" == -* ]]; then
                fail_missing_argument
            fi
            BEHAVIOR_ID="$2"
            shift 2
            ;;
        --help|-h) usage; exit 0 ;;
        -*) echo "ERROR: Unknown option '$1'" >&2; exit 1 ;;
        *)
            pos_count=$((pos_count + 1))
            if [[ $pos_count -gt 1 ]]; then
                echo "ERROR: Too many arguments (expected <tasks-path>)" >&2
                exit 1
            fi
            TASKS_ARG="$1"
            shift
            ;;
    esac
done

if [[ -z "$BEHAVIOR_ID" ]]; then
    fail_missing_argument
fi

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Unset positional argument falls back to the feature directory resolved from
# SPECIFY_FEATURE_DIRECTORY / .specify/feature.json.
if [[ -z "$TASKS_ARG" ]]; then
    if ! _paths_output=$(get_feature_paths); then
        echo "ERROR: Failed to resolve feature paths" >&2
        exit 1
    fi
    eval "$_paths_output"
    unset _paths_output
    TASKS_ARG="$FEATURE_DIR/tasks.md"
fi

if [[ ! -f "$TASKS_ARG" ]]; then
    if $JSON_MODE; then
        echo "{\"error\":\"tasks.md not found\",\"path\":\"$(json_escape "$TASKS_ARG")\",\"status\":\"missing\"}"
    fi
    echo "ERROR: tasks.md not found: $TASKS_ARG" >&2
    exit 1
fi

# Fixed-string matching: the behavior id is data, never a pattern.
MARKER="[behavior: $BEHAVIOR_ID]"

if ! grep -qF -- "$MARKER" "$TASKS_ARG"; then
    fail_not_found "Behavior '$BEHAVIOR_ID' not found in tasks.md"
fi

marker_lines="$(grep -nF -- "$MARKER" "$TASKS_ARG" | cut -d: -f1)"
line_count_markers=0
while IFS= read -r _marker_line; do
    [[ -n "$_marker_line" ]] || continue
    line_count_markers=$((line_count_markers + 1))
done <<< "$marker_lines"

line_number="$(printf '%s\n' "$marker_lines" | head -n 1)"
line_content="$(sed -n "${line_number}p" "$TASKS_ARG")"

if [[ "$line_count_markers" -gt 1 ]]; then
    joined_lines="$(printf '%s\n' "$marker_lines" | tr '\n' ',' | sed 's/,$//; s/,/, /g')"
    echo "WARNING: Multiple markers found for behavior $BEHAVIOR_ID (lines $joined_lines). Ticking first occurrence only." >&2
fi

if [[ "$line_content" == *"- [x]"* ]]; then
    if $JSON_MODE; then
        echo "{\"status\":\"already_done\",\"behavior_id\":\"$(json_escape "$BEHAVIOR_ID")\",\"message\":\"Task already ticked\"}"
    else
        echo "Behavior $BEHAVIOR_ID is already ticked"
    fi
    exit 0
fi

if [[ "$line_content" != *"- [ ]"* ]]; then
    fail_not_found "Behavior '$BEHAVIOR_ID' found at line $line_number but does not have a valid checkbox"
fi

# Rewrite the file line by line. The behavior id is only ever compared, never
# interpolated into a program or a regular expression: the python3 tier passes
# every value through argv, the bash tier only ever does string substitution.
TEMP_FILE="$(mktemp)"
trap 'rm -f "$TEMP_FILE"' EXIT

# Tier 1: python3. Values arrive via sys.argv, so a hostile behavior id (or a
# path containing quotes) can never be executed as code. Exit 3 = nothing ticked,
# which lets the shell tier take over.
tick_with_python() {
    python3 - "$TASKS_ARG" "$TEMP_FILE" "$line_number" <<'PY'
import sys

source_path, target_path, target_lineno = sys.argv[1], sys.argv[2], int(sys.argv[3])

changed = False
with open(source_path, "r", encoding="utf-8") as source:
    lines = source.readlines()

out = []
for index, line in enumerate(lines, start=1):
    if not changed and index == target_lineno and "- [ ]" in line:
        rewritten = line.replace("- [ ]", "- [x]", 1)
        if rewritten != line:
            line = rewritten
            changed = True
    out.append(line)

with open(target_path, "w", encoding="utf-8") as target:
    target.writelines(out)

sys.exit(0 if changed else 3)
PY
}

# Tier 2: pure bash, fixed-string substitution only.
tick_with_shell() {
    : > "$TEMP_FILE"
    local lineno=0
    local changed=false
    local line new_line
    while IFS= read -r line || [[ -n "$line" ]]; do
        lineno=$((lineno + 1))
        if [[ "$changed" == false && "$lineno" -eq "$line_number" ]]; then
            new_line="${line/- \[ \]/- [x]}"
            if [[ "$new_line" != "$line" ]]; then
                line="$new_line"
                changed=true
            fi
        fi
        printf '%s\n' "$line" >> "$TEMP_FILE"
    done < "$TASKS_ARG"
    [[ "$changed" == true ]]
}

ticked=false
if command -v python3 >/dev/null 2>&1 && tick_with_python; then
    ticked=true
elif tick_with_shell; then
    ticked=true
fi

if [[ "$ticked" != true ]]; then
    fail_not_found "Behavior '$BEHAVIOR_ID' found at line $line_number but no task was ticked"
fi

# Preserve the original permission bits across the atomic replace.
file_mode() {
    local mode=""
    if mode=$(stat -f '%Lp' "$1" 2>/dev/null) && [[ "$mode" =~ ^[0-7]{3,4}$ ]]; then
        printf '%s' "$mode"
    elif mode=$(stat -c '%a' "$1" 2>/dev/null) && [[ "$mode" =~ ^[0-7]{3,4}$ ]]; then
        printf '%s' "$mode"
    fi
}

original_mode="$(file_mode "$TASKS_ARG")"
if [[ -n "$original_mode" ]]; then
    chmod "$original_mode" "$TEMP_FILE"
fi
mv "$TEMP_FILE" "$TASKS_ARG"
trap - EXIT

# Verify the tick really landed.
verified_line="$(grep -nF -- "$MARKER" "$TASKS_ARG" | cut -d: -f1 | head -n 1)"
if [[ -z "$verified_line" || "$(sed -n "${verified_line}p" "$TASKS_ARG")" != *"- [x]"* ]]; then
    fail_not_found "Behavior '$BEHAVIOR_ID' could not be ticked in $TASKS_ARG"
fi

if $JSON_MODE; then
    if command -v jq >/dev/null 2>&1; then
        jq -cn \
            --arg status "success" \
            --arg id "$BEHAVIOR_ID" \
            '{status:$status,behavior_id:$id,message:"Task ticked"}'
    else
        echo "{\"status\":\"success\",\"behavior_id\":\"$(json_escape "$BEHAVIOR_ID")\",\"message\":\"Task ticked\"}"
    fi
else
    echo "Successfully ticked behavior: $BEHAVIOR_ID"
fi
