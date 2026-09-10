#!/usr/bin/env bash
# Read cycle evidence from cycle-log.md and emit structured JSON
#
# Contract: specs/1444-spec-kit-boundary-scripts/contracts/read-cycle-evidence.md
#   read-cycle-evidence.sh <cycle-log-path> [--json]

set -euo pipefail

JSON_MODE=false
CYCLE_LOG_ARG=""

usage() {
    cat <<'EOF'
Usage: read-cycle-evidence.sh <cycle-log-path> [--json]

  <cycle-log-path>  Path to cycle-log.md containing cycle evidence
  --json            Output results in JSON format
  --help, -h        Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --json) JSON_MODE=true; shift ;;
        --help|-h) usage; exit 0 ;;
        -*) echo "ERROR: Unknown option '$1'" >&2; exit 1 ;;
        *) CYCLE_LOG_ARG="$1"; shift ;;
    esac
done

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Resolve the cycle-log path. The documented positional argument wins; when it is
# omitted, fall back to the feature directory (SPECIFY_FEATURE_DIRECTORY or
# .specify/feature.json) resolved by common.sh.
if [[ -n "$CYCLE_LOG_ARG" ]]; then
    CYCLE_LOG="$CYCLE_LOG_ARG"
else
    if ! _paths_output=$(get_feature_paths); then
        echo "ERROR: Failed to resolve feature paths" >&2
        exit 1
    fi
    eval "$_paths_output"
    unset _paths_output
    CYCLE_LOG="$FEATURE_DIR/tdd/cycle-log.md"
fi

# Validate required file
if [[ ! -f "$CYCLE_LOG" ]]; then
    echo "ERROR: cycle-log.md not found: $CYCLE_LOG" >&2
    exit 1
fi

if [[ ! -r "$CYCLE_LOG" ]]; then
    echo "ERROR: Cannot read file: $CYCLE_LOG" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Tier 2 parser: python3
# ---------------------------------------------------------------------------
parse_with_python() {
    python3 - "$CYCLE_LOG" <<'PY'
import json
import re
import sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as handle:
    content = handle.read()

VALID_PHASES = ("RED", "GREEN", "REFACTOR")


def warn(lineno, reason):
    sys.stderr.write(
        "WARNING: Skipping malformed entry at line %d: %s\n" % (lineno, reason)
    )


def split_entries(text):
    """Split the log into (header, header_line, body_lines) chunks.

    A chunk starts at a ``##`` heading or after a ``---`` separator, and ends at
    the next ``---`` separator or ``##`` heading. One entry's body therefore can
    never swallow the following entry.
    """
    entries = []
    current = None
    for lineno, line in enumerate(text.splitlines(), start=1):
        if re.match(r"^---[ \t]*$", line):
            if current is not None:
                entries.append(current)
                current = None
            continue
        if line.startswith("##"):
            if current is not None:
                entries.append(current)
            current = {"header": line, "line": lineno, "body": []}
            continue
        if current is not None:
            current["body"].append(line)
    if current is not None:
        entries.append(current)
    return entries


def parse_header(header):
    """Return (timestamp, phase, behavior_id) or a (kind, reason) marker.

    ``kind`` is ``None`` when the heading is not an evidence entry at all.
    """
    rest = header.lstrip("#").strip()
    match = re.match(
        r"^(\d{4}-\d{2}-\d{2})[ T](\d{2}:\d{2}(?::\d{2})?)(.*)$", rest
    )
    if not match:
        return ("not_entry", None)
    date_part, time_part, tail = match.groups()
    tail = tail.strip()
    if not tail.startswith("-"):
        return ("missing_phase", None)
    tail = tail[1:].strip()
    if not tail:
        return ("missing_phase", None)

    if " - " in tail:
        phase, behavior = tail.split(" - ", 1)
        behavior = behavior.split(" ")[0]
    else:
        phase, behavior = tail, ""

    phase = phase.strip()
    behavior = behavior.strip()

    if phase not in VALID_PHASES:
        if not behavior:
            return ("missing_phase", None)
        return ("invalid_phase", phase)
    if not behavior:
        return ("missing_behavior", None)

    timestamp = "%sT%s" % (date_part, time_part)
    if timestamp.count(":") == 1:
        timestamp += ":00"
    return ("ok", (timestamp, phase, behavior))


def extract_body(body_lines, prefix):
    """Return the text for the first ``<prefix>:`` line plus the lines after it."""
    start = None
    for index, line in enumerate(body_lines):
        if line.startswith(prefix + ":"):
            start = index
            break
    if start is None:
        return ""
    text = body_lines[start][len(prefix) + 1:] + "\n" + "\n".join(body_lines[start + 1:])
    return text.strip()


records = []
for entry in split_entries(content):
    kind, payload = parse_header(entry["header"])
    if kind == "not_entry":
        continue
    if kind != "ok":
        reason = {
            "missing_phase": "missing phase",
            "missing_behavior": "missing behavior ID",
            "invalid_phase": "invalid phase '%s'" % payload,
        }[kind]
        warn(entry["line"], reason)
        continue
    timestamp, phase, behavior_id = payload
    records.append({
        "phase": phase,
        "behavior_id": behavior_id,
        "timestamp": timestamp,
        "evidence_text": extract_body(entry["body"], "Evidence"),
    })

print(json.dumps({"evidence": records}, ensure_ascii=False))
PY
}

# ---------------------------------------------------------------------------
# Tier 3 parser: pure shell fallback (no python3 required)
# ---------------------------------------------------------------------------
_JSON_PARTS=()
_TEXT_PARTS=()
_OUTPUT_MODE="json"

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

is_valid_phase() {
    case "$1" in
        RED|GREEN|REFACTOR) return 0 ;;
        *) return 1 ;;
    esac
}

warn_malformed() {
    echo "WARNING: Skipping malformed entry at line $1: $2" >&2
}

# Parse an entry header and, when valid, append the rendered entry.
#   $1 header line, $2 header line number, $3 body
render_entry() {
    local header="$1" hline="$2" body="$3"

    local rest="${header#\#\#}"
    rest="$(trim "$rest")"

    if [[ ! "$rest" =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2})[[:space:]T]([0-9]{2}:[0-9]{2}(:[0-9]{2})?)(.*)$ ]]; then
        return 0
    fi
    local date_part="${BASH_REMATCH[1]}"
    local time_part="${BASH_REMATCH[2]}"
    local tail
    tail="$(trim "${BASH_REMATCH[4]}")"

    if [[ "$tail" != -* ]]; then
        warn_malformed "$hline" "missing phase"
        return 0
    fi
    tail="$(trim "${tail#-}")"
    if [[ -z "$tail" ]]; then
        warn_malformed "$hline" "missing phase"
        return 0
    fi

    local phase="" behavior=""
    if [[ "$tail" == *" - "* ]]; then
        phase="$(trim "${tail%% - *}")"
        behavior="$(trim "${tail#* - }")"
        behavior="${behavior%% *}"
    else
        phase="$tail"
    fi

    if ! is_valid_phase "$phase"; then
        if [[ -z "$behavior" ]]; then
            warn_malformed "$hline" "missing phase"
        else
            warn_malformed "$hline" "invalid phase '$phase'"
        fi
        return 0
    fi
    if [[ -z "$behavior" ]]; then
        warn_malformed "$hline" "missing behavior ID"
        return 0
    fi

    local timestamp="${date_part}T${time_part}"
    if [[ "${timestamp//[^:]/}" == ":" ]]; then
        timestamp="${timestamp}:00"
    fi

    # Evidence body: everything from the first "Evidence:" line to the end of the
    # entry (multiline evidence is preserved verbatim).
    local evidence=""
    if printf '%s\n' "$body" | grep -q '^Evidence:'; then
        evidence="$(printf '%s\n' "$body" | sed -n '/^Evidence:/,$ p')"
        evidence="${evidence#Evidence:}"
    fi
    evidence="$(trim "$evidence")"

    if [[ "$_OUTPUT_MODE" == "json" ]]; then
        if command -v jq >/dev/null 2>&1; then
            _JSON_PARTS+=("$(jq -cn \
                --arg phase "$phase" \
                --arg behavior_id "$behavior" \
                --arg timestamp "$timestamp" \
                --arg evidence_text "$evidence" \
                '{phase:$phase,behavior_id:$behavior_id,timestamp:$timestamp,evidence_text:$evidence_text}')")
        else
            _JSON_PARTS+=("{\"phase\":\"$(json_escape "$phase")\",\"behavior_id\":\"$(json_escape "$behavior")\",\"timestamp\":\"$(json_escape "$timestamp")\",\"evidence_text\":\"$(json_escape "$evidence")\"}")
        fi
    else
        local behavior_text=""
        behavior_text="$(printf '%s\n' "$body" | grep -m1 '^Behavior:' || true)"
        behavior_text="$(trim "${behavior_text#Behavior:}")"

        local index=$(( ${#_TEXT_PARTS[@]} + 1 ))
        _TEXT_PARTS+=("[$index] $date_part $time_part - $phase - $behavior"$'\n'"    Behavior: $behavior_text"$'\n'"    Evidence: $evidence")
    fi
}

parse_with_shell() {
    local lineno=0 cur_header="" cur_line=0 cur_body="" started=false line
    while IFS= read -r line || [[ -n "$line" ]]; do
        lineno=$((lineno + 1))
        if [[ "$line" =~ ^---[[:space:]]*$ ]]; then
            if [[ "$started" == true ]]; then
                render_entry "$cur_header" "$cur_line" "$cur_body"
            fi
            cur_header=""; cur_body=""; started=false
            continue
        fi
        if [[ "$line" == "##"* ]]; then
            if [[ "$started" == true ]]; then
                render_entry "$cur_header" "$cur_line" "$cur_body"
            fi
            cur_header="$line"; cur_line="$lineno"; cur_body=""; started=true
            continue
        fi
        if [[ "$started" == true ]]; then
            cur_body="${cur_body}${line}"$'\n'
        fi
    done < "$CYCLE_LOG"

    if [[ "$started" == true ]]; then
        render_entry "$cur_header" "$cur_line" "$cur_body"
    fi
}

# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------
if $JSON_MODE; then
    if command -v python3 >/dev/null 2>&1; then
        parse_with_python
    else
        _OUTPUT_MODE="json"
        parse_with_shell
        joined=""
        for part in ${_JSON_PARTS[@]+"${_JSON_PARTS[@]}"}; do
            [[ -n "$joined" ]] && joined="${joined},"
            joined="${joined}${part}"
        done
        printf '{"evidence":[%s]}\n' "$joined"
    fi
else
    _OUTPUT_MODE="text"
    parse_with_shell
    printf 'Cycle Evidence: %s\n\n' "$CYCLE_LOG"
    count=${#_TEXT_PARTS[@]}
    if [[ "$count" -eq 0 ]]; then
        echo "Found 0 evidence entries:"
    elif [[ "$count" -eq 1 ]]; then
        echo "Found 1 evidence entry:"
    else
        echo "Found $count evidence entries:"
    fi
    if [[ "$count" -gt 0 ]]; then
        printf '\n'
        printf '%s\n\n' "${_TEXT_PARTS[@]}"
    fi
fi
