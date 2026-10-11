# Fix: compose no-green-units precondition defers to phase 2 (#1551)

- **Slug**: 1551-acceptance-compose-deadlock
- **Files changed (hard constraint: compose precondition grading ONLY)**:
  - `lib/src/plugins/tdd/commands/make_command.dart` — the ONLY source
    file touched.
  - `test/plugins/tdd/make_command_test.dart` — the A10 pin re-faithed to
    the production compose transcript + the corrected #1551 deferral
    contract (it was ALREADY RED on master: the slow tier's silent
    witness to this regression).
- **Unchanged (byte-identical to master)**: `compose_command.dart`,
  `composition_targets.dart`, `composition_planner.dart`,
  `generation_planner.dart`, `run_driver_core.dart`,
  `step_runner.dart` — the compose surface, the state machine, and the
  loop semantics are untouched.

## Change 1 — the make's pipeline-failure handler consults the compose child's verdict

In the `!pipelineResult.completed` block, AFTER the bug #826 kill-class
arm and BEFORE the #1407/#737/#942 build-step arms, a new arm:

```dart
if (failed != null &&
    idx >= 0 &&
    idx < effectivePlan.steps.length &&
    _isCompositionStepArgs(effectivePlan.steps[idx].args) &&
    _composeOutputReportsNoGreenUnits(failed.output)) {
  // ... names the deferral (+ `--> fix:` line, issue #1551) ...
  await _restoreSubjectIfMutated(subjectFile, subjectSnapshot,
      reason: 'the make stopped with an unmet compose anchor '
          'precondition (deferred, issue #1551)');
  _printSummary(behavior: record.behaviorId,
      outcome: MakeOutcome.unexpressible, feature: target.featureName);
  exitCode = 1;
  return;
}
```

Detection helpers (both static, both conservative):

- `_isCompositionStepArgs(args)` — the plan step IS the composition
  step: `args.length >= 2 && args[0] == 'tdd' && args[1] == 'compose'`
  (the spec-052 composition lane's argv, emitted by planner branch 3b
  and by `CompositionPlanner` through make's #642 fallback alike).
- `_composeOutputReportsNoGreenUnits(output)` — the child's own machine
  summary line names the precondition verdict:
  `^compose: behavior=\S+ outcome=no-green-units(?:\s|$)` (multiline).
  ANY other compose failure (a misfire, `missing-anchor-subject`,
  `target-not-acceptance`) keeps the honest `generation-error` grading.

## Why `unexpressible` is the correct token

`unexpressible` is the EXACT token the pre-#1512 zero-anchor shape
produced (planner branch 4 misfire → make `unexpressible`), and it is
the token the run driver's existing deferral arm consumes
(`run_driver_core.dart`: `step == 'make' && (outcome == 'unexpressible'
|| outcome == 'no-op')` → `[run] <id> make -> deferred (phase 2)`, the
bug #625/#826 contract). The deferral is phase-1-only: phase 2a re-drives
the deferred make with `deferralAllowed: false`, so a STILL-unmet
precondition at phase 2 honest-stops exactly as before (no loop change).

## What the fix deliberately does NOT do

- The compose command still exits 1 with `outcome=no-green-units` for
  direct callers (the surface is unchanged — pinned by bug-1551 pin 4
  and compose_command_test A6).
- No lane reordering in the driver (issue option 2 rejected — loop
  semantics are a hard constraint).
- No stub-anchor weakening for non-bug features (issue option 3
  rejected; the #1162 bug-feature stub lane already covers the
  sanctioned case).
- No change to `MakeOutcome`'s vocabulary, the summary-line contract,
  exit codes, or the green-evidence rules.

## Verification summary (fresh from real runs — full record in `tdd/verification.md`)

- RED (pristine master 4d1dafc, real `zfa tdd run` on a fresh fixture):
  `A1 make -> generation-error` → `result=stopped ... stopped_at=A1:make`.
- GREEN (this branch, same fixture shape, real `zfa tdd run`):
  `A1 make -> unexpressible` → `deferred (phase 2)` → U1 green →
  `A1 make -> green (phase 2)` (composed against the green anchor) →
  `result=complete pending=0 red=0 green=0 done=2`, exit 0.
- New suite `test/plugins/tdd/commands/bug_1551_no_green_units_defers_test.dart`:
  4/4 pass; `dart analyze`: no issues; A10 repaired; no new failures in
  the chunked suite (4 make-suite failures are pre-existing on master,
  proven by stash).
