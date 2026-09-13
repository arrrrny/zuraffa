# Tasks: 1529 make timeout — receipt, scaled budget, trimmed re-certification

**Input**: Design documents from `/specs/1529-make-timeout-diagnosable-scaled-budget/`

**Prerequisites**: plan.md (required), spec.md (required for user stories)

**Tests**: REQUIRED — the TDD extension drives red-green-refactor for
every behavioural task; the fast tier keeps the suite runnable in
seconds.

**Organization**: MVP-first (M1 receipt → M2 budget → M3 trimming);
within a milestone the pure helpers land before their wiring.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g. US1, US2, US3)

## Path Conventions

- Single package: `lib/src/plugins/tdd/` (sources),
  `test/plugins/tdd/` (tests), spec artifacts under
  `specs/1529-make-timeout-diagnosable-scaled-budget/`.

## Milestone M1 — receipt on kill (US1, P1)

- [ ] **T001** [P] [US1] `tdd_timeout.dart`: add `elapsed` +
  `descendantArgvs` to `ProcessTimeoutException`; `runTimed` measures
  actual wall time and snapshots the child's descendants (POSIX `ps`,
  best-effort) at the deadline BEFORE the kill.
- [ ] **T002** [P] [US1] `tdd_timeout.dart`: pure `inferTimeoutPhase`
  (running/compiling/unknown + evidence) and `TddTimeouts.minStepBudget`
  (25 min floor constant).
- [ ] **T003** [US1] New `services/step_timeout_receipt.dart`:
  `StepTimeoutReceipt` model (`tdd-make-timeout-receipt.v1`: behavior,
  step, argv, elapsed, deadline, phase, evidence, output tail,
  capturedAt) + best-effort writer to
  `specs/<feature>/tdd/make.<behaviorId>.timeout.json`.
- [ ] **T004** [US1] `step_runner.dart`: `StepResult.timeoutReceipt`
  (`StepTimeoutInfo?`) built in the `ProcessTimeoutException` arm only.
- [ ] **T005** [US1] `run_driver_core.dart`: the error-outcome arm
  writes the make-step receipt into the feature tdd dir and prints the
  path; failed writes reported, never fatal (FR-1, FR-12).

## Milestone M2 — scaled budget (US2, P2)

- [ ] **T006** [P] [US2] `tdd_timeout.dart`: pure `scaledStepBudget`
  (`max(25 min, 4 x baseline)`, explicit override wins, null baseline →
  floor).
- [ ] **T007** [P] [US2] `run_baseline_cache.dart` +
  `corpus_baseline_cache.dart`: additive optional `durationMs` write/
  read; old files read as null.
- [ ] **T008** [US2] `run_driver_core.dart`: measure the baseline
  capture, persist its duration, derive the budget (explicit honored +
  loud warning when `4 x baseline >= explicit`; default upgraded),
  rebuild the step runner with the scaled budget, keep the ONE uniform
  deadline handed down as `--timeout` (FR-4–FR-6).

## Milestone M3 — trimmed re-certification (US3, P3)

- [ ] **T009** [P] [US3] New `services/recert_scope.dart`: pure import-
  closure scoping over `test/**/*_test.dart` (imports/exports/parts;
  relative + self-package URIs; memoized) → own test + closure hits, or
  the full-tree signal (FR-8, FR-11).
- [ ] **T010** [P] [US3] `make_command.dart`: the trimmed-decision
  helper — fingerprint computable + mtime scan proving no shared write
  outside the declared set + parseable scoped transcript → scoped
  command via the #1374 template-append pattern; every unmet condition
  → existing paths (FR-9, FR-10).
- [ ] **T011** [US3] `make_command.dart`: wire the decision into the
  step-5 baseline and step-9 guard selection (standalone) and the
  cached-baseline guard fallback (driver path) with #731 attribution;
  unattributable failures stay fail-closed (FR-10).

## Final

- [ ] **T012** [US1–US3] `/speckit.tdd.run` red-green evidence recorded
  under `tdd/`; `/speckit.tdd.verify` writes `tdd/verification.md`;
  `dart analyze` clean on changed files; `dart format` applied.
