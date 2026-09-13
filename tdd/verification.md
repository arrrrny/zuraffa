# tdd.verify — SPEC 1568 `tdd make` hand-step first-class run state

- **Verified**: 2026-09-14, this session, on
  `feat/1568-tdd-make-hand-step-first-class` (working tree, pre-push)
- **Toolchain**: Dart 3.13.3 (stable) on linux_x64 (container; no Flutter
  SDK — flutter-tagged suites are excluded per the repo's own chunked
  runner policy)
- **Scope**: the nine changed source files + the four new 1568 suites, then
  the sanctioned chunked fast-tier sweep

## Verdict: PASS

## 0. RED evidence (pre-fix, real runs)

Full output in
`.specify/bugs/1568-tdd-make-hand-step-first-class/red-evidence.md`:
the three fast suites were compile-red against the untouched API
(`MakeOutcome.handStep`, `HandStepClassifier`, `RunState.handSteps`,
`summaryLine(handStepIds:)` all missing), and the make integration
reproduction captured the exact #1568 symptom on the pre-fix tree:

```
Expected: contains 'make: behavior=U1 outcome=hand-step feature=090-hand-step-1568'
  Actual: ...
    make: behavior=U1 outcome=generation-error feature=090-hand-step-1568
  Which: does not contain 'make: behavior=U1 outcome=hand-step feature=090-hand-step-1568'
```

— the planner-declared hand-step condition (entity-return contract subject,
`scan() -> ScanSession`, #1565 func-skip plan) graded `generation-error`,
exactly the issue's wall.

## 1. Static analysis (post-fix, post-format)

```
dart analyze lib/src/plugins/tdd/commands/make_command.dart \
             lib/src/plugins/tdd/commands/run_driver_core.dart \
             lib/src/plugins/tdd/commands/run_command.dart \
             lib/src/plugins/tdd/commands/run_engine_command.dart \
             lib/src/plugins/tdd/commands/run_skin_command.dart \
             lib/src/plugins/tdd/models/run_state.dart \
             lib/src/plugins/tdd/models/generation_plan.dart \
             lib/src/plugins/tdd/services/hand_step_classifier.dart \
             lib/src/plugins/tdd/services/run_state_store.dart \
             test/plugins/tdd/{commands,models,services}/…1568_test.dart
→ No issues found!
```

`dart format .` → `Formatted 2837 files (0 changed)` — zero remaining
formatting diffs (CI format gate).

## 2. The 1568 suites (REAL runs, post-fix)

```
dart test test/plugins/tdd/commands/make_command_hand_step_1568_test.dart \
          test/plugins/tdd/commands/run_driver_hand_step_1568_test.dart \
          test/plugins/tdd/models/run_state_hand_steps_1568_test.dart \
          test/plugins/tdd/services/make_hand_step_1568_test.dart
→ 00:18 +14: All tests passed!                       (fast tier)
→ 00:38 +5:  All tests passed!                       (make integration, real dart test children)
```

19/19 green. Coverage against the acceptance criteria:

- **AC-1** (`outcome=hand-step`, not `generation-error`, continues): A-1568-s1
  (make surface, real runner) + d2 (driver park arm, run continues).
- **AC-2** (`hand_steps=N` + ids listed): d1 (summary token) + d2/d4
  (terminal block `hand-step for U1` + remedy).
- **AC-3** (mechanical behaviors reachable): d2 pins `make U1` followed by
  `gen U2 → verify-red U2 → make U2 → refactor U2` with U2 done.
- **AC-4** (resume never re-drives): d3 (parked line, no gen/verify-red/make
  spawn) + B-1568-r1 (`hand_steps` round-trip + legacy-snapshot
  compatibility) + the store round-trip (`run_state_store.dart`).
- **SC-7 guards**: A-1568-g1 scalar + undeclared keep the honest
  `generation-error`; the entity-pipeline mechanical-surface guard is
  enforced in the make arm (plans carrying entity/mock/wire steps never
  park).

## 3. Mutation evidence (targeted, real runs — each mutant KILLED)

| Mutant | Site | Result |
| ------ | ---- | ------ |
| M1: `isEntityShapedReturn` → `return false` | `hand_step_classifier.dart` | s1 red (`Some tests failed`) — killed |
| M2: park arm drops `.markHandStep(row.id)` | `run_driver_core.dart` | d2 red (`Some tests failed`) — killed |
| M3: phase-1 resume skip removed | `run_driver_core.dart` | d3 red (`Some tests failed`) — killed |

Every mutant was reverted from a byte backup and the restored tree
re-verified green (`00:17 +4: All tests passed!` on the driver suite).

## 4. Chunked regression sweep — the repo's sanctioned runner, NO NEW failures

`tools/run_tests_chunked.sh` (fast tier, kernel cache purged between
chunks — `dart_test.yaml` documents the ~6.5 GB single-invocation cache
that overflows this container's disk):

```
=== 104 chunks over the full fast suite ===
OK: all chunks passed.
```

Including the tdd chunks:
- `test/plugins/tdd/commands` → `07:45 +601: All tests passed!`
  (includes the five 1568 make/driver integration pins + bug_1544, bug_1551,
  func_command_1565 — every sibling regression suite unchanged)
- `test/plugins/tdd/models` → `00:01 +90: All tests passed!`
- `test/plugins/tdd/services/*` → all passed (the 1080-test baseline
  surface plus the new classifier suite)
- `SKIP: no fast-tier tests in test/plugins/tdd/scenarios` (by design)

## 5. Pre-existing failures (flagged, unrelated — verified on master)

`test/plugins/tdd/make_command_test.dart` (tagged `regression`/`e2e` — a
tier `dart_test.yaml` marks "NOT for CI / cloud agents"; excluded from the
chunked fast sweep) fails 4 pins on this container. Verified PRE-EXISTING
by running the same pins on pristine master twice — a clean-tree stash run
in this working tree and an independent `master` worktree — both red
identically (`green-with-failed-build` expectations vs the #1587
build-skip's `outcome=green`). None touch the 1568 surfaces; none were
introduced or masked by this fix.

## 6. Success criteria proven vs not

| SC | Proved by | Status |
| -- | --------- | ------ |
| SC-1 make outcome=hand-step | A-1568-s1 (real runner) | PROVED |
| SC-2 named hand-step stop | A-1568-s2 | PROVED |
| SC-3 non-fatal park, honest red | d2 + d3 | PROVED |
| SC-4 persisted, resume skips | B-1568-r1 + d3 + store round-trip | PROVED |
| SC-5 hand_steps=N + ids | d1 + d2/d4 | PROVED |
| SC-6 mechanical behaviors drivable | d2 (U2 done behind parked U1) | PROVED |
| SC-7 classification-only change | A-1568-g1 + chunked sweep (all sibling suites unchanged) | PROVED |
