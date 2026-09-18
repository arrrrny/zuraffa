# Bug Fix: scalar vacuous-green refusal prints the void/entity explanation

- **Slug**: 1677-scalar-vacuous-green-message
- **Fixed**: 2026-09-18
- **Assessment**: ./assessment.md
- **Status**: applied
- **TDD artifacts**: tdd/test-list.md, tdd/verification.md (repo root, this session)
- **Branch**: `fix/1677-scalar-vacuous-green-message` (isolation from master a9329746)

## Summary

The run driver's make vacuous-green marker-present arm described every
marker-carrying test with the #1308 void/entity template. Since #1651 the
scalar type-only shape's generated test ALSO carries the
`zfa:tdd: vacuous-guard` marker, so a scalar contract
(`add(int a, int b) -> int`) got a refusal paragraph claiming its return
is "void/an entity" and its assertion set is "the UnimplementedError guard
only" — both false, and both contradicting the make refusal excerpt above
it on the same screen (the issue #1651 placeholder wording). The fix
branches the refusal message on the same discriminator the writer's
emission already produced: the scalar type-only expect in the test
content. Scalar contracts get the #1651 scalar explanation; void/entity
contracts keep the #1308 explanation byte-for-byte. Messaging only — the
#1651 gate semantics, the #1308 hand-delta-seam handling, the
`stopped_at=<id>:hand` machine contract, and the `--> fix:` / `hand step:`
lines are unchanged.

## Changes

| File | Change | Notes |
|------|--------|-------|
| `lib/src/plugins/tdd/services/vacuous_guard.dart` | modified | `_typeOnlyScalarExpect` gains a capture group around the declared scalar type (no match-behavior change — `replaceAll` removes the whole match regardless of groups); new public helper `scalarTypeOnlyDeclaredType(content)` returns the declared type the first scalar type-only expect checks, null when absent |
| `lib/src/plugins/tdd/commands/run_driver_core.dart` | modified | the marker-present arm reads the test content (fail-open, `_readTestContentFailOpen`) and branches the middle paragraph: scalar type-only expect present → the #1651 scalar explanation naming the declared type; otherwise → the #1308 void/entity template byte-for-byte. The `hand step:` line and the stop record are untouched |
| `test/plugins/tdd/commands/bug_1677_scalar_vacuous_message_test.dart` | added | driver-level pins: U1 (scalar branch — the RED→GREEN repro), U2 (void/entity branch — the no-regression guard) |

## Diff Highlights

The detector's capture group (issue #1677) — the declared type flows to
the message without changing what the detector strips:

```dart
final RegExp _typeOnlyScalarExpect = RegExp(
  r'\bexpect(?:Later)?\s*\(\s*[^,]*,\s*'
  r'isA\s*<\s*(String|int|num|double|bool)\s*>'   // ← capture group
  r'\s*\(\s*\)'
  r'(?:\s*,\s*(?:reason|skip|timeout)\s*:\s*[^)]*)?'
  r'\s*\)\s*;?',
);

String? scalarTypeOnlyDeclaredType(String content) =>
    _typeOnlyScalarExpect.firstMatch(content)?.group(1);
```

The refusal message's branch (the arm's guard is unchanged; only the
middle paragraph branches):

```dart
final markerContent = _readTestContentFailOpen(testPath);
final scalarType = markerContent == null
    ? null
    : scalarTypeOnlyDeclaredType(markerContent);
if (scalarType != null) {
  print(
    '   the traced contract\'s return is scalar ($scalarType) — '
    'the $vacuousGuardMarker marker\'s assertion set checks the '
    'declared return TYPE only; a func-scaffolded dummy '
    '(`return 0;`) satisfies it (issue #1651).',
  );
} else {
  print(
    '   the traced contract\'s return is void/an entity — the '
    '$vacuousGuardMarker marker IS the designed hand-delta seam '
    '(issue #1308): the assertion set is the UnimplementedError '
    'guard only, which make refuses vacuous-green (issue #1259).',
  );
}
```

## Local Verification

- RED (pre-fix, master a9329746): U1 failed with the driver printing the
  void/entity template verbatim
  (`does not contain 'the traced contract's return is scalar (int)'`);
  U2 (void/entity guard) passed pre-fix, as it must.
- GREEN (post-fix): the new file all-pass (`+2`).
- Vacuous-family regression: fast batch `+47` (1651 detector/writer,
  1651 scenario, 1308 fast, 1512, 1420, 1626, 1483 shape + driver, 1388
  traces fingerprint); slow batch `+24 -3` (1308 driver, 1651 driver
  remedy, 1320, 1488, 1388 reuse fingerprint — the 3 failures are
  PRE-EXISTING on unfixed master, verified by `git stash` A/B: bug_1320
  U6/U7 and issue_1388 U1, the gen-reuse subsystem, unrelated);
  e2e batches `+10` and `+17` (1651 make refusal, 1651 e2e, 1538, 1482).
- `dart analyze` on all touched files → No issues found.
- `dart format` on touched files → 0 changed; `--set-exit-if-changed` →
  exit 0.

## Deviations from Assessment

None — the remediation was applied exactly as assessed (content-keyed
branch on the scalar type-only expect, fail-open to the #1308 wording).

## Follow-ups

- The journal hand-step violation record
  (`vacuousGuardHandStepViolation`) cites "#1308" for both branches; it
  is a record, not the refusal message, and its instruction (write the
  outcome assertion, remove the marker) is accurate for both shapes. A
  follow-up may want a #1651-citing variant for the scalar shape.

## Review Hardening (PR #1701)

The review's one inline finding (🔵 informational) noted
`scalarTypeOnlyDeclaredType` keyed on the FIRST scalar type-only expect:
accurate for every writer-emitted shape (exactly one such expect), but a
future emission or hand-authored marker-carrying test carrying two
type-only expects over different scalars would get a paragraph naming only
the first type. Applied the suggested pluralization: the helper is now
`scalarTypeOnlyDeclaredTypes` — every distinct declared type,
first-occurrence order, duplicates collapsed, comma-joined — and the
driver paragraph interpolates the full set. Single-expect shapes print
byte-for-byte as before (U1/U2 pins unchanged); U3 pins the two-type
shape (`int` then `String`, duplicate `int` collapsed → `scalar (int,
String)`). Detection, gate semantics, and the machine contract are
untouched.
