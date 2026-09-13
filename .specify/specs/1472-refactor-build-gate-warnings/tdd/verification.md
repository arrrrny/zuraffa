# Verification — 1472-refactor-build-gate-warnings

- **Date**: 2026-09-13
- **Branch**: feat/1472-refactor-build-gate-warnings
- **Scope check (SC-7)**: changed Dart files are exactly
  `lib/src/plugins/tdd/services/refactor_passes.dart`,
  `lib/src/plugins/tdd/commands/refactor_command.dart`,
  `test/plugins/tdd/bug_1472_refactor_gate_errors_only_test.dart`,
  `test/plugins/tdd/bug_1472_refactor_gate_acceptance_test.dart`. The
  `zfa build` gate (`verifyAnalyzeOrFail`, `AnalyzerIssueCounts.blocksGate`),
  the pass registry order (build → format → fix), the refactor pass scope,
  the hand-delta seam (#1308), and the `zfa tdd run` state machine are
  untouched — `git diff -- lib/src/commands/build_command.dart` is empty and
  the state-machine files carry no changes.

## Success criteria

| id | criterion | verdict | evidence |
|----|-----------|---------|----------|
| SC-1 | errors-only gate: warnings-only refusal does not stop the registry | PASS | U-1472-1 green (invocations `[build, format, fix]`, `completed`); A-1472-1 green (outcome clean/refactored, exit 0) |
| SC-2 | errors / non-gate classes / spawn failure / timeout keep the misfire-stop | PASS | U-1472-4, U-1472-5, U-1472-6, U-1472-8, U-1472-9, U-1472-10 green; A-1472-2 green (`pass "build" failed — misfire-stop.` + `outcome=runner-error`, exit != 0) |
| SC-3 | accurate counts logged; never "did not compile cleanly" for warnings-only; honest action recording | PASS | U-1472-2 (true exit 1 + raw output kept), U-1472-3 (`0 error(s), 2 warning(s)` + `non-blocking` on the transcript) |
| SC-4 | message/parser disagreement keeps the honest stop | PASS | U-1472-6 green (0-error message over raw `error -` lines → misfire-stop) |
| SC-5 | `analyze-gate: warnings-blocking` profile opt-in restores the legacy refusal | PASS | U-1472-7 green (service flag); A-1472-3 green (profile key read by the command end-to-end) |
| SC-6 | build pass pinned to the driving zfa version; silence rules on unprovable input | PASS | U-1472-11 green (stale v0.0.9 PATH zfa bypassed for the driving entrypoint, pin logged); U-1472-12 (equal version keeps the #717 candidate); U-1472-13 (unprovable keeps the #717 candidate) |
| SC-7 | no regression: standalone `zfa build` gate, registry order, #1407 make grading, state machine | PASS | refactor_passes_test 11/11, build_command_unit_test 48/48, bug_1407 8/8, refactor_command_test + bug_1333 + bug_1311 27/27, subprocess_timeout + refactor_action green |

## Commands and results

1. Kernel sweep + analyze (changed files, the spec's §5 gate):

   ```
   rm -rf .dart_tool/test/ && rm -f $TMPDIR/dart_test.kernel.*
   dart analyze lib/src/plugins/tdd/commands/refactor_command.dart \
     lib/src/plugins/tdd/services/refactor_passes.dart \
     test/plugins/tdd/bug_1472_refactor_gate_acceptance_test.dart \
     test/plugins/tdd/bug_1472_refactor_gate_errors_only_test.dart
   → No issues found!
   ```

2. New suites:

   ```
   dart test test/plugins/tdd/bug_1472_refactor_gate_errors_only_test.dart
   → 00:00 +13: All tests passed!
   dart test --preset=integration test/plugins/tdd/bug_1472_refactor_gate_acceptance_test.dart
   → 00:24 +3: All tests passed!
   ```

3. Regression suites (pinned contracts around the change):

   ```
   dart test test/plugins/tdd/services/refactor_passes_test.dart \
     test/commands/build_command_unit_test.dart \
     test/plugins/tdd/services/subprocess_timeout_test.dart \
     test/plugins/tdd/models/refactor_action_test.dart
   → +43: All tests passed!
   dart test --preset=all test/plugins/tdd/refactor_command_test.dart \
     test/plugins/tdd/bug_1333_refactor_reproof_retry_test.dart \
     test/plugins/tdd/bug_1311_refactor_receipt_refresh_test.dart
   → +27: All tests passed!
   dart test --preset=all test/plugins/tdd/bug_1407_make_gate_errors_only_test.dart
   → +8: All tests passed!
   dart test --preset=all test/commands/build_command_unit_test.dart
   → +48: All tests passed!
   ```

4. Format: `dart format` applied to all four changed files (no-op on lib/,
   reflow on the two test files); suites re-run green after formatting.

5. Kernel sweep repeated after the suite runs (disk housekeeping).

## Red evidence

Recorded per behavior in `tdd/cycle-log.md`: U-1472-1, U-1472-3, U-1472-11
failed for the right reason pre-fix (registry misfire-stopped on the
warnings-only refusal; no accurate log; no pin), while the ten guard
behaviors were already green (they pin the behavior that must not change) —
the correct red shape for a bug fix.
