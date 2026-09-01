# Bug Assessment: [zfa tdd run] cannot bootstrap from existing evidence (run-state.json starts all pending even when all done)

- **Slug**: tdd-run-cannot-bootstrap-from-evidence
- **Created**: 2026-09-01
- **Source**: https://github.com/arrrrny/zuraffa/issues/682
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

`zfa tdd run` cannot bootstrap from an existing TDD project where all behaviors have already been proven. The `run-state.json` starts all behaviors as `pending` (from `RunState.empty()`), so the run attempts to regenerate and re-verify every behavior — including those already certified DONE — instead of skipping them. This makes `zfa tdd run` useless for brownfield projects that have complete TDD evidence but no `run-state.json`.

## Symptom

`zfa tdd run` regenerates test files, runs `verify-red` on already-proven behaviors, fails because the stub subject throws `UnimplementedError`, and stops at `U1:make` with a runner-error — even though red+green evidence exists for every behavior in `cycle-log.md` and `verification.md` confirms PASS.

## Reproduction

1. A package has complete TDD evidence: `tdd/test-list.md` all `DONE`, `tdd/cycle-log.md` with red+green evidence, `tdd/verification.md` with PASS verdict.
2. Run `zfa tdd run <feature>`.
3. Observe regeneration of already-proven behaviors and failure at `U1:make`.

## Suspected Code Paths

- `lib/src/plugins/tdd/commands/run_command.dart:411-443` — `_reconcile()` only demotes `done` claims that lack evidence; does NOT promote `pending` → `done` based on existing evidence.
- `lib/src/plugins/tdd/commands/run_command.dart` — `RunState.empty()` initializes all behaviors to `pending`.

## Root Cause Hypothesis

The `_reconcile()` method is asymmetric: it demotes `done` → lower states when evidence is missing, but never promotes `pending` → higher states when evidence is present. When `run-state.json` doesn't exist, `RunState.empty()` seeds all behaviors as `pending`, and reconciliation leaves them `pending` even when full red+green evidence exists. Confidence: **high** — the evidence sets (`red`, `green`) are already computed and passed to `_reconcile`; the fix is adding the promotion branch.

## Proposed Remediation

**Preferred**: In `_reconcile()`, add promotion logic for `pending` behaviors that have evidence:

```dart
if (effective == BehaviorState.pending || effective == BehaviorState.done) {
  if (hasRed && hasGreen) {
    effective = BehaviorState.done;
  } else if (hasGreen) {
    effective = BehaviorState.green;
  } else if (hasRed) {
    effective = BehaviorState.red;
  } else {
    effective = BehaviorState.pending;
  }
}
```

This makes reconciliation symmetric: it both demotes unsupported `done` claims and promotes `pending` behaviors that have evidence.

**Files likely to change**:
- `lib/src/plugins/tdd/commands/run_command.dart`

**Tests to add or update**:
- `zfa tdd run` on a brownfield project with complete evidence → skips already-proven behaviors (no regeneration), exits 0.
- `zfa tdd run` on a project with partial evidence → promotes `pending` → `red`/`green`/`done` based on available evidence.
- Regression: `zfa tdd run` on a project with no evidence → all `pending`, full run proceeds as before.

## Risks & Considerations

- The evidence parsing (`cycle-log.md` red/green sets) must be robust; malformed evidence should default to `pending` (safe).
- Promotion should not override a legitimate `done` claim in an existing `run-state.json` that lacks evidence — the demotion branch handles that case.

## Open Questions

- None blocking.