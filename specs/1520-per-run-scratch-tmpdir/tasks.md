# Tasks — Spec 1520 per-run scratch TMPDIR + age-guarded janitor + configurable root

MVP first: the scratch service + the chokepoint (T1–T4) make the leak fixed
by construction for `tdd run`; the remaining spawn sites, the janitor age
floor, and the configurable root are follow-on tasks in dependency order.
Behavioural tasks (T-marked tests) are red-green; the rest are
non-behavioural wiring that `dart analyze` + the existing suites guard.

## Phase 1 — scratch service + chokepoint (MVP)

- [x] T1 (test-first, red) `test/plugins/tdd/scratch_tmpdir_test.dart`:
      the `ScratchTmpDir` service contract — default root resolution from an
      injected environment, `ZFA_TMPDIR` > `.zfa.json` `tdd.tmpDir` >
      effective temp root, label sanitization, `createTemp` naming
      (`zfa-<label>-<random>`), childEnvironment TMPDIR/TEMP/TMP override
      with base merge, dispose (recursive + idempotent), best-effort null on
      an unusable configured root. Traces FR-1, FR-6.
- [x] T2 (green) `lib/src/plugins/tdd/services/scratch_tmpdir.dart`:
      `configuredRoot`, `acquire`, `childEnvironment`, `dispose` exactly per
      T1. Traces FR-1, FR-4, FR-6.
- [x] T3 (test-first, red) `runTimed(environment:)` passthrough +
      `StepRunner(childEnvironment:)` injection probes in
      `scratch_tmpdir_test.dart` (POSIX child prints `$TMPDIR`).
      Traces FR-2, SC-5.
- [x] T4 (green) `tdd_timeout.dart` `runTimed` gains the optional
      `environment` parameter (forwarded to `Process.start`);
      `step_runner.dart` `StepRunner` gains `childEnvironment` and its
      default spawner forwards it. Traces FR-2.

## Phase 2 — run command wiring (the #1507 construction fix)

- [x] T5 (test-first, red) `test/plugins/tdd/bug_1520_run_scratch_tmpdir_test.dart`:
      a full `zfa tdd run` whose fake zfa records `$TMPDIR` — every step
      child observes a fresh `zfa-090-tdd-fixture-*` scratch and the scratch
      is deleted after the run. Traces FR-1, FR-3, SC-1.
- [x] T6 (green) `run_driver_core.dart` `drive()` + phase-zero spawn accept
      and forward `childEnvironment`; `run_command.dart` acquires the scratch
      (label = the feature reference), injects it into both lane drives, and
      disposes in a `finally`. Traces FR-1, FR-3, FR-4.

## Phase 3 — remaining spawn sites

- [x] T7 (green, wired like T6) `realize_mock_command.dart` — scratch
      lifecycle + `environment:` on the default suite runner and tier-1
      driver spawns. Traces FR-1, FR-2.
- [x] T8 (green, wired like T6) `realize_command.dart` — scratch lifecycle +
      `environment:` on the default fixture driver and suite runner spawns.
      Traces FR-1, FR-2.
- [x] T9 (green, wired like T6) `dream_runner.dart` — `execute` owns the
      scratch; `_timedProcessRun` and both default spawners forward the env.
      Traces FR-1, FR-2.
- [x] T10 (green, wired like T6) `differential_ref_runner.dart` +
      `corpus_differential_command.dart` — the runner's default spawner/git
      runner forward `childEnvironment`; the command owns the scratch and
      disposes it in its existing `finally`. Traces FR-1, FR-2.

## Phase 4 — age-guarded janitor + configurable root sweep

- [x] T11 (test-first, red) `test/plugins/tdd/kernel_cache_age_guard_test.dart`:
      a `dart_test.kernel.*` DIRECTORY younger than the age floor but older
      than the command start SURVIVES the sweep (SC-3 — pre-fix it is
      deleted); old dirs and files are still swept (SC-4); the
      `commandStartedAt` guard still wins over the age floor; the configured
      root is swept alongside the ambient TMPDIR root (FR-7).
- [x] T12 (green) `kernel_cache.dart` — injectable
      `environment`/`now`/`ageGuard` (default `defaultKernelAgeGuard` = 1h),
      the two-guard delete rule, and the configured-root second sweep.
      Traces FR-5, FR-7.

## Phase 5 — verification

- [x] T13 `dart analyze` — no new warnings (baseline: 112 infos, 0
      warnings); `dart format` clean on touched files; the bug-1507 suite
      stays green (SC-6); the new suites green.
- [x] T14 `tdd/verification.md` — red evidence, green evidence, SC-by-SC
      trace, disk housekeeping note (`df -h` before/after phases).
