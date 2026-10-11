# Bug Fix: tdd engine lane certifies vacuous greens — unit subjects ship as `return 0;` dummies with result=complete

- **Slug**: 1651-vacuous-green-unit-dummies
- **Fixed**: 2026-09-15
- **Assessment**: ./assessment.md
- **Status**: applied
- **TDD artifacts**: ./tdd/test-list.md, ./tdd/cycle-log.md, ./red-evidence.md, ./tdd/verification.md
- **Branch**: `fix/1651-vacuous-green-unit-dummies` (isolation from master c5ed519f)

## Summary

A scalar-declared contract's generated unit test asserted only the declared
return TYPE (`expect(result, isA<int>())`), which the #1517 func dummy
(`return 0;`) satisfies — so `zfa tdd make` certified a dummy-body green and
the engine receipt reported `complete`. The fix extends the existing
#1259/#1488 vacuous-green machinery to this shape: the writer emits the typed
assertion WITH the `zfa:tdd: vacuous-guard` marker (the entity/void branch's
existing discipline), and the detector's content backstop classifies
scalar-type-only assertion sets as vacuous so legacy marker-less tests are
refused mechanically by every existing consumer (make step-3c, the born-green
arm, the gen contract-drift probe, the #1482 preflight).

## Changes

| File | Change | Notes |
|------|--------|-------|
| `lib/src/plugins/tdd/services/vacuous_guard.dart` | modified | `typeOnlyVacuousGuardComment` constant (marker + #1651 remedy wording); `_typeOnlyScalarExpect` regex; `contentIsVacuousGreen` layer 2 strips scalar type-only expects; module/function docs name #1651 |
| `lib/src/plugins/tdd/services/behavior_test_writer.dart` | modified | `_declaredAssertion` scalar branch emits `$typeOnlyVacuousGuardComment` before the typed assertion; doc updated |
| `test/plugins/tdd/bug_1651_type_only_vacuous_green_test.dart` | added | fast pins: detector vacuity (U1a-c), detector guard rails (U2a-e), writer marker emission (U3) |
| `test/plugins/tdd/commands/bug_1651_make_dummy_green_refusal_test.dart` | added | e2e repro: gen → verify-red → func → make refuses `outcome=vacuous-green` (U4) |
| `test/plugins/tdd/bug_1259_vacuous_green_test.dart` | modified | U5 pin flipped to marker-present; `genSubjectOf`/`genTestOf` path resolution repaired (see Deviations) |
| `test/plugins/tdd/commands/plan_traces_cell_1310_test.dart` | modified | U5 pin flipped to marker-present; U6 flipped from "make certifies the `=> false;` dummy" to "make refuses vacuous-green" |
| `test/plugins/tdd/services/bug_1538_void_guard_compile_test.dart` | modified | B1 pin flipped to marker-present |
| `test/plugins/tdd/services/bug_1512_acceptance_vacuous_composition_test.dart` | modified | unit-scalar guardrail pin flipped to marker-present (capture shape unchanged) |

## Diff Highlights

The detector's new strip (the precise vacuity class — dummy-satisfiable
scalar types only):

```dart
final RegExp _typeOnlyScalarExpect = RegExp(
  r'expect\s*\(\s*[A-Za-z_][A-Za-z0-9_]*\s*,\s*'
  r'isA\s*<\s*(?:String|int|num|double|bool)\s*>'
  r'\s*\(\s*\)\s*\)\s*;?',
);
```

Precision guards: `isNot(isA<T>())` and `throwsA(isA<T>())` do NOT match
(both FAIL on a dummy — they discriminate); composite/generic types and
entity-type `isA<T>()` stay real (entity subjects cannot be dummied — #1517
leaves the throw in place).

The writer's scalar branch (same marker discipline the entity/void branch
already had):

```dart
if (shape.scalarOutcome) {
  return '$capture\n'
      '      $typeOnlyVacuousGuardComment\n'
      '      expect(result, isA<${shape.declaredReturn}>());';
}
```

## Tests Added or Updated

- `bug_1651_type_only_vacuous_green_test.dart` (9 tests) — the detector's
  vacuity boundary and the writer's marker emission.
- `bug_1651_make_dummy_green_refusal_test.dart` (e2e) — the issue's exact
  repro, end to end, with the no-green-evidence assertion.
- Legacy pins flipped where they coded the old assumption: the pre-#1651
  contract "typed outcome assertion ⇒ no marker ⇒ make certifies a
  dummy-satisfied green" was #1651 itself, pinned as a feature by 1310 U6.

## Local Verification

- RED (pre-fix): fast pins `+5 -4` (U1a-c + U3 fail; U2 guard rails pass);
  e2e fails at the marker pin with gen's verbatim marker-less output.
- GREEN (post-fix): both new files all-pass (9 + 1).
- Vacuous-family regression: fast batch `+46` (1483 shape, 1308, 1626,
  1512, arg_placeholder, behavior_test_writer, 1320, 1388, 1323 seam);
  slow/e2e batch `+33` (1259, 1538, 1310, 1411, `--preset=all` scoped to
  those files); untagged driver batch (1483 driver, 1308 driver, 1626
  driver, 1323 driver, 1652) + the 1651 e2e — all passed.
- `dart format` on touched files; `dart analyze` on all touched lib and
  test files → No issues found.
- Never ran the full `dart test test` tree (the surgical contract;
  AGENTS.md disk guidance).

## Deviations from Assessment

- The assessment's "Suspected Code Paths / Root Cause / Proposed
  Remediation" were fetch-seeded `[NEEDS CLARIFICATION]` placeholders
  (bug-whole chains fix→test→PR without an assess step); the TDD plan
  phase filled them. No assessment claim was contradicted.
- Scope note recorded in spec.md: issue ask 1 (mechanically deriving
  scenario-value assertions for unit behaviors) is a FEATURE, not this
  fix — the repo parses no structured Given/When/Then value model
  (`_extractScenarioText` keeps only the Then-clause text). The fix
  implements asks 2 + 3 (refuse the dummy green; the stop/remedy is the
  designed hand step), which close the vacuous-complete hole this issue
  reports. Ask 1 remains a follow-up.
- Pre-existing master breakage repaired to make verification possible:
  `bug_1259_vacuous_green_test.dart`'s `genSubjectOf`/`genTestOf` still
  read the registry record's relative path against the runner CWD —
  broken by `69d0f768 fix(1574)` (gen switched to the portable
  project-relative record form) and unrun since (the file is
  `@Tags(['slow'])`, excluded from the default suite). U4/U5/U6 threw
  `PathNotFoundException` on UNFIXED master too. Repaired with the same
  root-joining resolver `plan_traces_cell_1310_test.dart` already uses.
  This is test infrastructure, not a behavior change; the maintainer may
  want a follow-up sweep for other slow-tier suites still reading
  #1574-era records CWD-relative.

## Follow-ups

- Issue ask 1: derive example-based unit assertions from acceptance
  Given/When/Then scenario values (needs a structured scenario-value
  model in `spec_parser.dart`).
- Sweep the slow/e2e tiers for more #1574 drift of the bug_1259 kind
  (suites that only run under `--preset=all`).
- The receipt-level `vacuous` marker (issue ask 3) is superseded for this
  class: the behavior now stops at `<id>:hand`/`<id>:make` instead of
  reaching `done`, so no false `complete` is ever emitted.
