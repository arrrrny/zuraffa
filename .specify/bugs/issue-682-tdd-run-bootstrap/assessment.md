# Bug Assessment: [zfa tdd run] cannot bootstrap from existing evidence

- **Slug**: issue-682-tdd-run-bootstrap
- **Created**: 2026-09-01
- **Source**: https://github.com/arrrrny/zuraffa/issues/682
- **Verdict**: valid
- **Severity**: medium

## Report (verbatim or summarized)

`zfa tdd run` cannot bootstrap from an existing TDD project where all behaviors have already been proven (red+green evidence exists in `tdd/cycle-log.md`, and a `tdd/verification.md` confirms the full suite is green with PASS verdict). The `run-state.json` has all 26 behaviors as `pending`, so `zfa tdd run` attempts to regenerate and re-verify every behavior — including those already certified DONE — instead of skipping them.

## Symptom

When `zfa tdd run <feature>` is invoked on a brownfield project with complete TDD evidence (no pre-existing `run-state.json`), `_reconcile()` receives `RunState.empty(feature)` which has an empty `behaviorStates: {}`. Every behavior ID resolves to `BehaviorState.pending` (the `?? BehaviorState.pending` fallback at `run_command.dart:419`), so the tool skips the promotion branch entirely (it only runs when `claimed == BehaviorState.done`, line 421). The tool then attempts to regenerate and re-verify all behaviors, stops at `U1:make` with a runner-error because the stub subject throws `UnimplementedError`, and exits non-zero.

## Reproduction

1. A package has a complete TDD setup: `specs/<feature>/tdd/test-list.md` with all behaviors marked `DONE`, `tdd/cycle-log.md` with red+green evidence for each, and `tdd/verification.md` with PASS verdict.
2. Ensure there is no `tdd/run-state.json` (fresh clone, never-run project).
3. Run `zfa tdd run <feature>`.
4. Error: the tool generates test files in `test/tdd/<id>_test.dart`, runs `verify-red` on them, which fails because the stub subject throws `UnimplementedError`.
5. `zfa tdd run` stops at `U1:make` with a runner-error.

## Suspected Code Paths

- `lib/src/plugins/tdd/commands/run_command.dart:217-221` — the call site: `loaded ?? RunState.empty(feature)` means no pre-existing state means all `pending`.
- `lib/src/plugins/tdd/commands/run_command.dart:411-443` — `_reconcile()`: the promotion logic is gated on `if (claimed == BehaviorState.done)` (line 421), so `pending` behaviors are never promoted even when red+green evidence exists.
- `lib/src/plugins/tdd/models/run_state.dart:29-30` — `RunState.empty()` initializes `behaviorStates: const {}`, ensuring every `row.id` resolves to `BehaviorState.pending` via the `??` fallback.

## Root Cause Hypothesis

**Confidence: high.** The bug is confirmed by reading the source.

When `run-state.json` does not exist, `loaded` is `null` (line 169), so `_reconcile()` is called with `RunState.empty(feature)` which has `behaviorStates: {}`. In `_reconcile()`, for each behavior row:
- `claimed = states[row.id] ?? BehaviorState.pending` → always `pending` (no entries in `{}`).
- `effective = claimed` → `pending`.
- The `if (claimed == BehaviorState.done)` block at line 421 is skipped.
- `states[row.id] = BehaviorState.pending` → confirmed `pending` for every row.

The evidence sets (`red`, `green`) are correctly computed from `cycle-log.md` (via `CycleEvidence`), but the promotion branch is only entered for `claimed == BehaviorState.done`. The `pending` default is never promoted.

The existing `sc_019_legacy_dialect_migration_test.dart` passes because it provides a pre-existing `run-state.json` with all behaviors already marked `done` — it never exercises the empty-state bootstrap path.

## Proposed Remediation

**Preferred**: Extend the condition in `_reconcile()` at `run_command.dart:421` from:

```dart
if (claimed == BehaviorState.done) {
```

to:

```dart
if (claimed == BehaviorState.done || claimed == BehaviorState.pending) {
```

This makes the promotion logic apply symmetrically to both `done` (already was the case) and `pending` (the new bootstrap case). When `pending` and both red and green evidence exist, the behavior is promoted to `done`. This is a single 12-character change and carries minimal risk — it makes `_reconcile()` apply the same evidence-based promotion regardless of how the entry arrived in `behaviorStates`.

**Alternative**: Explicitly handle the null-`loaded` bootstrap case in the call site (lines 217–221) by pre-populating `RunState` from the evidence sets before calling `_reconcile()`. This is more verbose and less symmetric.

**Files likely to change**:
- `lib/src/plugins/tdd/commands/run_command.dart`

**Tests to add or update**:
- Add an integration scenario test (under `test/plugins/tdd/scenarios/`) that invokes `zfa tdd run` on a feature directory that has `cycle-log.md` with red+green evidence for all behaviors but no `run-state.json`. The test should assert that the output contains `"N already done — skipping"` and exit code 0 without spawning any step processes.
- The existing `sc_019_legacy_dialect_migration_test.dart` tests the loaded-from-`done` path; the new test covers the no-file bootstrap path.

## Risks & Considerations

- **Low risk**: The change is additive-only — existing behavior for `claimed == BehaviorState.done` is unchanged. The `pending` case was previously a no-op (always set to `pending`); the fix makes it mirror the `done` case.
- **Behavior change**: If a project has `run-state.json` with a behavior marked `done` but no evidence, it is demoted (correctly). With the fix, a project with no `run-state.json` but full evidence will have those behaviors promoted to `done` — this is the intended behavior.
- **Performance**: The `_reconcile()` method is called once per `zfa tdd run` invocation; the fix adds two additional boolean checks per behavior, which is negligible.
- **Test coverage**: The existing scenario test `sc_019` exercises the pre-existing-state path. The new test for the empty-state bootstrap path is the natural complement and closes the gap.

## Open Questions

- [RESOLVED: The fix is a single-line condition change in `_reconcile()` at line 421; no other call sites need updating.]
- [RESOLVED: The `CycleEvidence` class correctly reads red and green evidence from `cycle-log.md` for all rows; confirmed by reading `cycle_evidence.dart:22-25`.]
