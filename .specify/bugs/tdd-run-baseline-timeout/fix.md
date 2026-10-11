# Bug Fix: zfa tdd run baseline ignores --timeout; 10-min default kills the run on large repos

- **Slug**: tdd-run-baseline-timeout
- **Fixed**: 2026-09-05
- **Assessment**: ./assessment.md
- **Status**: applied
- **TDD artifacts**: ./tdd/test-list.md, ./tdd/cycle-log.md (TDD loop driven; blocked at a NEW, separate gap — see Deviations)

## Summary

The `--timeout <minutes>` override is now one uniform deadline across the whole TDD
pipeline: the run-level suite baseline receives it, spawned step children inherit it via
`--timeout`, and `zfa tdd make`'s fallback live baseline applies it. On repos whose fast
suite outlives the hardcoded 10-minute `defaultSuite`, the baseline is no longer killed
and `tdd make` no longer refuses — the loop can proceed.

## Changes

| File | Change | Notes |
|------|--------|-------|
| `lib/src/plugins/tdd/commands/run_driver_core.dart` | modified | run-level baseline `runSuite(...)` now forwards the driver's `timeout` override (was dropped → hardcoded `defaultSuite` 10 min) |
| `lib/src/plugins/tdd/services/step_runner.dart` | modified | spawned step children (`gen`/`verify-red`/`make`/`refactor`) inherit the driver deadline as `--timeout <minutes>`; omitted when the default applies (no small-repo behavior change) |
| `lib/src/plugins/tdd/commands/make_command.dart` | modified | fallback live suite baseline forwards `timeoutOverride` (was dropped → 10-min kill) |
| `test/plugins/tdd/bug_1159_baseline_timeout_test.dart` | added test | 5 behavioral tests pinning the three surfaces |

## Diff Highlights

```dart
// run_driver_core.dart — the baseline keeps the run's ONE uniform deadline
final baselineRecord = await const SingleTestRunner().runSuite(
  suiteTemplate: suiteTemplate,
  workingDirectory: projectRoot,
  timeout: timeout, // issue #1159
);

// step_runner.dart — children inherit it
if (timeout != TddTimeouts.defaultStepProcess) {
  argv.addAll(['--timeout', '${minutes.toStringAsFixed(4)}']);
}

// make_command.dart — the fallback baseline honors it
final baselineRun = await runner.runSuite(
  suiteTemplate: suiteTemplate,
  workingDirectory: cwd,
  timeout: timeoutOverride, // issue #1159
);
```

## Tests Added or Updated

- `test/plugins/tdd/bug_1159_baseline_timeout_test.dart` — step children carry `--timeout` (make + refactor) and omit it under the default; `runSuite` honors a fractional deadline (kills at 0.5 s, completes at 30 s for the same `sleep 2` suite — the exact >10-min-suite-under-override shape); `parseTddTimeoutMinutes` default shape unchanged.

## Local Verification

- `dart analyze` on the three source files + new test → No issues found.
- `dart test test/plugins/tdd/bug_1159_baseline_timeout_test.dart test/plugins/tdd/services/step_runner_test.dart test/plugins/tdd/runner_suite_test.dart` → 42 passing.
- **Live proof caveat**: the shell `zfa` on PATH is a compiled global snapshot (v6.1.0,
  built Sep 2) that predates this fix — all loop invocations launched via the bare `zfa`
  command ran the STALE binary, so early loop runs reproduced the old refusal even after
  the source fix. Live verification therefore runs the local source explicitly via
  `dart run bin/zfa.dart ...` (results in the cycle-log addendum): the standalone
  `tdd make` fallback baseline with `--timeout 45` and the driver baseline leg.

## Deviations from Assessment

1. **TDD loop could not complete — blocked by a NEW, separate gap (not #1159).**
   With the baseline fixed, the loop now reaches make and stops at
   `outcome=subject-drift`: the #1036-era skip guard compares the subject file's sha256
   against the red evidence and refuses when a developer has (per the generator's own
   test-header instruction: "Replace the subject's stub body with real implementation")
   hand-implemented a bug subject. Its two sanctioned remedies do not cover this case:
   `git checkout` reverts the implementation, and `zfa tdd verify-red` cannot re-certify
   red on a now-passing test (`classification=unexpected-green`, no evidence written —
   verified live). For bug features (no entity to `wire`, prose scenario the entity
   pipeline cannot express), hand-implementation is the only implementation path, so the
   guard makes the loop unclosable for exactly the features the bug extension targets.
   **Recommended follow-up**: re-run `/speckit-bug-assess` for a new issue — proposed
   fix: make the drift guard accept a re-certification transition for implemented
   subjects (e.g. `zfa tdd verify-red --re-certify` that records the new subject hash
   with the passing test's transcript as evidence), or fail open when the subject's
   scenario assertions genuinely execute.
2. **specs/ bridge symlink**: `zfa tdd plan|run|verify` resolve features strictly under
   `specs/`, so the bug directory (`.specify/bugs/tdd-run-baseline-timeout/`) is bridged
   via the relative symlink `specs/bug-tdd-run-baseline-timeout`. Committed as part of
   the fix so the tdd artifacts resolve for reviewers.

## Follow-ups

- New issue for the subject-drift dead end (deviation 1) — blocks bug-TDD-loop closure, not this fix.
- The bug feature's test list (9 behaviors) remains an honest record: A1 red-certified, subjects stubbed; implementation of the behaviors beyond the source fix awaits the follow-up.
- Consider a corpus/regression entry for the baseline-timeout shape (slow tier).
