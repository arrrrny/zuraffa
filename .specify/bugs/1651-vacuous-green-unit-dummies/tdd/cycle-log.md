# Cycle Log: 1651-vacuous-green-unit-dummies (#1651)

Baseline seeded by `tdd.plan` (LLM-guided fallback path — `ZFA_MISSING`,
issue #1182/bug-TDD precedent). Loop driven by the red-green-refactor
contract: each cycle records the command, the exit, and the evidence.

## Baseline

- at: 2026-09-15
- suite: fast tier (`dart test`, default preset — slow tiers excluded)
- tree: `fix/1651-vacuous-green-unit-dummies` @ master (c5ed519f) + 0c24… lineage
- state: RED phase armed — `test/plugins/tdd/bug_1651_type_only_vacuous_green_test.dart`
  written against the UNFIXED detector/writer (vacuous_guard.dart layer-2
  counts type-only `isA<T>()` real; `_declaredAssertion` scalar branch
  emits without the marker)

## Cycle: U1-U4 (red)

- behavior: U1, U2, U3, U4
- kind: red
- classification: assertionFailure
- criterion: FR-001, FR-002
- test: test/plugins/tdd/bug_1651_type_only_vacuous_green_test.dart,
  test/plugins/tdd/commands/bug_1651_make_dummy_green_refusal_test.dart
- command: `dart test test/plugins/tdd/bug_1651_type_only_vacuous_green_test.dart`
  → `+5 -4` (U1a/U1b/U1c detector classification + U3 marker emission fail;
  the U2 guard rails pass);
  `dart test test/plugins/tdd/commands/bug_1651_make_dummy_green_refusal_test.dart`
  → the real `zfa tdd gen` output has NO marker:
  `Which: does not contain 'zfa:tdd: vacuous-guard'` on
  `expect(result, isA<int>())` after `subject.subject_u1(0, 0)`
- at: 2026-09-15
- evidence: `../red-evidence.md`

## Cycle: U1-U4 + A2 (green)

- behavior: U1, U2, U3, U4, A2
- kind: green
- criterion: FR-001, FR-002, FR-003, FR-004
- fix: vacuous_guard.dart (`typeOnlyVacuousGuardComment` +
  `_typeOnlyScalarExpect` strip in `contentIsVacuousGreen` layer 2) +
  behavior_test_writer.dart (`_declaredAssertion` scalar branch emits the
  marker comment); legacy pins flipped (bug_1259 U5, 1310 U5, 1310 U6
  certify→refuse, 1538 B1, 1512 guardrail) + bug_1259 path-helper repair
  (pre-existing #1574 drift, see fix.md Deviations)
- commands and exits:
  - `dart test test/plugins/tdd/bug_1651_type_only_vacuous_green_test.dart`
    → `+9: All tests passed!`
  - `dart test test/plugins/tdd/commands/bug_1651_make_dummy_green_refusal_test.dart`
    → `+1: All tests passed!` (gen→verify-red→func→make refuses
    `outcome=vacuous-green`; no green evidence appended)
  - fast family batch (1483 shape, 1308, 1626, 1512, arg_placeholder,
    behavior_test_writer, 1320, 1388, 1323 seam) → `+46: All tests passed!`
  - slow/e2e family batch (1259, 1538, 1310, 1411, `--preset=all`) →
    `+33: All tests passed!`
  - untagged driver batch (1483 driver, 1308 driver, 1626 driver, 1323
    driver, 1652, 1651 e2e) → all passed
  - `dart format` on the 8 touched files (wrapping only);
    `dart analyze` on all touched files → No issues found
- at: 2026-09-15
- suite: fast tier + explicit family files (`--preset=all` scoped to the
  vacuous-family paths — never the full `test` tree)

