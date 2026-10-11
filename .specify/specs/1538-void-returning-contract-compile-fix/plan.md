# Plan: 1538-void-returning-contract-compile-fix

- **Spec ID**: 1538-void-returning-contract-compile-fix
- **Created**: 2026-09-13

## Technical Context

- **Subject**: `BehaviorTestWriter._captureInvocation` — the guard-template
  emission in `lib/src/plugins/tdd/services/behavior_test_writer.dart` that
  renders the capture block at the head of every UNIT-lane test body. Today
  it has exactly two shapes: the acceptance lane's parameterless void-safe
  capture (`subject.<target>(); return null;` inside the IIFE) and the
  default IIFE with `return subject.<target>(<args>);`.
- **Void flow**: `gen_command.dart` resolves a `UnitContractShape` for every
  unit behavior with a declared signature (`UnitContractShape.ofResolved`).
  For declared return `void`: `void` ∈ `_renderableScalars` →
  `shape.returnType == 'void'` renders the stub verbatim
  (`SubjectWriter._renderContractUnitSubject`:
  `void subject_u3(...) => throw …`), and `shape.scalarOutcome == false`
  (`isAssertableScalarType` excludes void) → `_declaredAssertion` emits the
  `vacuousGuardComment` + bare guard. The capture is the ONLY broken piece.
- **Detection surface** (must keep working, unchanged):
  `contentIsVacuousGreen` strips `expect(result, isNot(isA<UnimplementedError>()));`
  via `_guardExpect` and refuses the test vacuous-green; the marker in
  `vacuousGuardComment` routes the run driver to
  `stopped_at=<id>:hand` (`run_driver_core.dart` marker dispatch,
  `contentCarriesVacuousGuardMarker`). Both are content-based — the
  statement-based capture preserves them.
- **Language/SDK**: Dart 3.13.3, pure-Dart package. Tests: `package:test`,
  patterned on `bug_1512_acceptance_vacuous_composition_test.dart` (content
  pins through `write()` into temp dirs + the slow `dart test` pair-compile
  proof) and `bug_1443_void_contract_seam_test.dart` (the sibling void fix's
  test naming/conventions).

## Architecture

```
 declared contract: sync(SyncRequest, SyncOptions) -> void
        │
        ▼
 UnitContractShape.ofResolved ──▶ returnType='void', scalarOutcome=false
        │
        ├──▶ SubjectWriter: void subject_u3(Object?, Object?) => throw  (UNCHANGED)
        │
        └──▶ BehaviorTestWriter._declaredAssertion
                 │  capture = _captureInvocation(b, target, shape)
                 ▼
        NEW branch (declaredReturn == 'void'):
              Object? result;
              try {
                subject.subject_u3(_arg0(), _arg1());
                result = null;
              } on UnimplementedError catch (error) {
                result = error;
              }
                 │
                 ▼   + vacuousGuardComment (marker) + bare guard  (UNCHANGED)
        expect(result, isNot(isA<UnimplementedError>()));
```

Single new branch in `_captureInvocation`, selected by
`shape != null && !acceptance && shape.declaredReturn.trim() == 'void'`.
The IIFE stays the default for every other shape; the acceptance branch is
unreachable from the void path (acceptance rows never carry a shape).

## Phases

### Phase 1: red tests (test-first)

- New `test/plugins/tdd/services/bug_1538_void_guard_compile_test.dart`:
  A1 (void scalar-param → statement capture), A2 (void entity-params →
  helpers compose), A3 (marker + detector classification = hand-step seam),
  B1/B2 (non-void scalar/entity unchanged — characterization guards),
  C1 (slow pair-compile proof under `dart test`).
- Run → record RED evidence in `tdd/red-1538.log` (A1/A2/A3/C1 fail; B1/B2
  pass as guards).

### Phase 2: green (single-point fix)

- `_captureInvocation` only: insert the void branch above the
  acceptance/default selection; return the statement-based capture. No other
  file in `lib/` changes.

### Phase 3: verification (non-behavioural)

- Re-run the new file → green (`tdd/green-1538.log`).
- Regression: `dart test` the writer/subject test family
  (`behavior_test_writer*_test.dart`, `bug_1512_*`, `bug_1443_*`,
  `subject_writer_test.dart`, `unit_contract_shape_1489_test.dart`,
  `issue_1308_*`).
- `dart analyze` changed files: no new issues vs baseline.
- Mutation evidence: revert the void branch → A1/A2/A3/C1 fail again
  (mutant killed); restore → green. Recorded in `tdd/verification.md`.
- `dart format .` → zero diffs on changed files.
