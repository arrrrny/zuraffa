# Verification: `zfa replay` (spec 066-zfa-replay)

**Date**: 2026-09-03 · **Branch**: `066-zfa-replay` · **Dart**: 3.13.3 (stable)
**Method**: test-first TDD via the tdd extension — every behavior below was
written and observed RED (load-error on the not-yet-existing services) before
the implementation that turned it green. Evidence entries live in
`tdd/cycle-log.md`, appended by the real `CycleLog.append` writer (schema-1
hash chain — this log is itself replayable by the feature it certifies).

## Test-first evidence (red)

`dart test <4 new test files>` (pre-implementation):

```text
00:00 +0 -4: Some tests failed.
Failing tests:
  test/plugins/tdd/commands/replay_command_test.dart: loading … [E]
    Error: Error when reading
    'lib/src/plugins/tdd/services/replay_history.dart': No such file or directory
  test/plugins/tdd/services/replay_history_test.dart: loading … [E]
  test/plugins/tdd/services/replay_runner_test.dart: loading … [E]
  test/plugins/tdd/services/replay_sandbox_test.dart: loading … [E]
```

17 red entries recorded (`066-replay-A1…A7`, `066-replay-U1…U10`,
classification `loadError`).

## Green evidence (this run — real numbers)

| Suite (chunked per disk protocol) | Result |
|---|---|
| `test/plugins/tdd/services/replay_history_test.dart` + `replay_sandbox_test.dart` + `replay_runner_test.dart` + `test/plugins/tdd/commands/replay_command_test.dart` | **37 passed, 0 failed** (fast tier) |
| `test/plugins/tdd/scenarios/sc_022_replay_full_history_test.dart` (`--preset=integration`) | **5 passed, 0 failed** |
| `test/plugins/tdd/commands` (fast chunk) | **47 passed, 0 failed** |
| `test/plugins/tdd/models` (fast chunk) | **60 passed, 0 failed** |
| `test/plugins/tdd/services` (fast chunk) | **323 passed, 0 failed** |
| `test/cli` (fast chunk — `cli_runner.dart` registration surface) | **171 passed, 0 failed** |
| `test/commands` (fast chunk — `tdd_command.dart` registration surface) | **100 passed, 0 failed** |
| `test/core/plugin_system` (fast chunk) | **17 passed, 0 failed** |
| `test/mcp` (fast chunk) | **71 passed, 0 failed** |

**Total: 794 passed, 0 failed.**

## Gates

- **`dart analyze`**: `47 issues found.` — byte-identical to the
  pre-feature baseline (`bd535c07`); all pre-existing infos (largest group:
  `examples/todo_tdd` nits). **Zero new issues.** `dart analyze lib/` and
  `dart analyze lib/ test/plugins/tdd/`: No issues found.
- **`dart format .`**: `Formatted 1545 files (9 changed)` — all 9 are this
  feature's own files; `git status` shows no unrelated file touched.
  Zero-format-diff vs the gate.
- **Kernel-cache hygiene**: every `dart test` invocation was followed by
  `rm -rf .dart_tool/test /tmp/dart_test.kernel.*`; the whole-tree
  `dart test test` was NOT used. `df -h .` at delivery: 1.3 GiB used of
  9.9 GiB (14%).

## Success criteria — verified vs not

| SC | Verification | Status |
|----|--------------|--------|
| SC1 clean full-history replay + read-only contract | A1 + SC-022 test 1: exit 0, `result=clean replayed=3 skipped=0 diverged=0`, real-tree `TreeSnapshot` byte-identical before/after, cycle-log bytes unchanged | **VERIFIED** |
| SC2 history tamper caught, entry named | A2 + SC-022 test 2: `- exit:` flip → `integrity -> diverged (chain mismatch: green)`, exit 1, and the tampered behavior's commands are provably never executed (fake-zfa invocation log empty for it) | **VERIFIED** |
| SC3 artifact drift caught, path named | A3 + SC-022 test 3: drifted generator → `gen -> drift (1 path: … modified)`, exit 1, path-stable (no sandbox path leaks) | **VERIFIED** |
| SC4 verify divergence caught, exits named | A4 + SC-022 test 4: broken subject → `verify -> diverged (exit expected 0, actual 1)`, exit 1 | **VERIFIED** |
| SC5 aggregation, partial, missing-log | A5: 2 replayable + 1 only-red → `replayed=2 skipped=1 diverged=0` exit 0; narrative-only log → exit 2 `partial`; missing log → exit 1 | **VERIFIED** |
| SC6 NDJSON event log | A6 + U10 + SC-022 test 5: parseable NDJSON, `replay.start` → per-stage `step.end` → `replay.end` with `exit` = process exit (0 clean, 1 divergent); no file without `--events` | **VERIFIED** |
| SC7 both surfaces + unknown id | A7: `zfa replay <feature>` and `zfa replay <…>/tdd/cycle-log.md` produce the identical summary/exit as `zfa tdd replay`; unknown `--behavior` → exit 1 naming id + recorded behaviors | **VERIFIED** |

Issue #806 Done-when mapping:

- **"Replaying the todo example's full recorded history passes clean"** —
  verified via SC-022's full-history clean replay, with the fixture history
  seeded through the real `CycleLog.append` writer: the same machine format
  (schema-1 chain, generation blocks, recorded commands) every
  pipeline-driven feature's history uses. The `example/` Flutter app itself
  predates the machine format — its `specs/031-scaffold-todo-example`
  cycle-log is hand-written narrative with zero `- behavior:` sections, so
  `zfa tdd replay 031-scaffold-todo-example` deterministically reports
  `partial` (exit 2) per the spec's edge case, never executing prose.
- **"An injected mutation into any replayed step is caught, with the step
  named"** — verified for all three tamper surfaces (history / artifacts /
  verify outcome), each naming behavior + step (SC2–SC4).

## Not verified here (honest gaps)

- The full 69-chunk `tools/run_tests_chunked.sh` matrix was not completed on
  this agent (10-minute execution window per invocation; the fast tier alone
  is ~1545 files). Every chunk that exercises the touched surface — the TDD
  plugin, `tdd_command.dart`, `cli_runner.dart` — plus the CLI-contract-
  sensitive `test/core/plugin_system` and `test/mcp` chunks ran green (794
  results). The remaining chunks are untouched by this diff (additive files
  + two registration lines).
- A real Flutter-SDK replay of the `example/` app (Out of Scope per spec).
- `zfa tdd replay 031-scaffold-todo-example` live invocation (covered by the
  equivalent narrative-only fixture in A5; same code path, zero parseable
  sections).

## Mutation/injection catches (summary)

| Injected mutation | Caught by | Named as |
|---|---|---|
| `- exit:` 0→1 inside a hashed green entry | integrity chain recompute | `chain mismatch: green` |
| Forged hash over a spliced `prev-hash` | prev-hash linkage | `chain linkage: green` |
| Hand-edited generated artifact | gen tree compare | `gen -> drift (1 path: … modified)` |
| Broke the subject the recorded command checks | verify replay | `verify-exit-mismatch` (expected 0, actual 1) |
| Recorded binary missing / unspawnable | verify/gen spawn | `runner-error` (POSIX 126/127) |
| Deleted a recorded red test artifact | red structural check | `red-missing-test-artifact: <path>` |
| Dishonest red (exit 0 / no classification) | red structural check | `red-exit-zero` / `red-no-classification` |
