# Bug Issue: [zfa tdd run] cannot bootstrap from existing evidence (run-state.json starts all pending even when all done)

- **Slug**: issue-682-tdd-run-bootstrap
- **Fetched**: 2026-09-01
- **Issue**: 682
- **URL**: https://github.com/arrrrny/zuraffa/issues/682
- **State**: open
- **Severity**: medium
- **Author**: arrrrny (Ahmet TOK)
- **Labels**: bug

## Body

`zfa tdd run` cannot bootstrap from an existing TDD project where all behaviors have already been proven (red+green evidence exists in `tdd/cycle-log.md`, and a `tdd/verification.md` confirms the full suite is green with PASS verdict). The `run-state.json` has all 26 behaviors as `pending`, so `zfa tdd run` attempts to regenerate and re-verify every behavior — including those already certified DONE — instead of skipping them.

This makes `zfa tdd run` useless for brownfield projects that have complete TDD evidence but no `run-state.json`.

## Steps to Reproduce

1. A package has a complete TDD setup: `specs/<feature>/tdd/test-list.md` with all behaviors marked `DONE`, `tdd/cycle-log.md` with red+green evidence for each, and `tdd/verification.md` with PASS verdict
2. Run `zfa tdd run <feature>`
3. Error: the tool generates new test files in `test/tdd/<id>_test.dart`, runs `verify-red` on them, fails because the stub subject throws `UnimplementedError`
4. `zfa tdd run` stops at `U1:make` with a runner-error

## Expected Behavior

`zfa tdd run` should reconcile `run-state.json` with the existing evidence:
- Behaviors with red AND green evidence in `cycle-log.md` → `done`
- Behaviors with only green evidence → `green`
- Behaviors with only red evidence → `red`
- Behaviors with no evidence → `pending`

The `run-state.json` reconciliation logic exists (`_reconcile` in `run_command.dart`) but it only applies when loading a **pre-existing** `run-state.json` file. If the file doesn't exist yet (fresh project), it starts from `RunState.empty()` with all `pending` states.

## Root Cause

**File**: `lib/src/plugins/tdd/commands/run_command.dart`

In `_reconcile()` (lines 411–443):
```dart
RunState _reconcile(
  RunState state,    // loaded ?? RunState.empty(feature)
  List<BehaviorRow> rows,
  Set<String> red,
  Set<String> green,
) {
  final states = Map<String, BehaviorState>.from(state.behaviorStates);
  for (final row in rows) {
    final claimed = states[row.id] ?? BehaviorState.pending;
    var effective = claimed;
    if (claimed == BehaviorState.done) {
      // Evidence check demotes DONE to evidence-backed state
    }
    states[row.id] = effective;
  }
  ...
}
```

The reconciliation only demotes `done` claims that lack evidence. It does NOT promote `pending` behaviors to `done` based on existing evidence. A brand-new `run-state.json` (from `RunState.empty()`) has all `pending` — even when red+green evidence exists for every behavior in `cycle-log.md`.

## Evidence Available for Reconciliation

For the `zuraffa_permissions` package, the following evidence exists:
- `specs/001-permission-port/tdd/verification.md` — PASS verdict, 26/26 behaviors proven, 100% mutation score
- `specs/001-permission-port/tdd/cycle-log.md` — red+green evidence for all 26 behaviors (U1–U26)
- `test/permission_test.dart` — 22 passing tests covering all 26 behaviors

The `_reconcile` logic has everything it needs to bootstrap the state — it just needs to apply the promotion logic too.

## Suggested Fix

In `run_command.dart`'s `_reconcile()` method, add promotion logic for `pending` behaviors that have full evidence:

```dart
// Promote pending → done when both red and green evidence exist
if (effective == BehaviorState.pending && hasRed && hasGreen) {
  effective = BehaviorState.done;
}
```

Or equivalently, change the initialization so that the `states` map starts empty but the promotion logic treats `pending` (the default for new behaviors) the same as a claimed `done`:

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

This way, when `loaded == null` (no `run-state.json` exists), the reconciliation will still populate the state from existing evidence instead of starting all behaviors at `pending`.

## Severity

medium — blocks `zfa tdd run` on brownfield projects with complete TDD evidence; work-around is to manually create `run-state.json` with all behaviors marked `done`

## Comments

None.
