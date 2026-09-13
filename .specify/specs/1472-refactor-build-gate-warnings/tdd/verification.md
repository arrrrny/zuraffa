# Verification — 1472-refactor-build-gate-warnings

- **Date**: 2026-09-13
- **Branch**: feat/1472-refactor-build-gate-warnings
- **Base head**: `5e1159e08c7c6539a161d13f62e66239b32030d7` (reviewed revision);
  the results below are the post-review-fix re-run on top of it.
- **Scope check (SC-7)**: changed production files are
  `lib/src/plugins/tdd/services/refactor_passes.dart`,
  `lib/src/plugins/tdd/services/tdd_profile_keys.dart` (new),
  `lib/src/plugins/tdd/commands/refactor_command.dart`,
  `lib/src/plugins/tdd/commands/make_command.dart`,
  `lib/src/cli/writers/tdd/tdd_profile_writer.dart`, and
  `lib/src/commands/build_command.dart`. The `build_command.dart` delta is
  additive only (the shared #1035 gate verdict parser + refusal logger hoisted
  for the review-findings fix); `verifyAnalyzeOrFail` and
  `AnalyzerIssueCounts.blocksGate` keep their existing behavior, proven by
  `build_command_unit_test.dart` 48/48. The pass registry order
  (build → format → fix), the refactor pass scope, the hand-delta seam
  (#1308), and the `zfa tdd run` state machine are untouched.

## Success criteria

| id | criterion | verdict | evidence |
|----|-----------|---------|----------|
| SC-1 | errors-only gate: warnings-only refusal does not stop the registry | PASS | U-1472-1 green (invocations `[build, format, fix]`, `completed`); A-1472-1 green (`outcome=refactored`, `applied>=1`, exit 0) |
| SC-2 | errors / non-gate classes / spawn failure / timeout keep the misfire-stop | PASS | U-1472-4, U-1472-5, U-1472-6, U-1472-8, U-1472-9, U-1472-10 green; A-1472-2 green (`pass "build" failed — misfire-stop.` + `outcome=runner-error`, exit != 0) |
| SC-3 | accurate counts logged; never "did not compile cleanly" for warnings-only; honest action recording | PASS | U-1472-2 (true exit 1 + raw output kept), U-1472-3 (`0 error(s), 2 warning(s)` + `non-blocking` on the transcript), U-1472-18 (capped sample + `... N more warning(s)`) |
| SC-4 | message/parser disagreement keeps the honest stop | PASS | U-1472-6 green (0-error message over raw `error -` lines → misfire-stop) |
| SC-5 | `analyze-gate: warnings-blocking` profile opt-in restores the legacy refusal | PASS | U-1472-7 green (service flag); A-1472-3 green (profile key read by the command end-to-end); the key is now emitted by the profile writer and documented |
| SC-6 | build pass pinned to the driving zfa version; silence rules on unprovable input | PASS | U-1472-11 green (stale v0.0.9 PATH zfa bypassed for the driving entrypoint, pin logged); U-1472-12/13 (equal / unprovable keeps the #717 candidate); U-1472-14/15 (the pin proves BOTH sides of the swap); U-1472-16 (identical entrypoint is a no-op); U-1472-17 (StateError fails open) |
| SC-7 | no regression: standalone `zfa build` gate, registry order, #1407 make grading, state machine | PASS | refactor_passes_test 11/11, subprocess_timeout 22/22, refactor_action 10/10, tdd_profile_writer 13/13 (one invocation, +56); build_command_unit_test 48/48; bug_1407 8/8; refactor_command_test + bug_1333 + bug_1311 27/27 |

## Commands and results

1. Analyze (every changed file, the spec's §5 gate):

   ```
   dart analyze lib/src/plugins/tdd/commands/refactor_command.dart \
     lib/src/plugins/tdd/commands/make_command.dart \
     lib/src/plugins/tdd/services/refactor_passes.dart \
     lib/src/plugins/tdd/services/tdd_profile_keys.dart \
     lib/src/cli/writers/tdd/tdd_profile_writer.dart \
     lib/src/commands/build_command.dart \
     test/plugins/tdd/bug_1472_refactor_gate_acceptance_test.dart \
     test/plugins/tdd/bug_1472_refactor_gate_errors_only_test.dart \
     test/plugins/tdd/helpers/refactor_pass_fakes.dart \
     test/cli/writers/tdd/tdd_profile_writer_test.dart
   → No issues found!
   ```

2. New suites:

   ```
   dart test test/plugins/tdd/bug_1472_refactor_gate_errors_only_test.dart
   → 00:00 +18: All tests passed!
   dart test --preset=integration test/plugins/tdd/bug_1472_refactor_gate_acceptance_test.dart
   → 01:08 +3: All tests passed!
   ```

3. Regression suites (pinned contracts around the change). Note the tier the
   invocation actually selects — the fast tier excludes `slow`-tagged files,
   so `build_command_unit_test.dart` needs its own `--preset=all` run:

   ```
   dart test test/plugins/tdd/services/refactor_passes_test.dart \
     test/plugins/tdd/services/subprocess_timeout_test.dart \
     test/plugins/tdd/models/refactor_action_test.dart \
     test/cli/writers/tdd/tdd_profile_writer_test.dart
   → 01:06 +56: All tests passed!
   dart test --preset=all test/plugins/tdd/bug_1407_make_gate_errors_only_test.dart
   → 03:06 +8: All tests passed!
   dart test --preset=all test/plugins/tdd/refactor_command_test.dart \
     test/plugins/tdd/bug_1333_refactor_reproof_retry_test.dart \
     test/plugins/tdd/bug_1311_refactor_receipt_refresh_test.dart
   → 05:30 +27: All tests passed!
   dart test --preset=all test/commands/build_command_unit_test.dart
   → 00:15 +48: All tests passed!
   ```

4. Format: `dart format` applied to all changed Dart files; re-checked with

   ```
   dart format --set-exit-if-changed <the ten changed Dart files>
   → Formatted 10 files (0 changed) in 0.21 seconds.  (exit 0)
   ```

5. Every suite above was re-run after formatting — the counts recorded here
   are the post-format numbers.

## Review follow-up (#1572)

The automated review of `5e1159e0` raised eight inline findings plus three
nitpicks; all are resolved. Each inline finding was applied against the
current head code (none were stale).

| finding | resolution |
|---|---|
| `refactor_passes.dart:392` — the #1035 gate contract triplicated, the #1407 profile reader duplicated | The gate verdict parser (`analyzeGateWarningsOnlyRefusal`) and refusal logger (`logAnalyzeGateRefusal`) now live on `BuildCommand`; a new `TddProfileKeys` service is the single profile reader. `refactor_passes.dart`, `make_command.dart` and `refactor_command.dart` call them instead of keeping local copies (~260 lines removed). |
| `refactor_passes.dart:598` — the pin proves the candidate and then returns an unproven replacement | `_pinToDrivingVersion` now probes the resolved `driving` entrypoint as well and returns it only when it provably reports the driving version; otherwise it keeps the #717 candidate. U-1472-14/15 pin both silence directions. |
| `bug_1472_refactor_gate_acceptance_test.dart:80` — A-1472-1 under-asserts | The fixture now seeds a real unused import and the test asserts `pass: format`/`pass: fix` reach the transcript plus `outcome=refactored applied=[1-9]`, so a pair of no-op passes can no longer satisfy it. |
| `refactor_passes.dart:440` — uncovered branches, no seam | A `ZfaEntrypointResolver` typedef + `resolveDrivingEntrypoint` seam added to `zfaBuildCommand`; U-1472-14..17 cover the failure modes and U-1472-18 the >10-warning cap with its remainder line. |
| `tdd/test-list.md:26` — outer-loop rows point at the wrong file; A-1472-3 missing | A-1472-1/A-1472-2 rows now name `bug_1472_refactor_gate_acceptance_test.dart`; the A-1472-3 (SC-5) row and the U-1472-14..18 rows were added. |
| `tdd/verification.md:52` — the recorded command cannot have produced `+43` | The recorded invocation now lists the three suites it really covers (+56 with the profile-writer suite included) and `build_command_unit_test.dart` is recorded as its own `--preset=all` run (+48). |
| `tasks.md:9` — T001/T005 name the wrong IDs and T001..T008 unchecked | T001 → U-1472-1..10 + U-1472-18, T005 → U-1472-11..17 (the ranges the review suggested plus the behaviors added for finding 4); all boxes are now checked because every listed suite is green. |
| `refactor_command.dart:1059` — the opt-in key is undiscoverable | `tdd_profile_writer.dart` now emits `analyze-gate: errors-only` with a comment naming the `warnings-blocking` opt-in (asserted by the profile-writer suite), and `docs/zfa-tdd-guide.md` documents the key and its values. |

Nitpicks: (a) `CHANGELOG.md` now states the pin is conditional and the log
line reads "resolved build zfa" instead of "system zfa on PATH";
(b) the new suite constructs every `RefactorPasses` with an injected
`passSpecs`, so no fast-tier behavior spawns a real `zfa --version` or reads
ambient PATH; (c) `FakeProcessExecutor`, `ProgrammedOutcome` and
`capturePrint` moved to `test/plugins/tdd/helpers/refactor_pass_fakes.dart`.

One nitpick is scoped deliberately: the reviewer noted the same ambient-PATH
construction in the pre-existing `refactor_passes_test.dart` and called it
"inherited rather than new". That file is outside this PR's diff (and its
registrations intentionally exercise the real `defaultPassSpecs` chain), so it
was left unchanged rather than refactored as part of a review-fix commit.

The review body's remark that `bug_1407_make_gate_errors_only_test.dart`
declares nine tests is stale: the suite reports `+8`, and the ninth `test(`
occurrence in the file sits inside the string literal returned by the
`_widgetTargetTest()` fixture helper, not in a suite declaration.

## Red evidence

Recorded per behavior in `tdd/cycle-log.md`: U-1472-1, U-1472-3, U-1472-11
failed for the right reason pre-fix (registry misfire-stopped on the
warnings-only refusal; no accurate log; no pin), while the guard behaviors
were already green (they pin the behavior that must not change) — the correct
red shape for a bug fix. The behaviors added for the review findings
(U-1472-14..18) were written after the fix they pin; their red is recorded as
"not applicable — post-fix pinning test" in the cycle log rather than
fabricated.
