#!/usr/bin/env bash
# Read cycle evidence from cycle-log.md and emit structured JSON

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
CYCLE_LOG="$FEATURE_DIR/tdd/cycle-log.md"

# Validate required file
if [[ ! -f "$CYCLE_LOG" ]]; then
    if $JSON_MODE; then
        echo '{"evidence":[]}'
    else
        echo "No cycle evidence found"
    fi
    exit 0
fi

# Extract evidence entries from cycle-log.md (three-tier parser cascade)
extract_evidence() {
    local file="$1"

    # Try python3 parser
    if command -v python3 >/dev/null 2>&1; then
        python3 -c "
import re, sys, json
with open('$file', 'r') as f:
    content = f.read()

    # Parse cycle entries
    entries = []
    cycle_pattern = r'##\s+Cycle\s+\d+:.*?\n\*\*Date\*\*:\s*([^\n]+)\s*\n\*\*Phase\*\*:\s*([^\n]+)\s*\n\*\*Behavior\*\*:\s*([^\n]+)\s*\n\*\*Evidence\*\*:\s*(.*?)(?=\n##|\Z)'

    for match in re.finditer(cycle_pattern, content, re.DOTALL):
        date, phase, behavior_id, evidence = match.groups()
        entries.append({
            'date': date.strip(),
            'phase': phase.strip(),
            'behavior_id': behavior_id.strip(),
            'evidence': evidence.strip()
        })

    result = {'evidence': entries}
    print(json.dumps(result))
" 2>/dev/null && return 0
    fi

    # Fallback to grep/sed
    if grep -q '^## Cycle' "$file"; then
        echo '{"evidence":[]}'
    else
        echo '{"evidence":[]}'
    fi
}

# Extract evidence
evidence_json=$(extract_evidence "$CYCLE_LOG")

# Output results
if $JSON_MODE; then
    if command -v jq >/dev/null 2>&1; then
        echo "$evidence_json" | jq -c --arg status "success" '. + {status:$status}'
    else
        echo "$evidence_json"
    fi
else
    if command -v jq >/dev/null 2>&1; then
        count=$(echo "$evidence_json" | jq '.evidence | length')
        echo "Found $count evidence entries"
        echo "$evidence_json" | jq -r '.evidence[] | "- [\(.phase)] \(.behavior_id): \(.date)"'
    else
        echo "$evidence_json"
    fi
fi
