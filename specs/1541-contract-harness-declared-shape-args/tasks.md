**Template Version**: `zuraffa-1.0`

# Tasks: 1541-contract-harness-declared-shape-args

Dependency-ordered, MVP-first. T1-T3 are the behavioral MVP (the
red-green loop drives them); T4-T5 are the non-behavioral wiring
(golden regeneration, verification) covered by `/speckit.implement`.

## 1. Harness fix (mvp)

- [ ] **T1** (P1) [behavior: U-1541-1] `contract_test_writer.dart` `_representativeArg`: stop
  emitting the bare literal `null` for `dynamic`/empty declared types —
  fall through to the `_argN()` scaffold placeholder seam (the same seam
  non-renderable complex types already take), so the `_render` placeholder
  scan picks the parameter up and the SCAFFOLD PLACEHOLDERS comment +
  `UnimplementedError` instruction (`provide a representative ... value
  for the ... contract test`) are emitted for `dynamic` params. Nullable
  complex types KEEP `null` (the declared shape is nullable). Update the
  resolver's doc comment. Traces: FR-001, SC-1. Depends: —.
- [ ] **T2** (P1) [behavior: U-1541-2] `contract_test_writer.dart` emitted `_captured`: add the
  catch-all arm (`on Object catch (error) => error`) after the dedicated
  `UnimplementedError` arm; update the helper's doc comment to name the
  split — `UnimplementedError` drives BLOCKED via the Case 2 assertion,
  any other captured error is a satisfied-with-rejection (the seam is
  implemented and validating). No uncaught error may escape the test body.
  Traces: FR-002, FR-003, SC-2. Depends: —.
- [ ] **T3** (P1) [behavior: U-1541-3] `contract_test_writer.dart` `_render`: guard the
  return-type case (Case 3, non-nullable scalar returns) so the
  `expect(outcome, isA<...>())` assertion runs only when the captured
  outcome is NOT a rejection (`outcome is! Error && outcome is! Exception`),
  with a named comment recording the satisfied-with-rejection semantics
  (issue #1541). Case 1/Case 2 text, order, and the
  `isNot(isA<UnimplementedError>())` pin stay byte-unchanged. Traces:
  FR-004, SC-2. Depends: T2.

## 2. Fast-tier render pins (mvp)

- [ ] **T4** (P1) [behavior: U-1541-1, U-1541-2, U-1541-3] [mandatory] `test/plugins/tdd/services/bug_1541_contract_harness_args_test.dart`
  (new, fast tier — no `dart test` spawn): render pins for (a) a
  `dynamic`-param contract renders `impl(_arg0())` and never `impl(null)`,
  with the placeholder helper + SCAFFOLD PLACEHOLDERS comment naming
  `dynamic`; (b) every parseable render emits the catch-all capture
  (`on Object`); (c) the scalar-return render guards Case 3 (the guard
  condition and the named rejection comment present); (d) the nullable
  complex type still resolves to `null` and the #1007 scalar pins
  (`Case 1 of 3` / `Case 2 of 3` / `Case 3 of 3`,
  `isNot(isA<UnimplementedError>())`, `isA<bool>()`) are unchanged for
  `User.validateEmail(String email) -> bool`. Written FIRST (red), then
  T1-T3 turn it green. Traces: FR-001, FR-002, FR-004, SC-1, SC-4.
  Depends: —.

## 3. Slow-tier e2e (mvp)

- [ ] **T5** (P1) [behavior: U-1541-4, U-1541-5] [mandatory] `test/plugins/tdd/commands/contract_satisfied_with_rejection_e2e_1541_test.dart`
  (new, `@Tags(['slow'])` — real `dart test` subprocess, mirroring the
  #1007 e2e harness): (a) an argument-validating seam (throws
  `ArgumentError` for the scaffold's representative argument) executes the
  generated contract test to a PASS (exit 0) and verify-red grades
  `classification=unexpected-green` — satisfied-with-rejection, no seam
  shim; (b) the unimplemented seam STILL grades `classification=blocked`
  with the `contract-blocked.A1.json` receipt (FR-003 unchanged). Traces:
  FR-002, FR-003, FR-004, SC-2, SC-3. Depends: T1-T3.

## 4. Wiring / non-behavioral

- [ ] **T6** (P2) [behavior: U-1541-6] Regenerate the #1513 golden fixture
  `test/fixtures/baseline_outputs/bug_1513_contract_default_render.txt`
  from the updated writer output (same fixture shape: behavior A1/add,
  `int a, int b` params, no pubspec, relative subject import) so the
  byte-comparison pin stays green against UNINTENDED drift. Traces:
  FR-006, SC-5. Depends: T1-T3.
- [ ] **T7** (P1) [behavior: U-1541-7] `tdd/verification.md`: record the red evidence (the T4
  pins failing against the pre-fix writer), the green evidence (analyze
  clean vs baseline, targeted test runs, the e2e verdicts), and the
  changed-file test list. Traces: SC-4. Depends: T1-T6.

## 5. Verification

- [ ] **T8** (P1) Targeted verification pass: `dart analyze` on the
  changed files reports no NEW issues against the pre-change baseline
  (112 pre-existing infos); the changed-file test loop
  (`dart test` per changed/added test file) passes in the fast tier; the
  slow e2e passes under `--preset=slow`/tag selection; `dart format` on
  the touched files introduces no diff beyond the feature. Depends:
  T1-T7.
