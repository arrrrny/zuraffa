#!/usr/bin/env bash
# Sync behaviors from test-list.md to tasks.md
#
# Contract: specs/1444-spec-kit-boundary-scripts/contracts/sync-behaviors-to-tasks.md
#   sync-behaviors-to-tasks.sh <test-list-path> <tasks-path> [--json]

set -euo pipefail

JSON_MODE=false
TEST_LIST_ARG=""
TASKS_ARG=""

usage() {
    cat <<'EOF'
Usage: sync-behaviors-to-tasks.sh <test-list-path> <tasks-path> [--json]

  <test-list-path>  Path to test-list.md containing behavior definitions
  <tasks-path>      Path to tasks.md to update with behavior markers
  --json            Output results in JSON format
  --help, -h        Show this help message
EOF
}

pos_count=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        --json) JSON_MODE=true; shift ;;
        --help|-h) usage; exit 0 ;;
        -*) echo "ERROR: Unknown option '$1'" >&2; exit 1 ;;
        *)
            pos_count=$((pos_count + 1))
            case "$pos_count" in
                1) TEST_LIST_ARG="$1" ;;
                2) TASKS_ARG="$1" ;;
                *) echo "ERROR: Too many arguments (expected <test-list-path> <tasks-path>)" >&2; exit 1 ;;
            esac
            shift
            ;;
    esac
done

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Unset positional arguments fall back to the feature directory resolved from
# SPECIFY_FEATURE_DIRECTORY / .specify/feature.json.
if [[ -z "$TEST_LIST_ARG" || -z "$TASKS_ARG" ]]; then
    if ! _paths_output=$(get_feature_paths); then
        echo "ERROR: Failed to resolve feature paths" >&2
        exit 1
    fi
    eval "$_paths_output"
    unset _paths_output
    if [[ -z "$TEST_LIST_ARG" ]]; then
        TEST_LIST_ARG="$FEATURE_DIR/tdd/test-list.md"
    fi
    if [[ -z "$TASKS_ARG" ]]; then
        TASKS_ARG="$FEATURE_DIR/tasks.md"
    fi
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

trim() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

# Report a fatal error in the requested format and exit non-zero.
fail() {
    local message="$1"
    if $JSON_MODE; then
        echo "{\"status\":\"error\",\"error\":\"$(json_escape "$message")\",\"behaviors_added\":0}"
    fi
    echo "ERROR: $message" >&2
    exit "${2:-1}"
}

[[ -f "$TEST_LIST_ARG" ]] || fail "test-list.md not found: $TEST_LIST_ARG"
[[ -f "$TASKS_ARG" ]] || fail "tasks.md not found: $TASKS_ARG"

# ---------------------------------------------------------------------------
# Parse behavior definitions from test-list.md
# ---------------------------------------------------------------------------
parse_behaviors() {
    local file="$1"
    if command -v python3 >/dev/null 2>&1; then
        python3 - "$file" <<'PY'
import re
import sys

path = sys.argv[1]
candidate = re.compile(r"^\s*[-*]?\s*\*\*([A-Za-z][A-Za-z0-9]*[0-9]+)\*\*\s*:\s*(.*)$")
with open(path, "r", encoding="utf-8") as handle:
    for lineno, raw in enumerate(handle, start=1):
        match = candidate.match(raw.rstrip("\n"))
        if not match:
            continue
        behavior_id, description = match.group(1), match.group(2).strip()
        print("%s\t%d\t%s" % (behavior_id, lineno, description))
PY
        return 0
    fi

    # Fallback: grep/sed (line numbers preserved so duplicates report real lines).
    grep -nE '^[[:space:]]*[-*]?[[:space:]]*\*\*[A-Za-z][A-Za-z0-9]*[0-9]+\*\*[[:space:]]*:' "$file" \
        | sed -E 's/^([0-9]+):[[:space:]]*[-*]?[[:space:]]*\*\*([A-Za-z][A-Za-z0-9]*[0-9]+)\*\*[[:space:]]*:[[:space:]]*/\2\t\1\t/' \
        || true
    return 0
}

BEHAVIOR_IDS=()
BEHAVIOR_DESCS=()
BEHAVIOR_LINES=()

while IFS=$'\t' read -r raw_id raw_line raw_desc; do
    [[ -n "${raw_id:-}" ]] || continue
    behavior_id="$(trim "$raw_id")"
    description="$(trim "${raw_desc:-}")"

    if [[ ! "$behavior_id" =~ ^[A-Z]+[0-9]+$ ]]; then
        echo "WARNING: Skipping invalid behavior ID '$behavior_id' at line $raw_line" >&2
        continue
    fi
    if [[ -z "$description" ]]; then
        echo "WARNING: Skipping behavior '$behavior_id' at line $raw_line: missing description" >&2
        continue
    fi

    # Duplicate IDs are ambiguous — which definition is canonical?
    dup_line=""
    index=0
    for known in ${BEHAVIOR_IDS[@]+"${BEHAVIOR_IDS[@]}"}; do
        if [[ "$known" == "$behavior_id" ]]; then
            dup_line="${BEHAVIOR_LINES[$index]}"
            break
        fi
        index=$((index + 1))
    done
    if [[ -n "$dup_line" ]]; then
        fail "Duplicate behavior ID '$behavior_id' found in test-list.md at lines $dup_line and $raw_line" 2
    fi

    BEHAVIOR_IDS+=("$behavior_id")
    BEHAVIOR_DESCS+=("$description")
    BEHAVIOR_LINES+=("$raw_line")
done < <(parse_behaviors "$TEST_LIST_ARG")

behavior_count=${#BEHAVIOR_IDS[@]}

if [[ $behavior_count -eq 0 ]]; then
    if $JSON_MODE; then
        echo '{"status":"success","message":"No behaviors found in test-list.md","behaviors_added":0}'
    else
        echo "No behaviors found in test-list.md. Nothing to sync."
    fi
    exit 0
fi

# ---------------------------------------------------------------------------
# Existing markers in tasks.md
# ---------------------------------------------------------------------------
marker_exists() {
    grep -qF "[behavior: $1]" "$TASKS_ARG"
}

MISSING_IDS=()
MISSING_DESCS=()
for ((i = 0; i < behavior_count; i++)); do
    if marker_exists "${BEHAVIOR_IDS[$i]}"; then
        continue
    fi
    MISSING_IDS+=("${BEHAVIOR_IDS[$i]}")
    MISSING_DESCS+=("${BEHAVIOR_DESCS[$i]}")
done

missing_count=${#MISSING_IDS[@]}
if [[ $missing_count -eq 0 ]]; then
    if $JSON_MODE; then
        echo '{"status":"success","message":"All behaviors already present","behaviors_added":0}'
    else
        echo "All behaviors already present in tasks.md"
    fi
    exit 0
fi

# ---------------------------------------------------------------------------
# Insertion strategy: one section per behavior category
# ---------------------------------------------------------------------------
section_key_for_id() {
    case "$1" in
        A*) printf 'A' ;;
        U*) printf 'U' ;;
        C*) printf 'C' ;;
        *) printf 'OTHER' ;;
    esac
}

section_title_for_key() {
    case "$1" in
        A) printf 'Acceptance Behaviors' ;;
        U) printf 'Unit Behaviors' ;;
        C) printf 'Characterization Behaviors' ;;
        *) printf 'Behavior Markers' ;;
    esac
}

PENDING_A=""
PENDING_U=""
PENDING_C=""
PENDING_OTHER=""
pending_for_key() {
    case "$1" in
        A) printf '%s' "$PENDING_A" ;;
        U) printf '%s' "$PENDING_U" ;;
        C) printf '%s' "$PENDING_C" ;;
        *) printf '%s' "$PENDING_OTHER" ;;
    esac
}

added_ids=()
for ((i = 0; i < missing_count; i++)); do
    behavior_id="${MISSING_IDS[$i]}"
    description="${MISSING_DESCS[$i]}"
    key="$(section_key_for_id "$behavior_id")"
    task_line="- [ ] $description [behavior: $behavior_id]"
    case "$key" in
        A) PENDING_A="${PENDING_A}${task_line}"$'\n' ;;
        U) PENDING_U="${PENDING_U}${task_line}"$'\n' ;;
        C) PENDING_C="${PENDING_C}${task_line}"$'\n' ;;
        *) PENDING_OTHER="${PENDING_OTHER}${task_line}"$'\n' ;;
    esac
    added_ids+=("$behavior_id")
done

lines=()
while IFS= read -r line || [[ -n "$line" ]]; do
    lines+=("$line")
done < "$TASKS_ARG"
line_count=${#lines[@]}

TEMP_FILE="$(mktemp)"
trap 'rm -f "$TEMP_FILE"' EXIT

insert_after_A=-1
insert_after_U=-1
insert_after_C=-1
insert_after_OTHER=-1

# Find, per existing section, the index of its last content line.
i=0
while [[ $i -lt $line_count ]]; do
    line="${lines[$i]}"
    if [[ "$line" == "## "* ]]; then
        title="$(trim "${line#\#\#}")"
        key=""
        case "$title" in
            "Acceptance Behaviors") key="A" ;;
            "Unit Behaviors") key="U" ;;
            "Characterization Behaviors") key="C" ;;
            "Behavior Markers") key="OTHER" ;;
        esac
        if [[ -n "$key" ]]; then
            end=$((i + 1))
            while [[ $end -lt $line_count && "${lines[$end]}" != "## "* ]]; do
                end=$((end + 1))
            done
            last=$i
            j=$((i + 1))
            while [[ $j -lt $end ]]; do
                if [[ -n "$(trim "${lines[$j]}")" ]]; then
                    last=$j
                fi
                j=$((j + 1))
            done
            case "$key" in
                A) insert_after_A=$last ;;
                U) insert_after_U=$last ;;
                C) insert_after_C=$last ;;
                *) insert_after_OTHER=$last ;;
            esac
            i=$end
            continue
        fi
    fi
    i=$((i + 1))
done

spliced_A=false
spliced_U=false
spliced_C=false
spliced_OTHER=false

emit_pending() {
    local key="$1"
    local pending
    pending="$(pending_for_key "$key")"
    [[ -n "$pending" ]] || return 0
    while IFS= read -r pending_line; do
        printf '%s\n' "$pending_line" >> "$TEMP_FILE"
    done <<< "$(printf '%s' "$pending")"
}

i=0
while [[ $i -lt $line_count ]]; do
    printf '%s\n' "${lines[$i]}" >> "$TEMP_FILE"

    if [[ $insert_after_A -eq $i ]]; then emit_pending A; spliced_A=true; fi
    if [[ $insert_after_U -eq $i ]]; then emit_pending U; spliced_U=true; fi
    if [[ $insert_after_C -eq $i ]]; then emit_pending C; spliced_C=true; fi
    if [[ $insert_after_OTHER -eq $i ]]; then emit_pending OTHER; spliced_OTHER=true; fi

    i=$((i + 1))
done

# Sections that did not exist yet are created at the end of the file.
for key in A U C OTHER; do
    spliced=false
    case "$key" in
        A) spliced=$spliced_A ;;
        U) spliced=$spliced_U ;;
        C) spliced=$spliced_C ;;
        *) spliced=$spliced_OTHER ;;
    esac
    [[ "$spliced" == false ]] || continue

    pending="$(pending_for_key "$key")"
    [[ -n "$pending" ]] || continue

    if [[ -s "$TEMP_FILE" ]]; then
        printf '\n' >> "$TEMP_FILE"
    fi
    printf '## %s\n\n' "$(section_title_for_key "$key")" >> "$TEMP_FILE"
    emit_pending "$key"
done

# Atomically replace tasks.md while preserving its permission bits (`mktemp`
# creates 0600, and `mv` would otherwise make tasks.md owner-only).
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

# Verify the markers really landed — never report success for a no-op write.
written=0
for id in ${added_ids[@]+"${added_ids[@]}"}; do
    if marker_exists "$id"; then
        written=$((written + 1))
    fi
done

if [[ $written -ne $missing_count ]]; then
    fail "Wrote $written of $missing_count behavior markers to $TASKS_ARG"
fi

# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------
if $JSON_MODE; then
    if command -v jq >/dev/null 2>&1; then
        behaviors_json="$(printf '%s\n' ${added_ids[@]+"${added_ids[@]}"} | jq -R . | jq -s .)"
        jq -cn \
            --arg status "success" \
            --argjson count "$missing_count" \
            --argjson behaviors "$behaviors_json" \
            '{status:$status,behaviors_added:$count,behaviors:$behaviors}'
    else
        behaviors_json=""
        for id in ${added_ids[@]+"${added_ids[@]}"}; do
            [[ -n "$behaviors_json" ]] && behaviors_json="${behaviors_json},"
            behaviors_json="${behaviors_json}\"$(json_escape "$id")\""
        done
        printf '{"status":"success","behaviors_added":%d,"behaviors":[%s]}\n' \
            "$missing_count" "$behaviors_json"
    fi
else
    echo "Successfully added $missing_count behavior marker(s) to tasks.md:"
    for id in ${added_ids[@]+"${added_ids[@]}"}; do
        echo "  - $id"
    done
fi
