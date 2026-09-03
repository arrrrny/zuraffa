# Verification: `zfa replay` path-stable replay (spec 0806-zfa-replay)

**Date**: 2026-09-03 · **Branch**: `spec/0806-zfa-replay` · **Dart**: 3.13.3 (stable; format gate re-verified on the CI-pinned 3.13.1)
**Method**: test-first TDD via the tdd extension — every behavior below was written and observed RED before the implementation that turned it green. Evidence entries live in `tdd/cycle-log.md`, appended through the real `CycleLog.append` writer (schema-1 hash chain — this log is itself replayable by the feature it certifies).

## /speckit.tdd.verify dispatch (step 7)

`zfa tdd verify --feature 0806-zfa-replay` was dispatched for real:

```text
mutation: gate=not_assessed killed=0 survived=0 timed_out=0 mutation_was_run=false
❌ mutation audit gate: not_assessed (no behavior artifacts registered)
```

The mutation engine derives its scope from the feature's pipeline-registered
behavior artifacts (`artifacts.json`); this feature's tests are repo-level
unit/scenario suites (the spec 066 delivery hit the same wall), so the audit
fell back to the extension's LLM-guided protocol: the evidence below is from
the real `dart analyze` / `dart test` / live-replay runs of THIS session.

## Test-first evidence (red)

`dart test <5 new test files>` (pre-implementation):

```text
Failing tests:
  test/plugins/tdd/services/replay_paths_test.dart: loading … [E]
    Error: Undefined name 'ReplayPaths'
  test/plugins/tdd/services/replay_anchor_test.dart: loading … [E]
    Error: No named parameter with the name 'recordedRoot'
  test/plugins/tdd/commands/func_convergent_test.dart [E]
    Expected: <0>  Actual: <1>
    zfa tdd func: … carries an UnimplementedError in an unrecognized shape
  test/commands/entity_convergent_test.dart [E]
    Expected: contains 'already exists'
    Actual: '✓ Created entity: lib/src/domain/entities/todo/todo.dart'
```

9 red entries recorded (`0806-replay-A1…A2`, `0806-replay-U1…U7`).

## Green evidence (this run — real numbers)

| Suite | Result |
|---|---|
| NEW: `replay_paths_test.dart` + `replay_anchor_test.dart` + `func_convergent_test.dart` + `entity_convergent_test.dart` | **28 passed, 0 failed** |
| NEW: `sc_023_replay_path_stable_test.dart` (`--preset=integration`) | **3 passed, 0 failed** |
| 066 regression: `replay_history` + `replay_sandbox` + `replay_runner` + `replay_command` (fast) | **37 passed, 0 failed** |
| 066 regression: `sc_022_replay_full_history_test.dart` (`--preset=integration`) | **5 passed, 0 failed** |
| `test/plugins/tdd/` (whole folder, fast chunk) | **870 passed, 0 failed** |
| `test/plugins/tdd/services` (chunk) | **503 passed, 0 failed** |
| `test/plugins/tdd/commands` (chunk) | **129 passed, 0 failed** |
| `test/plugins/tdd/models` (chunk) | **78 passed, 0 failed** |
| `test/commands` (fast chunk — entity create surface) | **134 passed, 1 failed — pre-existing (see below)** |
| `test/cli` (fast chunk — `cli_runner.dart` registration surface) | **175 passed, 0 failed** |
| `test/core/plugin_system` (fast chunk) | **17 passed, 0 failed** |
| `test/mcp` (fast chunk) | **71 passed, 0 failed** |
| `test/regression` (fast chunk — entity regression surface) | **8 passed, 0 failed** |
| `test/plugins/*` — 26 subfolder chunks (api…xray + root files) | **1030 passed, 0 failed** |
| `test/plugins/tdd/scenarios` (`--preset=integration`) | **16 passed, 4 failed — all 4 pre-existing (see below)** |

## The live Done-when pair (issue #806, literally)

**1. Replaying the todo example's full recorded history passes clean** —
`examples/todo_tdd` is the real todo example: 27 machine-format entries
recorded on a different agent box (`- test:` fields anchored at
`/home/z/my-project/workspace/todo_tdd/./…`, gen steps carrying
`/home/z/dart-sdk/bin/dart /home/z/my-project/zuraffa/bin/zfa.dart …`,
an `artifacts.json` registry pointing outside any local root). Live run
on this fresh clone:

```text
$ dart bin/zfa.dart replay examples/todo_tdd/specs/001-todo-app/tdd/cycle-log.md
[replay] A1 integrity -> verified
[replay] A1 gen -> identical (0 paths)
[replay] A1 verify -> green (exit 0)
… (A2, A3, U1–U6 same; schema-0 entries warned, not failed;
   001-todo-app-refactor: refactor recorded, not re-executed)
replay: feature=001-todo-app result=clean replayed=9 skipped=1 diverged=0
EXIT=0
```

The single skipped behavior is the refactor pseudo-behavior (9 refactor
entries, no green/gen) — refactors are recorded, never re-executed (066
FR-012, unchanged). Before this PR the same command reported
`result=divergent replayed=0 skipped=1 diverged=9`, exit 1 — every behavior
failing integrity on `red-missing-test-artifact: /home/z/my-project/workspace/todo_tdd/./…`.

**2. An injected mutation into any replayed step is caught, with the step
named** — live injection (a canary line appended into the generated
`todo.g.dart`, which the recorded `build` step regenerates):

```text
[replay] A1 gen -> drift (1 path: lib/src/domain/entities/todo/todo.g.dart modified)
replay: feature=001-todo-app result=divergent replayed=1 skipped=1 diverged=8
EXIT=1
```

Behavior + stage + project-relative path named. After `git checkout --`,
the replay returned to `result=clean … exit 0` and `git status` on the
example stayed empty (read-only contract held through both runs).

## Gates

- **`dart analyze`**: issue lines byte-identical to the pristine-master
  baseline (24 pre-existing info lines, largest group: todo-example nits);
  diff of sorted analyzer output vs stashed baseline: **empty — zero new
  issues**.
- **Format gate** (CI's own job: `dart format --set-exit-if-changed lib
  test` on the pinned SDK 3.13.1): **exit 0, 0 changed**. This includes a
  format-only fixup of 4 files that arrived drifted with the pr-943 merge
  (`subject_signature_deriver.dart`, `test_list_reader.dart`,
  `bug_937_reader_sections_test.dart`, `wire_command_test.dart`) — the gate
  was already failing on master; the fixup restores it.
- **Kernel-cache hygiene**: every `dart test` invocation was followed by
  `rm -rf .dart_tool/test /tmp/dart_test.kernel.*`; the whole-tree
  `dart test test` was NOT used (one deliberate `test/plugins/` monolithic
  probe exhausted the disk exactly as the protocol warns — cleaned
  immediately, re-run per-chunk all green). `df -h .` at delivery:
  7.2 GiB free of 9.9 GiB.

## Success criteria — verified vs not

| SC | Verification | Status |
|----|--------------|--------|
| SC1 recorded-elsewhere full history replays clean | SC-023 test 1 (exit 0, `result=clean`, no recorded root in any spawn — fake-zfa log asserted) + the live todo run above | **VERIFIED** |
| SC2 injected mutation caught, path named | SC-023 test 2 (`gen -> drift (1 path: … modified)`, exit 1) + the live mutation catch above; SC-023 test 3 (leaked-registry negative control → named runner-error exit 7) | **VERIFIED** |
| SC3 same-machine replay unchanged | The full 066 suite (37 fast + 5 SC-022) passes unmodified; all `replay_*` fixtures untouched except additive helpers | **VERIFIED** |
| SC4 live todo example clean + live mutation caught | Both runs above, from this session | **VERIFIED** |
| SC5 convergent generation | U6 (existing entity → exit 0, bytes untouched, no receipt) + U7 (implemented subject with stale doc comment → exit 0 `already-implemented`; genuine throw → exit 1) + fresh-create guard test | **VERIFIED** |
| SC6 analyzer / format / chunked gates | Zero new analyzer issues; CI format gate green; chunked suites above | **VERIFIED** |

## Pre-existing failures flagged (unrelated to this diff, present on pristine master)

- `test/commands/corpus_command_test.dart` A2 (US1.AC2) — "contract drift —
  missing `**Template Version**` marker"; reproduced on stashed pristine
  master.
- `test/plugins/tdd/scenarios/sc_018_plan_run_loop_e2e_test.dart` (1) and
  `sc_019_legacy_dialect_migration_test.dart` (3) under
  `--preset=integration`; reproduced on stashed pristine master (the same 4
  failing tests, byte-identical list).

## Not verified here (honest gaps)

- The full 70-chunk `tools/run_tests_chunked.sh` matrix was not completed on
  this agent; every chunk exercising the touched surface (the TDD plugin,
  `entity_command.dart`, `func_command.dart`, the 4 format-fixup files, the
  CLI registration surface, `test/mcp`, `test/regression`) ran green, and
  the untouched remainder is additive files + formatter-only changes.
- Red reproduction and refactor re-execution remain out of scope (066
  decisions, restated in this spec).
- A real Flutter-SDK replay of `example/` (narrative pre-format log — exit 2
  edge case, unchanged).

## Mutation/injection catches (summary)

| Injected mutation | Caught by | Named as |
|---|---|---|
| Canary line in a generated `.g.dart` (live todo tree) | gen tree compare (the recorded `build` regenerates it) | `A1 gen -> drift (1 path: lib/src/domain/entities/todo/todo.g.dart modified)` |
| Generator drift (regeneration writes a different body) | SC-023 test 2 | `gen -> drift (1 path: lib/… modified)` |
| Registry not re-anchored (negative control) | SC-023 test 3 | `runner-error: recorded gen step failed (exit 7)` |
| History tamper (hashed entry) | 066 integrity chain recompute (unchanged) | `chain mismatch: green` |
| Broken subject under the recorded green command | 066 verify replay (unchanged) | `verify-exit-mismatch` (expected 0, actual 1) |
