Fixes #1651

## Summary

`zfa tdd run` certified `result=complete, done=10` on the zcalc probe while
all four unit subjects were func-scaffolded dummies (`return 0;`). The hole:
the #1259 remediation replaced the bare guard with a typed assertion
(`expect(result, isA<int>())`) for scalar-declared contracts — but the #1517
func pass fills the subject with `return 0;`, which SATISFIES a type check,
so the terminal dummy-body green persisted and `contentIsVacuousGreen`
counted the type-only assertion as real evidence.

The fix extends the existing #1259/#1488/#1626 vacuous-green machinery to
this shape:

- **Writer (FR-001)** — `BehaviorTestWriter._declaredAssertion`'s scalar
  branch now emits the typed assertion WITH the `zfa:tdd: vacuous-guard`
  marker and a #1651 remedy comment — the same marker discipline the
  entity/void branch already carries. Marker presence routes the run
  driver's existing `stopped_at=<id>:hand` hand-step machinery unchanged.
- **Detector (FR-002)** — `contentIsVacuousGreen`'s content backstop strips
  scalar-type-only `expect(x, isA<T>())` expects (T ∈
  {String, int, num, double, bool} — the #1517 dummy literal set) so legacy
  marker-less tests are refused by every existing consumer (make step-3c,
  the born-green arm, the gen contract-drift probe, the #1482 preflight).
  `isNot(...)`-wrapped, `throwsA(...)`, composite, and entity-type `isA<T>()`
  assertions stay real — all of them FAIL on a dummy, so they discriminate.
- **Existing stop machinery (FR-003)** — untouched: make's step-3c unit
  remedy already prescribes the designed unlock (write an assertion on the
  observable outcome named by the behavior description — the spec's scenario
  values — remove the marker, re-run make).
- **Legacy pins (FR-004)** — four pins that coded the old assumption
  ("typed ⇒ no marker ⇒ make certifies a dummy green") are updated to the
  new contract; `plan_traces_cell_1310_test.dart` U6 previously pinned the
  exact #1651 bug as a feature ("make certifies green … the dummy
  `=> false;`") and now pins the refusal.

Issue ask 1 (mechanically deriving scenario-value unit assertions from
Given/When/Then) stays a follow-up: the repo parses no structured
scenario-value model (`_extractScenarioText` keeps only the Then-clause
text). Until it lands, the hand step is the unlock — the #1488/#1626
remedy family. Ask 3 (a receipt-level `vacuous` marker) is superseded: the
behavior now stops at `<id>:hand`/`<id>:make` instead of reaching `done`,
so no false `complete` is emitted.

## Changes

| File | Change | Notes |
|------|--------|-------|
| `lib/src/plugins/tdd/services/vacuous_guard.dart` | modified | `typeOnlyVacuousGuardComment` + `_typeOnlyScalarExpect` strip in `contentIsVacuousGreen` layer 2 |
| `lib/src/plugins/tdd/services/behavior_test_writer.dart` | modified | scalar branch emits the marker comment before the typed assertion |
| `test/plugins/tdd/bug_1651_type_only_vacuous_green_test.dart` | added | fast pins: detector vacuity (U1a-c), guard rails (U2a-e), writer marker (U3) |
| `test/plugins/tdd/commands/bug_1651_make_dummy_green_refusal_test.dart` | added | e2e repro: gen → verify-red → func → make refuses (`@Tags(['e2e'])`, #1510 convention) |
| `test/plugins/tdd/bug_1259_vacuous_green_test.dart` | modified | U5 pin flipped to marker-present; path-helper repair (see below) |
| `test/plugins/tdd/commands/plan_traces_cell_1310_test.dart` | modified | U5 pin flipped; U6 certify→refuse |
| `test/plugins/tdd/services/bug_1538_void_guard_compile_test.dart` | modified | B1 pin flipped to marker-present |
| `test/plugins/tdd/services/bug_1512_acceptance_vacuous_composition_test.dart` | modified | unit-scalar guardrail pin flipped (capture shape unchanged) |

## TDD evidence (red → green)

- RED (pre-fix): fast pins `+5 -4` (detector counts the type-only shape
  real; gen emits marker-less — the failing e2e captured gen's verbatim
  `subject.subject_u1(0, 0)` + `expect(result, isA<int>())`); the U2
  guard rails passed red AND green.
- GREEN (post-fix): fast pins 9/9; e2e repro passes (make refuses, no
  green evidence appended).
- Family regression: fast batch `+46` (1483 shape, 1308, 1626, 1512,
  arg_placeholder, behavior_test_writer, 1320, 1388, 1323 seam); slow/e2e
  batch `+33` (1259, 1538, 1310, 1411); untagged drivers (1483, 1308,
  1626, 1323, 1652) — all passed.
- Mutation probes on the changed seams: detector strip removed → killed
  by U1a-c; wrong comment constant → killed by U3; restores green.
- `dart analyze` on all touched files: No issues found; `dart format`
  applied.

Full evidence: `.specify/bugs/1651-vacuous-green-unit-dummies/`
(`red-evidence.md`, `tdd/cycle-log.md`, `tdd/verification.md` — verdict
**PASS**, `fix.md`, `test.md`). Assessment:
`.specify/bugs/1651-vacuous-green-unit-dummies/assessment.md`.

## Pre-existing breakage repaired in passing

`bug_1259_vacuous_green_test.dart`'s `genSubjectOf`/`genTestOf` still read
the registry record's relative path against the runner CWD — broken by
`69d0f768 fix(1574)` (gen switched to the portable project-relative record
form) and unrun since (the file is `@Tags(['slow'])`): U4/U5/U6 threw
`PathNotFoundException` on UNFIXED master. Repaired with the same
root-joining resolver `plan_traces_cell_1310_test.dart` already uses. A
follow-up sweep of the slow tiers for more #1574 drift is worthwhile.

Closes #1651.
