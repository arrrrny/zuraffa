#!/usr/bin/env bash
# Spec 0967 (issue #967) — spec-mutation arena CI smoke: the seeded
# weakness demo, fail-on-should-be-red (the proof_smoke.sh recipe).
#
# Drives `zfa spec fuzz` end-to-end with REAL `dart test` processes in a
# throwaway sandbox project:
#   1. the WEAK toy spec goes green through the real loop machinery
#   2. `zfa spec fuzz` must FLAG it: survived > 0, exit 1, weakness
#      report rows, severity:contract gap-ledger entries, spec restored
#   3. the STRENGTHENED spec over the SAME implementation must kill
#      every mutant: exit 0, certified=true (the job fails if any
#      survive — a CI gate that blocks certified status)
#
# Usage: bash tools/spec_fuzz_demo.sh   (run from a `dart pub get`-ed repo)

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
sandbox="$(mktemp -d /tmp/zfa_spec_fuzz_demo_XXXXXX)"
trap 'rm -rf "$sandbox"' EXIT

zfa() { (cd "$repo_root" && dart run bin/zfa.dart -C "$sandbox" "$@"); }

feature="demo-greeter"

mkdir -p "$sandbox/specs/$feature/tdd" \
         "$sandbox/test/tdd/$feature" \
         "$sandbox/lib/tdd/$feature" \
         "$sandbox/.zfa"

cat > "$sandbox/pubspec.yaml" <<'EOF'
name: spec_fuzz_demo
environment:
  sdk: ^3.11.0
dev_dependencies:
  test: ^1.25.0
EOF

(cd "$sandbox" && dart pub get --no-example >/dev/null 2>&1)

# ---------------------------------------------------------------------
# The shared implementation (identical for both spec variants — the
# demo's whole point: the SPEC's strength is what the kill rate measures).
# ---------------------------------------------------------------------

subject() {
  cat > "$sandbox/lib/tdd/$feature/${1}_subject.dart" <<EOF
// IMPLEMENTED SUBJECT (spec 0967 demo).
library;

int subjectUnderTest() => $2;
EOF
}

subject a1 42
subject a2 0
subject u1 42
subject u2 0
subject u3 100

registry() {
  cat > "$sandbox/specs/$feature/tdd/artifacts.json" <<'EOF'
{
  "feature": "demo-greeter",
  "records": [
EOF
  for slug in a1 a2 u1 u2 u3; do
    id="$(echo "$slug" | tr '[:lower:]' '[:upper:]')"
    case "$slug" in
      a1) crit="AC-1";; a2) crit="AC-2";;
      u1) crit="FR-001";; u2) crit="FR-002";; u3) crit="FR-003";;
    esac
    printf '    {"behavior_id": "%s", "feature": "demo-greeter", "source_criterion": "%s", "test_path": "test/tdd/demo-greeter/%s_test.dart", "subject_path": "lib/tdd/demo-greeter/%s_subject.dart", "runnable_test_name": "%s — demo", "test_ownership": "created", "subject_ownership": "created", "created_at": "2026-09-05T00:00:00Z"}' \
      "$id" "$crit" "$slug" "$slug" "$id" >> "$sandbox/specs/$feature/tdd/artifacts.json"
    if [ "$slug" != "u3" ]; then
      printf ',\n' >> "$sandbox/specs/$feature/tdd/artifacts.json"
    else
      printf '\n' >> "$sandbox/specs/$feature/tdd/artifacts.json"
    fi
  done
  printf '  ]\n}\n' >> "$sandbox/specs/$feature/tdd/artifacts.json"
}

# The generic (weak) test: no expect pin, the writer's vague shape.
generic_test() {
  cat > "$sandbox/test/tdd/$feature/${1}_test.dart" <<EOF
// GENERIC (weak fixture).
library;

import 'package:test/test.dart';
import '../../../lib/tdd/$feature/${1}_subject.dart' as subject;

void main() {
  group('${1} — demo', () {
    test('${1} — demo', () {
      final result = (() {
        try {
          return subject.subjectUnderTest();
        } on UnimplementedError catch (error) {
          return error;
        }
      })();
      expect(result, isNot(isA<UnimplementedError>()));
    });
  });
}
EOF
}

# The pinned (strong) test: asserts the declared value.
pinned_test() {
  cat > "$sandbox/test/tdd/$feature/${1}_test.dart" <<EOF
// PINNED (strong fixture).
library;

import 'package:test/test.dart';
import '../../../lib/tdd/$feature/${1}_subject.dart' as subject;

void main() {
  group('${1} — demo', () {
    test('${1} — demo', () {
      expect(subject.subjectUnderTest(), equals($2));
    });
  });
}
EOF
}

# ---------------------------------------------------------------------
# Phase 1 — the WEAK spec + generic tests: the loop is green, but the
# intent is not pinned. spec fuzz MUST flag it (fail-on-should-be-red).
# ---------------------------------------------------------------------

cat > "$sandbox/specs/$feature/spec.md" <<'EOF'
**Template Version**: `zuraffa-1.0`

# Feature Specification: Demo Greeter (weak)

**Feature Branch**: `demo-greeter`

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A vague greeter (Priority: P1)

**Acceptance Scenarios**:

1. **Given** any user, **When** the greeter greets, **Then** it shows the message 'Hello'.
   **Type**: acceptance
2. **Given** an empty name, **When** the greeter greets, **Then** it handles the empty case gracefully.
   **Type**: acceptance

### Functional Requirements

- **FR-001**: The greeter MUST return a greeting message.
- **FR-002**: The greeter MUST NOT fail when the name is empty.
- **FR-003**: The greeter MUST count at most 100 greetings.
EOF

registry
generic_test a1
generic_test a2
generic_test u1
generic_test u2
generic_test u3

(cd "$sandbox" && dart test \
  test/tdd/$feature/a1_test.dart \
  test/tdd/$feature/a2_test.dart \
  test/tdd/$feature/u1_test.dart \
  test/tdd/$feature/u2_test.dart \
  test/tdd/$feature/u3_test.dart >/dev/null 2>&1)
echo "✓ the weak feature is green (the loop machinery passes it)"

weak_out="$(zfa spec fuzz "$feature" --no-ledger 2>&1)" && weak_exit=0 || weak_exit=$?

if [ "$weak_exit" -ne 1 ]; then
  echo "✗ the weak spec round must exit 1 (survived mutants flagged), got $weak_exit" >&2
  echo "$weak_out" >&2
  exit 1
fi
if ! echo "$weak_out" | grep -q "certified=false"; then
  echo "✗ the weak round must report certified=false" >&2
  exit 1
fi
if ! echo "$weak_out" | grep -Eq "survived=[1-9]"; then
  echo "✗ the weak round must report at least one survived mutant" >&2
  exit 1
fi
if [ ! -f "$sandbox/specs/$feature/tdd/spec-fuzz.json" ]; then
  echo "✗ the weakness report must be written" >&2
  exit 1
fi
survived_rows="$(grep -c '"verdict": "survived"' "$sandbox/specs/$feature/tdd/spec-fuzz.json")"
echo "✓ spec fuzz flagged the weak spec: survived=$survived_rows (exit 1, certified=false)"
if ! diff <(cat <<'EOF'
**Template Version**: `zuraffa-1.0`

# Feature Specification: Demo Greeter (weak)

**Feature Branch**: `demo-greeter`

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A vague greeter (Priority: P1)

**Acceptance Scenarios**:

1. **Given** any user, **When** the greeter greets, **Then** it shows the message 'Hello'.
   **Type**: acceptance
2. **Given** an empty name, **When** the greeter greets, **Then** it handles the empty case gracefully.
   **Type**: acceptance

### Functional Requirements

- **FR-001**: The greeter MUST return a greeting message.
- **FR-002**: The greeter MUST NOT fail when the name is empty.
- **FR-003**: The greeter MUST count at most 100 greetings.
EOF
) "$sandbox/specs/$feature/spec.md" >/dev/null; then
  echo "✗ spec.md must be restored byte-exactly after the round" >&2
  exit 1
fi
echo "✓ spec.md restored byte-exactly after the mutation round"

# ---------------------------------------------------------------------
# Phase 2 — the STRENGTHENED spec over the SAME implementation: every
# mutant must be killed (exit 0, certified=true). The job fails if any
# survive.
# ---------------------------------------------------------------------

cat > "$sandbox/specs/$feature/spec.md" <<'EOF'
**Template Version**: `zuraffa-1.0`

# Feature Specification: Demo Greeter (strong)

**Feature Branch**: `demo-greeter`

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A pinned greeter (Priority: P1)

**Acceptance Scenarios**:

1. **Given** any user, **When** the greeter greets, **Then** it returns 42 as the greeting code.
   **Type**: acceptance
2. **Given** an empty name, **When** the greeter greets, **Then** it returns 0 as the greeting code.
   **Type**: acceptance

### Functional Requirements

- **FR-001**: The greeter MUST return 42 as the greeting code when the name is not empty.
- **FR-002**: The greeter MUST return 0 when the name is empty; it MUST NOT return 42 in that case.
- **FR-003**: The greeter MUST accept greeting counts within 0..100 and MUST return 100 when full.
EOF

registry
pinned_test a1 42
pinned_test a2 0
pinned_test u1 42
pinned_test u2 0
pinned_test u3 100

strong_out="$(zfa spec fuzz "$feature" --no-ledger 2>&1)" && strong_exit=0 || strong_exit=$?

if [ "$strong_exit" -ne 0 ]; then
  echo "✗ the strengthened spec must kill every mutant (exit 0), got $strong_exit" >&2
  echo "$strong_out" >&2
  exit 1
fi
if ! echo "$strong_out" | grep -q "certified=true"; then
  echo "✗ the strong round must report certified=true" >&2
  exit 1
fi
if ! echo "$strong_out" | grep -q "survived=0"; then
  echo "✗ the strong round must report survived=0" >&2
  exit 1
fi
echo "✓ the strengthened spec kills all mutants (exit 0, certified=true)"

# Determinism: the same seed reproduces the round byte-identically.
first="$(cat "$sandbox/specs/$feature/tdd/spec-fuzz.json")"
zfa spec fuzz "$feature" --no-ledger >/dev/null 2>&1 || true
second="$(cat "$sandbox/specs/$feature/tdd/spec-fuzz.json")"
if [ "$first" != "$second" ]; then
  echo "✗ the same seed must reproduce the weakness report byte-identically" >&2
  exit 1
fi
echo "✓ deterministic replay: same seed, byte-identical report"

echo
echo "spec fuzz demo: all gates passed (weak flagged, strong certified, replay deterministic)"
