# Verification — spec 1540 (protect git-tracked `.g.dart` placeholders)

Date: 2026-09-13 · Dart SDK 3.13.3 · branch
`feat/1540-protect-git-tracked-g.dart-from-build` · base `master` @ 46fe766e

## 1. Red → Green

**Red** (recorded in `tdd/red-run.md`, commit `abab6a33`): guard shipped as a
compiling no-op stub; 13 fast-tier + 2 slow-tier tests failed on BEHAVIOR
assertions — including the exact issue-#1540 dead-end reproduced by A7's
pre-fix transcript (`pass build exit 0`, placeholder missing, no refusal,
`outcome=refactored`, exit 0).

**Green** (post-implementation, same suites):

```
dart test test/core/generation/ test/commands/build_command_tracked_outputs_test.dart
  → 00:01 +28: All tests passed!

dart test --preset=all test/plugins/tdd/bug_1540_refactor_tracked_restore_test.dart
  → 00:16 +2: All tests passed!          (A6 restoration + A7 refusal)
```

## 2. Scenario matrix (spec success criteria)

| SC | Evidence | Result |
| --- | --- | --- |
| SC-1 (restore byte-identical + report) | U5/A1, U8, A6 (fixture e2e: file byte-identical, `[1540] restored` in evidence + stdout) | PASS |
| SC-2 (refusal names `git checkout --`) | U9/A2 (build helper returns false + remedy), U6 (parent-dir anomaly), A7 (refactor e2e: exit ≠ 0, remedy printed) | PASS |
| SC-3 (non-git silent no-op) | U3, A3, A5c (gate message unchanged) | PASS |
| SC-4 (regeneration untouched) | A4 (regenerated file never flagged/rewritten) | PASS |
| SC-5 (gate remedy tracked vs untracked) | A5a (`git checkout --` present) / A5b (absent, message unchanged) | PASS |
| SC-6 (refactor build pass restores + records + exit 0) | A6 | PASS |
| SC-7 (refactor refusal: stop on build + remedy + exit ≠ 0) | A7 | PASS |
| SC-8 (docs page with both builder keys) | A8 (`json_serializable`, `source_gen:combining_builder`, `generate_for`, `exclude`, `engine_event` asserted) | PASS |
| SC-9 (suite + analyze + format gates) | see §3 | PASS |

## 3. Full-suite / analyze / format gates

- `dart analyze` on every changed file (`lib/src/core/generation/`,
  `lib/src/commands/build_command.dart`,
  `lib/src/plugins/tdd/services/refactor_passes.dart`,
  `lib/src/plugins/tdd/commands/refactor_command.dart`, all three new test
  files): **No issues found!**
- `dart format --output=none --set-exit-if-changed lib test`:
  **Formatted 2595 files (0 changed)** — CI's format gate passes.
- Full fast suite via `tools/run_tests_chunked.sh` (the repo-prescribed
  disk-safe runner; 104 chunks, kernel caches cleared per chunk):
  **no failing test in the entire log** (zero `+N -M` summaries, zero
  `Some tests failed`). The runner's aggregate exit was non-zero without any
  failing-test output; re-running suspect chunks individually exits 0
  (`test/zap` → `+76: All tests passed!` exit 0; `test/agent` →
  `+240: All tests passed!` exit 0; `test/commands test/core/generation` →
  `+395: All tests passed!` exit 0). Concluded a sandbox exit-code artifact,
  not a test failure — stated here rather than hidden.
- Targeted re-runs of the suites adjacent to the touched code:
  `build_command_unit_test.dart`, `build_yaml_guard_test.dart`,
  `bug_1303_build_retry_skip_test.dart`, `build_command_slang_stage_test.dart`
  → `+15: All tests passed!`;
  `refactor_command_test.dart` + `bug_1333` + `bug_922` + `bug_1311`
  → 35 passed, 1 failed (**pre-existing**): the #922 end-to-end
  "baseline-red suite reaches done" failure reproduces identically on
  pristine `master` (46fe766e) in this environment — a kernel-race-sensitive
  e2e (the #1333 infra class), **not introduced by this branch**.

## 4. Cross-artifact consistency (tasks.md T012)

- spec.md FR-1..FR-9 ↔ plan.md decisions D1–D6 ↔ tasks.md T001–T014 ↔
  test-list.md A1–A9/U1–U9: each FR traces to ≥1 task + ≥1 test row; each SC
  to an A-row; no orphan tasks. Red-state stub (T001) superseded by the
  implementation commits — documented here.
- Signature constraint honored: `verifyDeclaredPartsOrFail` stayed `bool`
  (sync); the git check is `Process.runSync` on the failing path only (D5).
- Hard constraint honored: no build_runner/json_serializable behavior
  changed — only `zfa`-side snapshot/restore/refuse logic plus docs.

## 5. Files delivered

```
lib/src/core/generation/tracked_generated_output_guard.dart   NEW  (guard service)
lib/src/commands/build_command.dart                           guard wiring + gate remedy
lib/src/plugins/tdd/services/refactor_passes.dart             build-pass restore-or-refuse
lib/src/plugins/tdd/commands/refactor_command.dart            refusal surfacing
docs/hand-authored-g-dart-placeholders.md                     NEW  (pattern doc)
test/core/generation/tracked_generated_output_guard_test.dart NEW  (fast)
test/commands/build_command_tracked_outputs_test.dart         NEW  (fast)
test/plugins/tdd/bug_1540_refactor_tracked_restore_test.dart  NEW  (slow)
specs/1540-protect-git-tracked-g-dart-from-build/…            spec artifacts
```
