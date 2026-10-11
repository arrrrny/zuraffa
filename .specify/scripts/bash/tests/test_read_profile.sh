#!/usr/bin/env bash
# test_read_profile.sh — read-tdd-profile.sh suite (P1–P6).
#
# Covers: dart engine JSON (P1), flutter engine with optional commands (P2),
# null optional fields + text "(not configured)" (P3), missing file / no
# frontmatter (P4), missing required fields (P5), text mode (P6).

set -u

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=harness.sh
source "$TESTS_DIR/harness.sh"

READ_PROFILE="$SCRIPTS_DIR/read-tdd-profile.sh"
ROOT="$(t_fixture_dir)"
trap 'rm -rf "$ROOT"' EXIT

# ---------------------------------------------------------------------------
t_case "P1: dart engine profile emits engine + test_command JSON"

PROFILE="$ROOT/p1-profile.md"
cat > "$PROFILE" <<'EOF'
---
engine: dart
test_command: dart test
---

# Stack Profile

Detected: 2026-09-15
EOF

out="$(bash "$READ_PROFILE" "$PROFILE" --json)"
rc=$?
t_assert_exit "P1 succeeds" 0 "$rc"
if t_have_jq; then
    t_assert_eq "P1 engine is dart" "dart" "$(t_json_get "$out" '.engine')"
    t_assert_eq "P1 test_command round-trips" "dart test" "$(t_json_get "$out" '.test_command')"
else
    t_assert_contains "P1 engine (grep fallback)" "$out" '"engine":"dart"'
    t_assert_contains "P1 test_command (grep fallback)" "$out" '"test_command":"dart test"'
fi

# ---------------------------------------------------------------------------
t_case "P2: flutter engine profile emits all four fields"

# Note: fixture values deliberately avoid a trailing quote — the tier-3
# grep/sed fallback strips one trailing quote from a value, while tiers 1-2
# keep it (finding F-1, recorded in analysis.md). Assertions here are
# tier-agnostic so the suite is deterministic in minimal environments.
PROFILE="$ROOT/p2-profile.md"
cat > "$PROFILE" <<'EOF'
---
engine: flutter
test_command: flutter test
verify_command: flutter test --coverage
plan_command: flutter test --plain-name regex
---

# Stack Profile
EOF

out="$(bash "$READ_PROFILE" "$PROFILE" --json)"
rc=$?
t_assert_exit "P2 succeeds" 0 "$rc"
if t_have_jq; then
    t_assert_eq "P2 engine is flutter" "flutter" "$(t_json_get "$out" '.engine')"
    t_assert_eq "P2 test_command" "flutter test" "$(t_json_get "$out" '.test_command')"
    t_assert_eq "P2 verify_command" "flutter test --coverage" "$(t_json_get "$out" '.verify_command')"
    t_assert_eq "P2 plan_command" "flutter test --plain-name regex" "$(t_json_get "$out" '.plan_command')"
else
    t_assert_contains "P2 engine (grep fallback)" "$out" '"engine":"flutter"'
    t_assert_contains "P2 verify (grep fallback)" "$out" '"verify_command":"flutter test --coverage"'
fi

# ---------------------------------------------------------------------------
t_case "P3: absent optional fields are JSON null (and '(not configured)' in text)"

PROFILE="$ROOT/p3-profile.md"
cat > "$PROFILE" <<'EOF'
---
engine: dart
test_command: dart test
---
EOF

out="$(bash "$READ_PROFILE" "$PROFILE" --json)"
rc=$?
t_assert_exit "P3 JSON mode succeeds" 0 "$rc"
if t_have_jq; then
    t_assert_eq "P3 verify_command is null" "null" "$(t_json_get "$out" '.verify_command')"
    t_assert_eq "P3 plan_command is null" "null" "$(t_json_get "$out" '.plan_command')"
else
    t_assert_contains "P3 verify null (grep fallback)" "$out" '"verify_command":null'
fi

out="$(bash "$READ_PROFILE" "$PROFILE")"
rc=$?
t_assert_exit "P3 text mode succeeds" 0 "$rc"
t_assert_contains "P3 text shows (not configured) for verify" "$out" "Verify Command: (not configured)"
t_assert_contains "P3 text shows (not configured) for plan" "$out" "Plan Command: (not configured)"

# ---------------------------------------------------------------------------
t_case "P4: missing file or missing frontmatter fails loudly"

err="$(bash "$READ_PROFILE" "$ROOT/no-such-profile.md" 2>&1 >/dev/null)"
rc=$?
t_assert_exit "P4 missing file exits 1" 1 "$rc"
t_assert_contains "P4 error names the path" "$err" "tdd-profile.md not found"

PROFILE="$ROOT/p4-nofrontmatter.md"
printf '# Stack Profile\n\nEngine: dart\n' > "$PROFILE"
err="$(bash "$READ_PROFILE" "$PROFILE" 2>&1 >/dev/null)"
rc=$?
t_assert_exit "P4 no frontmatter exits 1" 1 "$rc"
t_assert_contains "P4 frontmatter error" "$err" "No YAML frontmatter found"

# ---------------------------------------------------------------------------
t_case "P5: missing engine or missing test_command fails loudly"

PROFILE="$ROOT/p5-no-engine.md"
cat > "$PROFILE" <<'EOF'
---
test_command: dart test
---
EOF
err="$(bash "$READ_PROFILE" "$PROFILE" 2>&1 >/dev/null)"
rc=$?
t_assert_exit "P5 missing engine exits 1" 1 "$rc"
t_assert_contains "P5 engine error" "$err" "Missing required field 'engine'"

PROFILE="$ROOT/p5-no-test-command.md"
cat > "$PROFILE" <<'EOF'
---
engine: dart
---
EOF
err="$(bash "$READ_PROFILE" "$PROFILE" 2>&1 >/dev/null)"
rc=$?
t_assert_exit "P5 missing test_command exits 1" 1 "$rc"
t_assert_contains "P5 test_command error" "$err" "Missing required field 'test_command'"

# ---------------------------------------------------------------------------
t_case "P6: text mode lists Engine and Test Command lines"

PROFILE="$ROOT/p6-profile.md"
cat > "$PROFILE" <<'EOF'
---
engine: dart
test_command: dart test
---
EOF

out="$(bash "$READ_PROFILE" "$PROFILE")"
rc=$?
t_assert_exit "P6 succeeds" 0 "$rc"
t_assert_contains "P6 Engine line" "$out" "Engine: dart"
t_assert_contains "P6 Test Command line" "$out" "Test Command: dart test"

# ---------------------------------------------------------------------------
t_report
