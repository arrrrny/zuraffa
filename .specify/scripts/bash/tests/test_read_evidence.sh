#!/usr/bin/env bash
# test_read_evidence.sh — read-cycle-evidence.sh suite (E1–E5).
#
# Covers: RED/GREEN/REFACTOR parsing to JSON (E1), malformed-entry skip with
# warning (E2), zero-entry logs (E3), missing file (E4), text mode + JSON
# parseability (E5).

set -u

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=harness.sh
source "$TESTS_DIR/harness.sh"

READ_EVIDENCE="$SCRIPTS_DIR/read-cycle-evidence.sh"
ROOT="$(t_fixture_dir)"
trap 'rm -rf "$ROOT"' EXIT

# ---------------------------------------------------------------------------
t_case "E1: parses RED/GREEN/REFACTOR entries into JSON with fields"

LOG="$ROOT/e1-cycle-log.md"
cat > "$LOG" <<'EOF'
# TDD Cycle Log

## Baseline

Narrative heading without a timestamp — never an evidence entry.

---

## 2026-09-15 10:00:00 - RED - U9

Behavior: first behavior
Evidence: failing test output

---

## 2026-09-15 10:05:00 - GREEN - U9

Behavior: first behavior
Evidence: passing test output

---

## 2026-09-15 10:10:00 - REFACTOR - U9

Behavior: first behavior
Evidence: cleanup while green

---

## 2026-09-15 11:00 - RED - U10

Behavior: second behavior
Evidence: another red

---
EOF

out="$(bash "$READ_EVIDENCE" "$LOG" --json)"
rc=$?
t_assert_exit "E1 succeeds" 0 "$rc"
if t_have_jq; then
    t_assert_eq "E1 four entries" "4" "$(t_json_get "$out" '.evidence | length')"
    t_assert_eq "E1 first phase RED" "RED" "$(t_json_get "$out" '.evidence[0].phase')"
    t_assert_eq "E1 first behavior U9" "U9" "$(t_json_get "$out" '.evidence[0].behavior_id')"
    t_assert_eq "E1 third phase REFACTOR" "REFACTOR" "$(t_json_get "$out" '.evidence[2].phase')"
    t_assert_eq "E1 HH:MM timestamp normalized" "2026-09-15T11:00:00" "$(t_json_get "$out" '.evidence[3].timestamp')"
    t_assert_contains "E1 evidence text extracted" "$(t_json_get "$out" '.evidence[0].evidence_text')" "failing test output"
else
    t_assert_contains "E1 entries present (grep fallback)" "$out" '"phase":"RED"'
    t_assert_contains "E1 behavior present (grep fallback)" "$out" '"behavior_id":"U9"'
fi

# ---------------------------------------------------------------------------
t_case "E2: malformed entries skipped with a warning, valid entries kept"

LOG="$ROOT/e2-cycle-log.md"
cat > "$LOG" <<'EOF'
# TDD Cycle Log

## 2026-09-15 09:00:00 - GREEN - U1

Behavior: good entry
Evidence: kept

---

## 2026-09-15 09:30:00 - BROKEN - X1

Behavior: invalid phase
Evidence: skipped

---

## 2026-09-15 10:00:00 - GREEN - U2

Behavior: another good entry
Evidence: also kept

---
EOF

out="$(bash "$READ_EVIDENCE" "$LOG" --json 2>"$ROOT/e2-stderr.txt")"
rc=$?
err="$(cat "$ROOT/e2-stderr.txt")"
t_assert_exit "E2 succeeds despite malformed entry" 0 "$rc"
t_assert_contains "E2 warning on stderr" "$err" "WARNING: Skipping malformed entry"
t_assert_contains "E2 warning names the invalid phase" "$err" "invalid phase 'BROKEN'"
if t_have_jq; then
    t_assert_eq "E2 only valid entries returned" "2" "$(t_json_get "$out" '.evidence | length')"
    t_assert_eq "E2 valid entries intact" "U1 U2" "$(t_json_get "$out" '.evidence[].behavior_id' | tr '\n' ' ' | sed 's/ $//')"
else
    t_assert_not_contains "E2 malformed entry excluded (grep fallback)" "$out" '"behavior_id":"X1"'
fi

# ---------------------------------------------------------------------------
t_case "E3: log without evidence entries yields zero entries and exit 0"

LOG="$ROOT/e3-cycle-log.md"
cat > "$LOG" <<'EOF'
# TDD Cycle Log

## Baseline

Nothing driven yet.

---
EOF

out="$(bash "$READ_EVIDENCE" "$LOG" --json)"
rc=$?
t_assert_exit "E3 succeeds" 0 "$rc"
if t_have_jq; then
    t_assert_eq "E3 zero entries" "0" "$(t_json_get "$out" '.evidence | length')"
else
    t_assert_eq "E3 empty evidence array (grep fallback)" '{"evidence":[]}' "$(printf '%s' "$out" | tr -d '[:space:]')"
fi

# ---------------------------------------------------------------------------
t_case "E4: missing cycle-log fails loudly"

err="$(bash "$READ_EVIDENCE" "$ROOT/no-such-log.md" 2>&1 >/dev/null)"
rc=$?
t_assert_exit "E4 exits 1" 1 "$rc"
t_assert_contains "E4 error names the path" "$err" "cycle-log.md not found"

# ---------------------------------------------------------------------------
t_case "E5: text mode summarizes entries; JSON output is jq-parseable"

LOG="$ROOT/e5-cycle-log.md"
cat > "$LOG" <<'EOF'
## 2026-09-15 10:00:00 - RED - U9

Behavior: first behavior
Evidence: failing output

---

## 2026-09-15 10:05:00 - GREEN - U9

Behavior: first behavior
Evidence: passing output

---

## 2026-09-15 10:10:00 - REFACTOR - U9

Behavior: first behavior
Evidence: cleanup

---
EOF

out="$(bash "$READ_EVIDENCE" "$LOG")"
rc=$?
t_assert_exit "E5 text mode succeeds" 0 "$rc"
t_assert_contains "E5 header line" "$out" "Cycle Evidence:"
t_assert_contains "E5 count line" "$out" "Found 3 evidence entries:"
t_assert_contains "E5 entry rendered" "$out" "[1] 2026-09-15 10:00:00 - RED - U9"
t_assert_contains "E5 behavior line rendered" "$out" "Behavior: first behavior"

out="$(bash "$READ_EVIDENCE" "$LOG" --json)"
if t_have_jq; then
    if printf '%s' "$out" | jq -e . >/dev/null 2>&1; then
        t_pass "E5 JSON parses via jq -e"
    else
        t_fail "E5 JSON parses via jq -e"
    fi
else
    t_pass "E5 JSON parseability (jq absent — skipped)"
fi

# ---------------------------------------------------------------------------
t_report
