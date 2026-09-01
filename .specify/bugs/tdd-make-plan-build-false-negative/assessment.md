# Bug Assessment: fix(tdd): make plan includes func scaffold that races with pre-existing red tests — generation-error instead of skipped

- **Slug**: tdd-make-plan-build-false-negative
- **Created**: 2026-09-02
- **Source**: https://github.com/arrrrny/zuraffa/issues/737
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

`zfa tdd make` plans a 2-step generation for a unit behavior: `[zfa tdd func <id>, zfa build]`. When the suite has pre-existing red tests (e.g., other U* behaviors still red), the suite-guard's "1 failed" reading causes make to fail with `generation-error` even though the func scaffold succeeded. Direct calls to `zfa tdd func` and the subsequent `zfa tdd make` both succeed; only the run driver's invocation of the plan fails.

Issue URL: https://github.com/arrrrny/zuraffa/issues/737

## Symptom

The make plan's `build` step fails because the full `dart test` suite exits non-zero (pre-existing red tests in U4+ with `UnimplementedError` stubs), and the pipeline runner treats that non-zero exit as a plan failure — reporting `generation-error` even though the func scaffold itself succeeded and the current behavior's test passes.

## Reproduction

1. State: U1-U2 green, U3 stub fresh, U4 stub also fresh.
2. Run `zfa tdd run`.
3. Observe:
   ```
   [run] U3 gen -> ok
   [run] U3 verify-red -> certified
   [run] U3 make -> generation-error
   zfa tdd make: generation step failed at index 0 (scaffold the render function for behavior U3 from its description):
      command: ... zfa tdd func U3
      exit: 1
   ```
   But the SAME `zfa tdd func U3` runs successfully from the command line.

## Suspected Code Paths

- `lib/src/plugins/tdd/services/generation_planner.dart:8-20` — **confirmed**. Unit-kind behaviors plan as `[zfa tdd func <id>, zfa build]` (lines 11-14: "plan is `zfa tdd func <id>` ... then `zfa build`"). Every expressible plan terminates in a `build` step (line 41-43).
- `lib/src/plugins/tdd/services/pipeline_runner.dart:93-136` — **confirmed**. `runPlan` executes each step via `Process.run` and breaks on `result.exitCode != 0` (lines 113-116), setting `firstFailure = i`. Any non-zero exit from `zfa build` is treated as a plan failure.
- `lib/src/commands/build_command.dart` — `zfa build` runs build_runner + `dart analyze` (lines 157-212). The build command itself does not run `dart test`, but the suite guard / make command's post-generation re-run does (see below).
- `lib/src/plugins/tdd/commands/make_command.dart:247-273` — **confirmed**. Before generation, make runs a full-suite baseline (`runner.runSuite(suiteTemplate: …)`, line 248) and refuses if it "did not produce a usable snapshot" (lines 259-273). The baseline can fail to parse when the suite has unimplemented stubs.
- `lib/src/plugins/tdd/commands/make_command.dart:405-443` — **confirmed**. After generation, make re-runs the full suite (`guardRun`, line 411) and computes a `GuardDiff` (line 414-417). `diff.hasNewFailures` (line 435) triggers a regression report. The guard compares baseline vs. guard failure sets (suite_guard.dart:168-171), but the baseline itself may already contain pre-existing failures from U4+.
- `lib/src/plugins/tdd/services/suite_guard.dart:165-177` — **confirmed**. `diff()` computes `newFailures = guard.failedTests.where((id) => !baselineSet.contains(id))` — pre-existing failures are correctly excluded from `newFailures`, but the *baseline snapshot itself* may be unparseable or the *build step* may exit non-zero for reasons unrelated to the current behavior.

## Root Cause Hypothesis

The make plan's `build` step is a full-project operation. When the project has pre-existing red tests (U4+ stubs throwing `UnimplementedError`), the build step's exit code reflects the whole project, not the current behavior. The pipeline runner (pipeline_runner.dart:113) treats any non-zero exit as a plan failure, so the plan reports `generation-error` even though the func scaffold succeeded and the current behavior's test passes.

This is the same underlying pattern as #731 (full-suite vs per-behavior), but in a different code path: the **plan-step runner** (`pipeline_runner.dart`) vs. the **direct make runner** (`make_command.dart`). The issue correctly notes the fix location is different. High confidence: the plan shape and pipeline runner behavior are verified directly in source.

## Proposed Remediation

**Preferred**: Make the pipeline runner's failure grading per-step-context-aware for the `build` step, OR make the make command's post-generation check per-behavior:

- In `make_command.dart`, after the pipeline completes, re-run **the current behavior's test** (e.g. `dart test test/tdd/u3_test.dart`) rather than the full suite to certify green. If the current behavior's test passes and no NEW failures appear in the full suite, return `outcome=skipped` (per #694) or `outcome=green` and continue.
- In `pipeline_runner.dart`, treat a `zfa build` step's non-zero exit as a soft failure when the exit is caused by pre-existing red tests unrelated to the current behavior — but this is harder to detect at the pipeline layer, so the per-behavior check in `make_command.dart` is the cleaner fix.

**Alternatives**:
- Add a `--test <path>` scope to `zfa build` so the build step only runs the current behavior's test. Trade-off: changes the build command's contract; build is meant to be project-wide.
- In the pipeline runner, skip the `build` step's exit-code check when the step is `zfa build` and the make command has already verified the current behavior's test. Trade-off: couples the pipeline runner to make-command context.

**Files likely to change**:
- `lib/src/plugins/tdd/commands/make_command.dart` (post-generation certification: per-behavior test instead of full suite)
- `lib/src/plugins/tdd/services/pipeline_runner.dart` (optional: soft-fail handling for build step)
- `test/plugins/tdd/make_command_test.dart` (per-behavior certification scenario)

**Tests to add or update**:
- U3:make returns `outcome=skipped` (or `green`) when U3's own test passes, even though U4+ are red.
- The run continues through all U* behaviors after a per-behavior make certification.
- Direct `zfa tdd make` on a clean suite still certifies via the full suite guard (regression).

## Risks & Considerations

- Per-behavior certification weakens the "whole suite is green" guarantee for the make step; the full-suite guard should still run as a final gate per feature, not per behavior.
- The `build` step's exit code is also used by build_runner's own guards (verifyOutputsOrFail, verifyDeclaredPartsOrFail); those must not be conflated with test failures.
- This bug is a separate filing from #731 per the issue; the fix must not regress #731's suite-guard behavior for clean suites.

## Open Questions

- [NEEDS CLARIFICATION: Should the make command's post-generation check be per-behavior test only, or per-behavior test + full-suite diff (excluding pre-existing failures)?]
- [NEEDS CLARIFICATION: Does the `build` step in the pipeline need a separate exit-code policy, or is it sufficient to change the post-generation certification in make_command.dart?]