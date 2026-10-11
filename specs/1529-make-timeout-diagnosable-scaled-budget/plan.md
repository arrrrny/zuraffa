# Plan — Spec 1529 make timeout: diagnosable kill receipt, scaled budget, trimmed re-certification

**Branch**: `feat/1529-make-timeout-diagnosable-scaled-budget` | **Date**: 2026-09-13 | **Spec**: [spec.md](./spec.md)

## Technical Context

- **Surface**: the timed-spawn primitive
  (`lib/src/plugins/tdd/services/tdd_timeout.dart`), the driver's step
  contract (`lib/src/plugins/tdd/services/step_runner.dart`), the run
  driver's baseline capture + error-outcome arm
  (`lib/src/plugins/tdd/commands/run_driver_core.dart`), the baseline
  caches (`lib/src/plugins/tdd/services/run_baseline_cache.dart`,
  `lib/src/plugins/tdd/services/corpus_baseline_cache.dart`), and make's
  re-certification set selection
  (`lib/src/plugins/tdd/commands/make_command.dart`).
- **Key concepts**: the #742 kill contract (`runTimed` SIGKILL +
  `ProcessTimeoutException` → `runner-error` StepResult); the #741
  once-per-run suite baseline handed to make via `--suite-baseline`; the
  #1505 corpus dependency fingerprint (sha256 over pubspec/lock/suite
  template); the #731 already-red tolerance; the #1374 scoped-suite
  template pattern (`$suiteTemplate <path>`); the #1159 ONE-uniform-
  deadline contract; the issue #1329 error-outcome recording.
- **Hard constraints honored**: no change to the `zfa make` generation
  command, to `SingleTestRunner.runSuite`'s spawn/parse mechanics, to
  the run-state machine, or to the cycle-log format. The receipt is
  additive evidence (never a gate). Small/fast suites keep byte-
  identical behavior (floor ≥ old ceiling; empty importer set ⇒ zero
  extra spawns; scope == whole tree ⇒ full suite as before).

## Approach

1. **Timed-spawn diagnostics** (`tdd_timeout.dart`): `runTimed` starts a
   Stopwatch, and at the deadline — BEFORE the SIGKILL — snapshots the
   child's descendant argv via `ps -eo pid,ppid,args` (POSIX,
   best-effort, try/catch; empty list on Windows/failure).
   `ProcessTimeoutException` carries `elapsed` (actual wall time) and
   `descendantArgvs`. New pure helpers: `inferTimeoutPhase` (running →
   compiling → unknown, evidence-carrying) and `scaledStepBudget`
   (`max(floor, 4 x baseline)`, explicit wins). `TddTimeouts.minStepBudget`
   = 25 min (the issue's floor).
2. **Step contract** (`step_runner.dart`): `StepResult` gains
   `timeoutReceipt` (`StepTimeoutInfo?`): argv, elapsed, deadline,
   phase, evidence, output tail. Built ONLY in the
   `ProcessTimeoutException` arm — every other path keeps `null`.
3. **Receipt writer** (new `services/step_timeout_receipt.dart`):
   `StepTimeoutReceipt` model + `write()` to
   `specs/<feature>/tdd/make.<behaviorId>.timeout.json`
   (`tdd-make-timeout-receipt.v1`). Best-effort at the call site: a
   failed write prints a note and never changes the outcome.
4. **Driver wiring** (`run_driver_core.dart`):
   - the error-outcome arm, for `step == 'make'` with a
     `timeoutReceipt`, writes the receipt into `featureDir/tdd/` and
     prints the path in the failure report (FR-1, FR-12);
   - the baseline capture measures its wall time and persists
     `durationMs` through both caches (FR-7); after capture the driver
     derives the scaled budget: explicit `--timeout` honored + loud
     warning when `4 x baseline >= explicit`; default upgraded to
     `max(25 min, 4 x baseline)` (floor with no measurement); the
     (possibly upgraded) budget rebuilds the step runner and stays the
     ONE uniform deadline handed down (FR-6).
5. **Baseline caches** (`run_baseline_cache.dart`,
   `corpus_baseline_cache.dart`): additive optional `durationMs` in
   write/read; old files without the key read as null (floor applies).
6. **Trimmed re-certification** (new `services/recert_scope.dart` +
   `make_command.dart`):
   - `recertScopeFor(...)`: pure scoping — enumerate `test/**/*_test.dart`,
     memoized transitive closure over imports/exports/parts (relative +
     self-package URIs), return the own test + closure hits, or null
     when the scope covers the tree (FR-8, FR-11);
   - `make_command.dart` computes the trimmed decision: fingerprint
     computable (FR-9a) + scoped transcript parseable (FR-10) + (guard
     time) mtime scan proving no shared write outside the declared set
     (FR-9b) → scoped baseline/guard via the #1374 template-append
     pattern with the SAME scope both sides (FR-10); every unmet
     condition falls back to the existing paths unchanged; the
     driver-path guard upgrades the cached-baseline fallback from
     "full suite" to the scoped importer run with #731 attribution
     against the cached full-suite baseline (unattributable → fail-
     closed refusal).

## Alternatives considered

- **Killing the whole process tree** (setsid/pgid) on timeout: real leak
  (grandchildren survive), but it changes spawn semantics for every TDD
  child — out of this spec's scope (#1520's TMPDIR work is the
  companion); the receipt's descendant snapshot at least RECORDS the
  tree.
- **Budget from corpus-cache only** (never measure fresh): rejected —
  the fresh per-run measurement is already paid for by the #741 capture;
  the cache only needs to carry the duration for reuse runs.
- **Scope by feature test directory** (all tests of the feature):
  rejected — for the dogfood (51 behaviors in one dir) the scope IS the
  suite; import-closure scoping is the only cut that actually trims.
- **Reading the pipeline's written-file list for the write set**:
  rejected — `GenerationStep` carries commands, not files, and touching
  the pipeline violates the constraint; the mtime scan observes the
  truth on disk instead.

## Verification plan

- Fast-tier unit tests for every pure helper (budget, phase inference,
  scoping, receipt model) — no real processes except the timed-spawn
  tests that already exist.
- A driver-level test with a fake zfa entrypoint whose make step sleeps
  past a tiny deadline: runner-error + receipt on disk with all fields.
- The existing suites for the touched surfaces stay green
  (`subprocess_timeout_test`, `step_runner_test`, `run_baseline_cache_test`,
  `run_command_test`, `runner_test`, make command suites).

## Milestone plan (MVP-first)

1. **M1 — receipt on kill (US1)**: tdd_timeout diagnostics +
   StepTimeoutReceipt + StepResult field + driver write. Testable
   alone; ships the operator value even if the run dies again.
2. **M2 — scaled budget (US2)**: cache durationMs + budget derivation +
   loud warning + hand-down. Depends on M1's helpers only.
3. **M3 — trimmed re-certification (US3)**: recert_scope + make
   decision + fallbacks. Independent of M1/M2 at runtime; lands last
   (largest surface, most conservative).
