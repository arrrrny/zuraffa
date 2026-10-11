# Tasks: 1538-void-returning-contract-compile-fix

- **Spec ID**: 1538-void-returning-contract-compile-fix
- **Created**: 2026-09-13

Dependency order: T001 (red tests) → T002 (fix) → T003 (verify + evidence).
MVP-first: T001+T002 are the whole behavioural surface; T003 is
non-behavioural.

## T001: Red tests — void-safe guard emission (MVP)

- New `test/plugins/tdd/services/bug_1538_void_guard_compile_test.dart`,
  content pins through `BehaviorTestWriter(contractShape: shape).write()` +
  `SubjectWriter(contractShape: shape).write()` into temp dirs:
  - A1 (SC-1): declared `log(String message) -> void` → the emitted test
    contains `Object? result;`, the bare call `subject.subject_u1(r'sample');`,
    `result = null;`, `result = error;` — and NOT `return subject.` /
    `final result = (() {`
  - A2 (SC-1): declared `sync(SyncRequest request, SyncOptions options) ->
    void` → the `_arg0()`/`_arg1()` placeholder helpers still precede the
    capture and the call site keeps both placeholders (the symptom shape)
  - A3 (SC-3): the void test carries `vacuousGuardComment` (marker) and its
    only expectation is the guard → `contentIsVacuousGreen` true AND
    `contentCarriesVacuousGuardMarker` true (the hand-step seam), and no
    typed `expect(result, isA<…>()` assertion is emitted
  - B1 (SC-2): declared `-> bool` keeps `final result = (() {` +
    `return subject.…` + `expect(result, isA<bool>())` (characterization)
  - B2 (SC-2): declared entity return keeps the IIFE + marker guard
    (characterization)
  - C1 (SC-4, tags: 'slow'): the void pair (test + `void` stub) runs under
    `dart test` in a temp package → non-zero exit (honest red), output has
    no `compile-time error` / `undefined name`, has Expected/Actual
- Run the file → RED (evidence: `tdd/red-1538.log`; A1/A2/A3/C1 fail, B1/B2
  pass)
- Tests: `bug_1538_void_guard_compile_test.dart`

## T002: Green — void branch in `_captureInvocation`

- `lib/src/plugins/tdd/services/behavior_test_writer.dart`,
  `_captureInvocation` only: when
  `!acceptance && shape != null && shape.declaredReturn.trim() == 'void'`,
  return the statement-based capture (`Object? result; try { subject.<target>(
  <args>); result = null; } on UnimplementedError catch (error) { result =
  error; }`) — helpers/args composition unchanged; the acceptance and
  default IIFE branches keep their bytes
- No other lib/ file changes: contract lane, parameter grammar, subject
  stub signature, markers, state machine untouched
- Tests: T001 set turns green (A1/A2/A3/C1), B1/B2 stay green

## T003: Verification + evidence (non-behavioural)

- Regression sweep: `dart test` the writer/subject test family
  (`test/plugins/tdd/services/behavior_test_writer_test.dart`,
  `behavior_test_writer_persistence_833_test.dart`,
  `bug_1512_acceptance_vacuous_composition_test.dart`,
  `bug_1443_void_contract_seam_test.dart`,
  `subject_writer_test.dart`,
  `unit_contract_shape_1489_test.dart`,
  `issue_1308_vacuous_guard_remedy_test.dart`)
- `dart analyze` — no new issues vs baseline (0 errors / 0 warnings / 112
  pre-existing infos)
- Mutation evidence: revert the void branch → A1/A2/A3/C1 fail (mutant
  killed) → restore → green
- `dart format .` → zero diffs on changed files
- Write `tdd/verification.md` (gates table + red/green/mutation logs)
