# Bug Assessment: `tdd make` hard-stops with generation-error on behaviors the planner already declared hand-step

- **Slug**: 1568-tdd-make-hand-step-first-class
- **Created**: 2026-09-14
- **Source**: https://github.com/arrrrny/zuraffa/issues/1568
- **Verdict**: valid
- **Severity**: high

## Report

Issue #1568 (arrrrny/zuraffa): the planner announces hand-step behaviors
upfront (SPEC 1489 SC-4's `Seam cost: 10 of 14 unit behaviors will hand-step
because return is an entity.`), but `zfa tdd make` treats the same condition
as `generation-error` and stops the entire run. A feature with any hand-step
behavior can never drive its mechanical behaviors — the run stops at the first
hand-step, making remaining units/contracts unreachable; resume re-drives
everything up to the same wall (#1544's blocked-contract sibling). Discovered
during the zxscan (barcode-scan host) dogfood, fresh project.

## Symptom (verified against the code on this branch)

`lib/src/plugins/tdd/commands/make_command.dart` — the post-generation red
stop (the arm after `_argPlaceholderDiagnosis`, ~line 2013-2026) grades the
still-red target test as a generation defect:

```dart
// Issue #1036: same failed-make contract as the step-failure path ...
await _restoreSubjectIfMutated(
  subjectFile, subjectSnapshot,
  reason: 'the make stopped with a generation-error',
);
_printSummary(
  behavior: record.behaviorId,
  outcome: MakeOutcome.generationError,   // ← the misclassification
  feature: target.featureName,
);
exitCode = 1;
```

`lib/src/plugins/tdd/commands/run_driver_core.dart` — the generic step-failure
stop (~line 2419-2440) turns that outcome into a run-terminal stop
(`result=stopped stopped_at=<id>:make`, exit 1): every behavior after the
first hand-step is unreachable, and each resume re-enters at the SAME
behavior's make.

Both registry sub-shapes of an entity-return contract subject land there:

1. **Entity on disk** (SPEC 1489 verbatim rendering): plan = `build` only (the
   #1565 func skip — func would refuse the entity-typed signature); the
   paired test asserts `isA<ScanSession>()`; the subject still throws → red →
   `generation-error`.
2. **Entity missing** (`Object?` degradation): `tdd func` rewrites the stub
   but `_declaredStubBody` keeps the honest red for non-scalar returns
   (`throw UnimplementedError('implement per declared signature: ...')`,
   #920/#1259) → red → `generation-error`.

The planner's own forecast
(`UnitContractShape.countEntityReturnSeamsResolved` → `!shape.scalarOutcome`,
surfacd via `entityReturnSeamCostLine`) had ALREADY classified these behaviors
as hand-steps before the run started — planner and driver disagree about the
same behavior.

## Consequences (from the issue)

1. A feature with hand-step behaviors can never drive its mechanical
   behaviors — the run stops at the first hand-step.
2. The operator gets `generation-error` for a condition the tool itself
   classified as expected work.
3. Resume re-drives everything up to the same wall.

## Fix direction

Classification + propagation only (the issue's hard constraint): a new
non-fatal `MakeOutcome.handStep` (`outcome=hand-step`) graded at make's
post-generation red stop when the behavior's declared contract return is
entity-shaped (the planner's own seam class, stable against mid-run entity
creation via the registry-independent `isRenderableScalarType` check); the
run driver parks the behavior (PENDING + honest red, the #1544 park-and-
continue shape), persists the id in `tdd/run-state.json` (`hand_steps`) so
resume does not re-drive it, and reports `hand_steps=N` + the ids at run end.
The planner, the entity pipeline, and the analyze gate are untouched.
