# 1538-void-returning-contract-compile-fix

- **Spec ID**: 1538-void-returning-contract-compile-fix
- **Created**: 2026-09-13
- **Source**: GitHub issue #1538 (SPEC 1538 — VOID-RETURNING CONTRACT ROWS EMIT NON-COMPILING GUARD TEST)
- **Type**: bug (P1 — generated pair does not compile; the TDD cycle dead-ends)
- **Branch**: feat/1538-void-returning-contract-compile-fix

## Problem

A UNIT-lane behavior whose declared Layer Contract returns `void` produces a
generated test pair that does not compile. `UnitContractShape.of` treats
`void` as a renderable scalar (`void` ∈ `_renderableScalars`), so the paired
subject stub renders the declared return verbatim —
`void subject_u3(...) => throw UnimplementedError(...)` — while
`BehaviorTestWriter._captureInvocation` unconditionally wraps the invocation
in the IIFE capture:

```dart
final result = (() {
  try {
    return subject.subject_u3(_arg0(), _arg1());   // void!
  } on UnimplementedError catch (error) {
    return error;
  }
})();
```

`return`ing a void expression from an `Object? Function()` closure is a
compile error (`use_of_void_result`, plus
`return_of_invalid_type_from_closure` at the closure boundary). The behavior
therefore dead-ends at `verify-red -> compile-error` — it never reaches the
designed vacuous-guard → hand-step transition, even though
`vacuous_guard.dart` explicitly documents the traced "entity/void-returning
path" as a marker-carrying hand-delta seam (issue #1259's two-class dispatch,
issue #1308). The #1443 fix (render the CONTRACT lane's seam as `Object?`)
and the #1512 fix (the ACCEPTANCE lane's void-safe capture) cover the other
two lanes; the UNIT lane's guard template is the remaining gap.

## Goal

For void-returning declared contracts, gen emits a COMPILING guard test: the
invocation stands alone (its void result is never used), completion is
recorded by assigning `null` to a nullable capture variable, and a thrown
`UnimplementedError` is captured the same way — so the honest red survives,
`verify-red` grades an assertion (never a compile error), and the existing
vacuous-guard marker machinery routes the behavior to the designed hand-step
transition.

## Success criteria (measurable)

- **SC-1**: For a void-returning contract, the emitted test uses the
  statement-based void-safe capture and never `return`s the subject's value:
  `Object? result;` … `try { subject.<target>(<args>); result = null; } on
  UnimplementedError catch (error) { result = error; }` followed by
  `expect(result, isNot(isA<UnimplementedError>()));`. Placeholder `_argN()`
  helpers for non-scalar declared params compose with this form (helpers are
  still declared before the capture; scalar params still render literals).
- **SC-2**: Non-void contract test generation is byte-for-byte unchanged:
  scalar returns keep `final result = (() {` + `return subject.…` +
  `expect(result, isA<T>())`; entity returns keep the IIFE + the
  `vacuousGuardComment`/marker guard; the acceptance lane keeps its
  parameterless void-safe capture (#1512); the contract lane (#1007/#1443)
  is untouched.
- **SC-3**: Void contract tests reach the vacuous-guard → hand-step
  transition, not compile-error: the emitted test carries
  [vacuousGuardMarker] (via `vacuousGuardComment`) and its only expectation
  is the guard, so `contentIsVacuousGreen` +
  `contentCarriesVacuousGuardMarker` classify it as the traced hand-delta
  seam (`stopped_at=<id>:hand`) exactly like entity-return contracts.
- **SC-4**: The emitted void pair COMPILES and fails through an assertion:
  running the generated test + `void` subject stub under `dart test` yields
  an assertion failure (Expected/Actual), never `compile-time error`.
- **SC-5**: `dart analyze` over the changed files reports no new issues vs
  the repo baseline (0 errors / 0 warnings / 112 pre-existing infos).

## Hard constraints

- Fix ONLY the guard template generation for void returns — the
  `_captureInvocation` emission inside
  `lib/src/plugins/tdd/services/behavior_test_writer.dart`. Do NOT change
  the contract lane (`contract_test_writer.dart`), the parameter grammar
  (`ContractParam.parse` / `UnitContractShape` derivation), or the state
  machine (`run_driver_core.dart` dispatch, markers, receipts).
- The subject stub signature stays the declared contract verbatim
  (`void subject_u3(...)`); the test-side capture is the fix (the subject IS
  the declared surface — degrading it to `Object?` would betray the
  contract, unlike the #1443 seam which is a scaffold, not the declared
  method).
- Must not break non-void contract test generation (SC-2 is a hard gate).
- Must pass `dart analyze` with no new warnings.

## Out of scope

- `Future<void>` declared returns — they already compile through the IIFE
  (the closure returns the Future object; `void` inside the generic is not a
  void expression at the return site). Only bare `void` is broken.
- Plan-time refusal of void contracts (the spec's alternative remedy): the
  emit-compiling-guard branch is implemented instead — it keeps the declared
  contract implementable end-to-end.
- `zfa tdd func`'s dummy-fill (`func_command._declaredStubBody` already
  handles `void` with an empty body).
- Mutation of markers, receipts, journal wording, or the run driver's
  two-class stop dispatch.

## References

- #1538 (GitHub issue — this spec)
- #1259 (contract-derived subjects; vacuous-green refusal + marker)
- #1308 (the hand-step seam; two-class stop dispatch keyed on the marker)
- #1443 (CONTRACT lane: seam renders `Object?` for void — the sibling fix)
- #1512 (ACCEPTANCE lane: void-safe parameterless capture — the other sibling)
