# Tasks: `zfa replay` — deterministically re-execute a feature's recorded TDD history

**Input**: Design documents from `/specs/066-zfa-replay/` (spec.md, plan.md,
research.md, data-model.md, contracts/replay.md, quickstart.md)

**Prerequisites**: plan.md (required), spec.md (required), research.md,
data-model.md, contracts/

**Tests**: MANDATORY — the tdd extension drives this feature test-first.
Behavior markers (`[A1]`–`[A7]`, `[U1]`–`[U10]`) trace tasks to
`specs/066-zfa-replay/tdd/test-list.md`; `/speckit.tdd.run` ticks a task's
checkbox only when it can read a behavior id from it, and every behavior's test
is written and observed RED before the implementation task that turns it green
may run.

**Organization**: Tasks grouped by user story (spec.md US1–US4) with a
foundational phase for the history/sandbox services the P1 stories consume.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1–US4)
- Include exact file paths in descriptions

## Path Conventions

Repo-root package (matches plan.md): implementation under
`lib/src/plugins/tdd/{commands,services}/` + `lib/src/commands/`, fast-tier
tests under `test/plugins/tdd/{commands,services}/`, slow-tier scenario under
`test/plugins/tdd/scenarios/`.

---

## Phase 1: Setup

**Purpose**: register the replay command so both CLI surfaces exist

- [X] T001 Create `ReplayCommand` as a skeleton in
  `lib/src/plugins/tdd/commands/replay_command.dart` (flags: `--behavior`,
  `--project`/`--project-root`, `--zfa-bin`, `--timeout`, `--events`,
  `--keep-sandbox`; summary printer emitting
  `replay: feature=<f> result=partial replayed=0 skipped=0 diverged=0` as a
  placeholder last line) and register it in
  `lib/src/commands/tdd_command.dart` after `RunCommand`; update
  `test/plugins/tdd/tdd_command_smoke_test.dart` to expect `replay` in
  `zfa tdd --help`

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: the pure history service + the sandbox contract every stage
consumes. Test-first: each group's failing tests land before its
implementation.

- [X] T002 [P] [U1] [U2] Write the failing history-parsing tests FIRST in
  `test/plugins/tdd/services/replay_history_test.dart`: grouping parsed
  entries by behavior id in file order (seeded via the real `CycleLog.append`
  writer — red then green then refactor for one behavior, interleaved
  behaviors stay grouped); generation-step extraction from a green section
  (`- generation:` / `  - step:` / `    exit:` / `    purpose:`, in order;
  `  (none)` → empty; refactor/red entries → empty); zero parseable entries →
  empty behavior list — observe red before the service exists (depends on T001
  for imports only)
- [X] T003 [P] Implement `ReplayHistory` in
  `lib/src/plugins/tdd/services/replay_history.dart`: `load(featureDir)` →
  `List<ReplayBehavior>` (grouped `ParsedCycleEntry`s via
  `CycleEvidence.parseEntries` + section-scoped generation-step extraction);
  expose `red`/`green`/`refactors`/`genSteps`/`hashless` per the data model
  (depends on T002 red)
- [X] T004 [P] [U3] [U4] [U5] Write the failing integrity/replayability tests
  FIRST in `test/plugins/tdd/services/replay_history_test.dart`: chain
  recompute via `CycleLog.payloadFromFields` (valid red→green chain verifies;
  a tampered `- exit:` field breaks with the behavior + `green` entry named;
  a spliced prev-hash breaks with a linkage divergence; a hash-less schema-0
  entry is skipped as unverified, never failed); red structural checks
  (missing test path → `red-missing-test-artifact`; recorded exit 0 →
  `red-exit-zero`; no classification → `red-no-classification`; valid red
  passes); replayability derivation (only-red → gen/verify skippable; green
  without generation block → gen skipped; green without command → verify
  skipped) — observe red
- [X] T005 [P] Implement the integrity stage + replayability on
  `ReplayHistory` (per-behavior chain walk: recompute sha256 over
  `payloadFromFields`, assert prev-hash linkage from
  `CycleLog.genesisHash`; red structural validation against the real tree;
  `canReplayGen`/`canReplayVerify`; depends on T004 red)
- [X] T006 [P] [U6] Write the failing sandbox tests FIRST in
  `test/plugins/tdd/services/replay_sandbox_test.dart`: seeding copies
  pubspec.yaml/pubspec.lock/analysis_options.yaml/.zfa.json/lib//test//
  specs/<feature>//.specify//.dart_tool/package_config.json from the real project;
  excludes .git, build/, .dart_tool/test/**; absent sources skipped silently;
  cleanup deletes the sandbox (kept only with keep); seeded files are byte-identical
  copies — observe red
- [X] T007 [P] Implement `ReplaySandbox` in
  `lib/src/plugins/tdd/services/replay_sandbox.dart`:
  `Directory.systemTemp.createTemp('zfa_replay_')` + copy/exclusion rules +
  `delete()`/keep contract (depends on T006 red)

## Phase 3: User Story 1+2 — the replay runner (clean pass + every catch)

**Purpose**: execute the stages — gen replay with tree compare, verify replay
with recorded-exit assertion — and shape the report. Test-first.

- [X] T008 [P] [U7] [U9] Write the failing gen-replay + report tests FIRST in
  `test/plugins/tdd/services/replay_runner_test.dart`: identical trees →
  `identical` with zero paths (gen step re-run against a fixture whose
  recorded command rewrites the same content); drift → sorted, project-
  relative, A/M/D-classified paths with the sandbox root absent from every
  path; report shaping — result rules (any divergence → `divergent` exit 1;
  zero replayed → `partial` exit 2; else `clean` exit 0) and
  replayed/skipped/diverged counts — observe red
- [X] T009 [P] Implement the gen stage + report shaping in
  `lib/src/plugins/tdd/services/replay_runner.dart`: run recorded gen steps
  (shell, cwd = sandbox, `--zfa-bin` substitution for bare `zfa` invocations),
  `TreeSnapshot.capture` both trees, `changedPaths` →
  `ReplayStepResult(artifact-drift)` with path classification;
  `ReplayReport.result()`/`exitCode` per FR-013 (depends on T008 red)
- [X] T010 [P] [U8] [U9] Write the failing verify-replay tests FIRST: recorded
  green command runs in the sandbox (cwd asserted), exit equal → `green`;
  recorded 0 vs actual 1 → `verify-exit-mismatch` divergence carrying
  expected/actual; unspawnable command → `runner-error` divergence; command
  absent → verify skipped; a project with pubspec.yaml but no
  `.dart_tool/package_config.json` → verify skipped with the `no package
  resolution` warning (FR-011) — observe red
- [X] T011 [P] Implement the verify stage in `replay_runner.dart` (shell-run
  the recorded green command under the timeout budget; compare exits; typed
  divergences; depends on T010 red)

## Phase 4: User Story 3 — full-history command wiring

**Purpose**: the `zfa tdd replay <feature>` surface end-to-end: aggregation,
summary/exit contract, cleanup. Test-first via `CliRunner.runCapturing`.

- [X] T012 [A5] [A1] Write the failing command e2e tests FIRST in
  `test/plugins/tdd/commands/replay_command_test.dart` (fixture project with
  fake zfa bin + shell runner scripts, cycle-log seeded via real
  `CycleLog.append`): SC1 clean single-behavior replay — exit 0, header +
  `[replay] … integrity -> verified` / `gen -> identical (0 paths)` /
  `verify -> green (exit 0)` lines, final
  `replay: feature=<f> result=clean replayed=1 skipped=0 diverged=0` as the
  last stdout line, and a real-tree `TreeSnapshot` byte-identical
  before/after the run (read-only contract); SC5 full-history — 3 behaviors
  (2 replayable + 1 only-red) → exit 0 `replayed=2 skipped=1 diverged=0`;
  narrative-only log → exit 2 `result=partial`; missing cycle-log → exit 1 —
  observe red
- [X] T013 Implement the command body in `replay_command.dart`: arg parsing →
  `ReplayHistory.load` → per-behavior stage walk (integrity → gen → verify →
  refactor-noted) → warnings → summary line + `exitCode` on every code path;
  sandbox `finally` cleanup unless `--keep-sandbox` (path printed in header +
  summary); `--behavior` filter with unknown-id exit 1; `--project` resolution
  via `ProjectRoot.find()` with `_stripSpecsPrefix`/`_validateFeatureSegment`
  equivalents (depends on T012 red)
- [X] T014 [A2] [A3] [A4] Write the failing mutation-catch e2e tests: SC2 —
  flip a green entry's `- exit:` in the seeded log → exit 1
  `result=divergent`, divergence names behavior + `green` kind; SC3 —
  hand-edit a generated test file in the real project so the re-rendered
  sandbox content differs → `gen -> drift` naming the path, exit 1; SC4 —
  break the subject the recorded green command's script checks →
  `verify -> diverged (exit expected 0, actual 1)`, exit 1 — observe red
- [X] T015 Make T014's catches pass through the wired command (fix any drift
  between stages/lines only — the service contracts are already green;
  depends on T014 red)

## Phase 5: User Story 4 — machine contract: NDJSON events + top-level surface

**Purpose**: `--events` NDJSON writer and the `zfa replay` dream surface.

- [X] T016 [P] [U10] [A6] Write the failing event-log tests FIRST in
  `test/plugins/tdd/commands/replay_command_test.dart`: `--events <path>` on
  a clean run → parseable NDJSON, first line `replay.start` with feature +
  behaviors, one `step.end` per replayed stage (`identical`/`green`
  statuses), last line `replay.end` with `exit: 0`; on a divergent run → the
  divergence-carrying `step.end` is present and `replay.end.exit == 1`; no
  `--events` → no file created — observe red
- [X] T017 [P] Implement the NDJSON writer (in
  `lib/src/plugins/tdd/services/replay_events.dart` or inside
  `replay_runner.dart`): one `jsonEncode` line per event, stable key order,
  written on every outcome, `replay.end.exit` = process exit (depends on T016
  red)
- [X] T018 [A7] Write the failing top-level surface tests: `zfa replay
  <feature>` (new `lib/src/commands/replay_command.dart` delegating to the
  same capability) and `zfa replay <path>/tdd/cycle-log.md` produce the same
  summary/exit as `zfa tdd replay <feature>`; register in
  `lib/src/cli/cli_runner.dart` `_addCoreCommands`; smoke-test both in
  `test/plugins/tdd/commands/replay_command_test.dart` — observe red
- [X] T019 Implement the delegating top-level command + registration (path
  form: derive feature + project root from the cycle-log path; depends on
  T018 red)

## Phase 6: Verification & polish

**Purpose**: full-suite proof, format gate, hygiene

- [X] T020 [A1] [A5] [A6] [A7] Write the slow-tier scenario
  `test/plugins/tdd/scenarios/sc_022_replay_full_history_test.dart` (tagged
  `slow`): the SC1 fixture replays clean end-to-end, then each SC2–SC7
  mutation catch replays divergent with the step named — the issue's
  Done-when pair as one executable scenario
- [X] T021 Run `dart analyze` — zero new issues vs the 47-issue baseline;
  run `tools/run_tests_chunked.sh` — all chunks pass; record real
  pass/fail counts for tdd/verification.md
- [X] T022 Run `dart format .` — zero-format-diff gate; clean fixture/build
  artifacts (temp sandboxes, .dart_tool kernel caches); verify `df -h .`
  healthy; append the phase record to the feature worklog
