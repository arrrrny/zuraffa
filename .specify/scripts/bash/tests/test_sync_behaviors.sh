#!/usr/bin/env bash
# test_sync_behaviors.sh — sync-behaviors-to-tasks.sh suite (S1–S6).
#
# Covers: normal insert + section grouping (S1), idempotency + byte-stable
# preservation (S2), duplicate-ID rejection (S3), malformed-ID skip (S4),
# missing-input errors (S5), JSON success shape (S6).
#
# Every case builds its fixtures under a temp root; repo files are untouched.

set -u

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=harness.sh
source "$TESTS_DIR/harness.sh"

SYNC="$SCRIPTS_DIR/sync-behaviors-to-tasks.sh"
ROOT="$(t_fixture_dir)"
trap 'rm -rf "$ROOT"' EXIT

make_test_list() { # <path> then ID:desc lines
    local path="$1" id desc
    : > "$path"
    shift
    while [[ $# -ge 2 ]]; do
        id="$1"; desc="$2"; shift 2
        printf -- '- **%s**: %s\n' "$id" "$desc" >> "$path"
    done
}

# ---------------------------------------------------------------------------
t_case "S1: inserts markers grouped into Acceptance/Unit/Characterization sections"

LIST="$ROOT/s1-test-list.md"
TASKS="$ROOT/s1-tasks.md"
make_test_list "$LIST" A1 "First acceptance" U1 "First unit" C1 "First characterization"
cat > "$TASKS" <<'EOF'
# Tasks: Demo

## Setup

- [x] setup done

## Implementation
EOF

out="$(bash "$SYNC" "$LIST" "$TASKS")"
rc=$?
t_assert_exit "S1 sync succeeds" 0 "$rc"
t_assert_eq "S1 one A1 marker" 1 "$(grep -cF '[behavior: A1]' "$TASKS")"
t_assert_eq "S1 one U1 marker" 1 "$(grep -cF '[behavior: U1]' "$TASKS")"
t_assert_eq "S1 one C1 marker" 1 "$(grep -cF '[behavior: C1]' "$TASKS")"
t_assert_contains "S1 Acceptance section created" "$(cat "$TASKS")" "## Acceptance Behaviors"
t_assert_contains "S1 Unit section created" "$(cat "$TASKS")" "## Unit Behaviors"
t_assert_contains "S1 Characterization section created" "$(cat "$TASKS")" "## Characterization Behaviors"
a1_line="$(grep -F '[behavior: A1]' "$TASKS")"
t_assert_contains "S1 marker line is an unticked task with description" "$a1_line" "- [ ] First acceptance [behavior: A1]"
t_assert_contains "S1 text output reports count" "$out" "Successfully added 3 behavior marker(s)"

# ---------------------------------------------------------------------------
t_case "S2: idempotent; existing marker lines stay byte-identical"

LIST="$ROOT/s2-test-list.md"
TASKS="$ROOT/s2-tasks.md"
make_test_list "$LIST" A1 "Sync it" A2 "Second acceptance" U1 "Unit thing" U2 "Second unit"
cat > "$TASKS" <<'EOF'
# Tasks

- [ ] existing work [behavior: A1]
- [ ] more work [behavior: U1]
EOF
a1_before="$(grep -F '[behavior: A1]' "$TASKS")"
u1_before="$(grep -F '[behavior: U1]' "$TASKS")"

out="$(bash "$SYNC" "$LIST" "$TASKS" --json)"
rc=$?
t_assert_exit "S2 first run succeeds" 0 "$rc"
if t_have_jq; then
    t_assert_eq "S2 first run added 2" "2" "$(t_json_get "$out" '.behaviors_added')"
    t_assert_eq "S2 behaviors array holds A2,U2" "A2 U2" "$(t_json_get "$out" '.behaviors | join(" ")')"
else
    t_assert_contains "S2 first run added 2 (grep fallback)" "$out" '"behaviors_added":2'
fi
t_assert_eq "S2 A1 line unchanged" "$a1_before" "$(grep -F '[behavior: A1]' "$TASKS")"
t_assert_eq "S2 U1 line unchanged" "$u1_before" "$(grep -F '[behavior: U1]' "$TASKS")"

out="$(bash "$SYNC" "$LIST" "$TASKS" --json)"
rc=$?
t_assert_exit "S2 second run succeeds" 0 "$rc"
if t_have_jq; then
    t_assert_eq "S2 second run is a no-op" "0" "$(t_json_get "$out" '.behaviors_added')"
else
    t_assert_contains "S2 second run is a no-op (grep fallback)" "$out" '"behaviors_added":0'
fi

# ---------------------------------------------------------------------------
t_case "S3: duplicate behavior ID rejected, tasks.md untouched"

LIST="$ROOT/s3-test-list.md"
TASKS="$ROOT/s3-tasks.md"
make_test_list "$LIST" A1 "first" U1 "middle" A1 "second"
cp /dev/null "$TASKS"
printf '# Tasks\n\n- [ ] untouched\n' > "$TASKS"
before="$(t_file_hash "$TASKS")"

err="$(bash "$SYNC" "$LIST" "$TASKS" 2>&1 >/dev/null)"
rc=$?
t_assert_exit "S3 duplicate exits non-zero" 2 "$rc"
t_assert_contains "S3 error names the duplicate" "$err" "Duplicate behavior ID 'A1'"
t_assert_eq "S3 tasks.md unchanged" "$before" "$(t_file_hash "$TASKS")"

# The README documents the --json error contract for this exact path.
out="$(bash "$SYNC" "$LIST" "$TASKS" --json 2>/dev/null)"
rc=$?
t_assert_exit "S3 JSON mode also exits 2" 2 "$rc"
if t_have_jq; then
    t_assert_eq "S3 JSON status=error" "error" "$(t_json_get "$out" '.status')"
    t_assert_contains "S3 JSON error names the duplicate" "$(t_json_get "$out" '.error')" "Duplicate behavior ID 'A1'"
else
    t_assert_contains "S3 JSON error shape (grep fallback)" "$out" '"status":"error"'
fi
t_assert_eq "S3 tasks.md unchanged after JSON error" "$before" "$(t_file_hash "$TASKS")"

# ---------------------------------------------------------------------------
t_case "S4: malformed behavior ID skipped with warning; valid ones still sync"

LIST="$ROOT/s4-test-list.md"
TASKS="$ROOT/s4-tasks.md"
make_test_list "$LIST" A1 "good one" U1 "also good"
printf -- '- **ab1**: bad lowercase id\n' >> "$LIST"
cat > "$TASKS" <<'EOF'
# Tasks
EOF

err="$(bash "$SYNC" "$LIST" "$TASKS" 2>&1 >/dev/null)"
rc=$?
t_assert_exit "S4 valid behaviors still sync" 0 "$rc"
t_assert_contains "S4 warning on stderr" "$err" "WARNING: Skipping invalid behavior ID 'ab1'"
t_assert_eq "S4 A1 marker present" 1 "$(grep -cF '[behavior: A1]' "$TASKS")"
t_assert_not_contains "S4 no marker for malformed id" "$(cat "$TASKS")" "[behavior: ab1]"

# ---------------------------------------------------------------------------
t_case "S5: missing test-list.md or tasks.md fails loudly"

TASKS="$ROOT/s5-tasks.md"
printf '# Tasks\n' > "$TASKS"

err="$(bash "$SYNC" "$ROOT/does-not-exist.md" "$TASKS" 2>&1 >/dev/null)"
rc=$?
t_assert_exit "S5 missing test-list exits 1" 1 "$rc"
t_assert_contains "S5 error names missing test-list" "$err" "test-list.md not found"

LIST="$ROOT/s5-list.md"
make_test_list "$LIST" A1 "desc"
err="$(bash "$SYNC" "$LIST" "$ROOT/missing-tasks.md" 2>&1 >/dev/null)"
rc=$?
t_assert_exit "S5 missing tasks exits 1" 1 "$rc"
t_assert_contains "S5 error names missing tasks" "$err" "tasks.md not found"

# ---------------------------------------------------------------------------
t_case "S6: --json emits status/behaviors_added/behaviors"

LIST="$ROOT/s6-test-list.md"
TASKS="$ROOT/s6-tasks.md"
make_test_list "$LIST" A1 "alpha" U1 "beta"
printf '# Tasks\n' > "$TASKS"

out="$(bash "$SYNC" "$LIST" "$TASKS" --json)"
rc=$?
t_assert_exit "S6 succeeds" 0 "$rc"
if t_have_jq; then
    t_assert_eq "S6 status=success" "success" "$(t_json_get "$out" '.status')"
    t_assert_eq "S6 behaviors_added=2" "2" "$(t_json_get "$out" '.behaviors_added')"
    t_assert_eq "S6 behaviors lists both ids" "A1 U1" "$(t_json_get "$out" '.behaviors | join(" ")')"
else
    t_assert_contains "S6 status (grep fallback)" "$out" '"status":"success"'
    t_assert_contains "S6 count (grep fallback)" "$out" '"behaviors_added":2'
fi

# ---------------------------------------------------------------------------
t_report
