#!/usr/bin/env bash
# test_tick_behavior.sh — tick-behavior-task.sh suite (T1–T7).
#
# Covers: exact-line tick (T1), already_done no-op (T2), unknown id (T3),
# duplicate markers tick-first + warning (T4), missing --behavior flag (T5),
# JSON success shape (T6), permission-bit preservation (T7).

set -u

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=harness.sh
source "$TESTS_DIR/harness.sh"

TICK="$SCRIPTS_DIR/tick-behavior-task.sh"
ROOT="$(t_fixture_dir)"
trap 'rm -rf "$ROOT"' EXIT

# ---------------------------------------------------------------------------
t_case "T1: ticks exactly the requested line, all other lines byte-identical"

TASKS="$ROOT/t1-tasks.md"
cat > "$TASKS" <<'EOF'
# Tasks

- [ ] implement thing [behavior: U1]
- [ ] other thing
- [ ] second thing [behavior: U2]
EOF

out="$(bash "$TICK" "$TASKS" --behavior U1 --json)"
rc=$?
t_assert_exit "T1 succeeds" 0 "$rc"

# Byte-exact comparison via diff (command substitution strips trailing
# newlines, so $()-to-literal comparison would false-fail here).
printf '%s\n' '# Tasks' '' '- [x] implement thing [behavior: U1]' '- [ ] other thing' '- [ ] second thing [behavior: U2]' > "$ROOT/t1-expected.md"
if diff -u "$ROOT/t1-expected.md" "$TASKS" > "$ROOT/t1-diff.txt" 2>&1; then
    t_pass "T1 only the U1 line changed"
else
    t_fail "T1 only the U1 line changed"
    sed 's/^/      /' "$ROOT/t1-diff.txt"
fi

# ---------------------------------------------------------------------------
t_case "T2: already-ticked behavior reports already_done and rewrites nothing"

TASKS="$ROOT/t2-tasks.md"
cat > "$TASKS" <<'EOF'
- [x] done deal [behavior: U1]
EOF
before="$(t_file_hash "$TASKS")"

out="$(bash "$TICK" "$TASKS" --behavior U1 --json)"
rc=$?
t_assert_exit "T2 exits 0" 0 "$rc"
t_assert_eq "T2 file unchanged" "$before" "$(t_file_hash "$TASKS")"
if t_have_jq; then
    t_assert_eq "T2 status=already_done" "already_done" "$(t_json_get "$out" '.status')"
else
    t_assert_contains "T2 already_done (grep fallback)" "$out" '"status":"already_done"'
fi
out="$(bash "$TICK" "$TASKS" --behavior U1)"
t_assert_contains "T2 text mode reports already ticked" "$out" "already ticked"

# ---------------------------------------------------------------------------
t_case "T3: unknown behavior id exits non-zero without mutating the file"

TASKS="$ROOT/t3-tasks.md"
cat > "$TASKS" <<'EOF'
- [ ] present [behavior: U1]
EOF
before="$(t_file_hash "$TASKS")"

err="$(bash "$TICK" "$TASKS" --behavior Z9 2>&1 >/dev/null)"
rc=$?
t_assert_exit "T3 exits non-zero" 1 "$rc"
t_assert_contains "T3 error names the behavior" "$err" "Behavior 'Z9' not found"
t_assert_eq "T3 file unchanged" "$before" "$(t_file_hash "$TASKS")"

# ---------------------------------------------------------------------------
t_case "T4: duplicate markers — first ticked, warning emitted, second untouched"

TASKS="$ROOT/t4-tasks.md"
cat > "$TASKS" <<'EOF'
- [ ] first [behavior: U1]
- [ ] second [behavior: U1]
EOF

err="$(bash "$TICK" "$TASKS" --behavior U1 2>"$ROOT/t4-stderr.txt" >/dev/null)"
rc=$?
err="$(cat "$ROOT/t4-stderr.txt")"
t_assert_exit "T4 succeeds (first occurrence)" 0 "$rc"
t_assert_contains "T4 multiple-marker warning" "$err" "WARNING: Multiple markers found for behavior U1"
t_assert_contains "T4 first line ticked" "$(sed -n '1p' "$TASKS")" "- [x] first [behavior: U1]"
t_assert_contains "T4 second line still unticked" "$(sed -n '2p' "$TASKS")" "- [ ] second [behavior: U1]"

# ---------------------------------------------------------------------------
t_case "T5: missing --behavior flag fails with usage on stderr"

TASKS="$ROOT/t5-tasks.md"
cat > "$TASKS" <<'EOF'
- [ ] thing [behavior: U1]
EOF

err="$(bash "$TICK" "$TASKS" 2>&1 >/dev/null)"
rc=$?
t_assert_exit "T5 omitted flag exits 1" 1 "$rc"
t_assert_contains "T5 usage shown" "$err" "Missing required flag --behavior"

err="$(bash "$TICK" "$TASKS" --behavior 2>&1 >/dev/null)"
rc=$?
t_assert_exit "T5 dangling --behavior exits 1" 1 "$rc"
t_assert_contains "T5 dangling flag usage shown" "$err" "Missing required flag --behavior"

# ---------------------------------------------------------------------------
t_case "T6: --json success shape carries status and behavior_id"

TASKS="$ROOT/t6-tasks.md"
cat > "$TASKS" <<'EOF'
- [ ] thing [behavior: U1]
EOF

out="$(bash "$TICK" "$TASKS" --behavior U1 --json)"
rc=$?
t_assert_exit "T6 succeeds" 0 "$rc"
if t_have_jq; then
    t_assert_eq "T6 status=success" "success" "$(t_json_get "$out" '.status')"
    t_assert_eq "T6 behavior_id echoed" "U1" "$(t_json_get "$out" '.behavior_id')"
else
    t_assert_contains "T6 status (grep fallback)" "$out" '"status":"success"'
    t_assert_contains "T6 id (grep fallback)" "$out" '"behavior_id":"U1"'
fi

# ---------------------------------------------------------------------------
t_case "T7: file permission bits preserved across the atomic replace"

TASKS="$ROOT/t7-tasks.md"
cat > "$TASKS" <<'EOF'
- [ ] thing [behavior: U1]
EOF
chmod 644 "$TASKS"

bash "$TICK" "$TASKS" --behavior U1 >/dev/null 2>&1
rc=$?
t_assert_exit "T7 tick succeeds" 0 "$rc"
t_assert_eq "T7 mode still 644" "644" "$(t_file_mode "$TASKS")"

# ---------------------------------------------------------------------------
t_report
