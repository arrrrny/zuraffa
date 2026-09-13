# TDD Verification — Spec 1520 per-run scratch TMPDIR + age-guarded janitor + configurable root

Date: 2026-09-13 · Dart SDK 3.13.3 (stable) · branch
`feat/1520-per-run-scratch-tmpdir`

## Red evidence

Recorded in `tdd/red-evidence.txt` (2026-09-13T08:16Z, pre-implementation):

- **B1–B7 (fast tier)** — `dart analyze
  test/plugins/tdd/scratch_tmpdir_test.dart test/plugins/tdd/kernel_cache_age_guard_test.dart`
  → **23 errors**: `Target of URI doesn't exist:
  package:zuraffa/src/plugins/tdd/services/scratch_tmpdir.dart`,
  `Undefined name 'ScratchTmpDir'`, `The named parameter 'environment' isn't
  defined` (clearDartTestKernelCache), `The named parameter 'now' isn't
  defined` — the service and the new parameters did not exist (the
  spec-1333 red-protocol pattern: analyzer errors are the red for a not-yet-
  existing seam).
- **B8–B9 (CLI tier, behavioral red)** — `dart test
  test/plugins/tdd/bug_1520_run_scratch_tmpdir_test.dart` → **`00:15 +0 -2`**:
  B8 `Expected: a string starting with 'zfa-090-tdd-fixture-'  Actual: ''`
  (step children observed an EMPTY/ambient TMPDIR — no scratch existed) and
  B9 `Expected: '/tmp/zfa1520-cfg-root-…'  Actual: '.'` — the run drove a
  green cycle entirely on the shared/ambient TMPDIR.

## Green evidence

| Suite | Behaviors | Result |
|---|---|---|
| `test/plugins/tdd/scratch_tmpdir_test.dart` | B1–B7 | `00:00 +11: All tests passed!` |
| `test/plugins/tdd/kernel_cache_age_guard_test.dart` | B10–B13 | `00:00 +4: All tests passed!` |
| `test/plugins/tdd/bug_1520_run_scratch_tmpdir_test.dart` | B8–B9 | `00:15 +2: All tests passed!` |
| `test/plugins/tdd/bug_1507_kernel_cache_cycle_start_test.dart` (regression, SC-6) | C1–C7 | `00:11 +6: All tests passed!` |
| `test/plugins/tdd/bug_1333_refactor_reproof_retry_test.dart` (regression, SC-6) | B3–B6 | `00:11 +4: All tests passed!` |
| `test/plugins/tdd/services/step_runner_test.dart` + `subprocess_timeout_test.dart` + `corpus_step_runner_test.dart` (regression) | spawn path | `00:36 +48: All tests passed!` |
| `run_command_test.dart`, `runner_test.dart`, `runner_suite_test.dart`, `runner_instance_method_test.dart`, `run_baseline_cache_test.dart`, `run_command_path_format_test.dart`, `two_cycle_run_commands_test.dart`, `refactor_command_test.dart`, `bug_922…`, `bug_1329…`, `bug_1159…`, `verdict_envelope_test.dart`, `tdd_command_smoke_test.dart` (regression) | driver/loop unchanged | `All tests passed!` (33 + 11) |
| `differential_ref_runner_test.dart`, `differential_corpus_test.dart`, `differential_harness_test.dart`, `corpus_differential_command_test.dart` | spawn sites | `00:01 +51: All tests passed!` |
| `realize_command_test.dart`, `realize_diff_only_test.dart`, `realize_mock_command_test.dart`, `realize_command_1193_test.dart`, `bug_1367…`, `bug_1391…` | spawn sites | `All tests passed!` (11 on 1193; others green) |
| `test/integration/dream_cli_integration_test.dart` (integration preset) | dream wiring | `01:39 +1: All tests passed!` |

B10 is the honest behavioral check of the age floor: the fast-tier sweep test
calls the new signature with an injected clock (`commandStartedAt` 1 s after
the entry's real mtime, `now` 10 s after) — pre-spec semantics (mtime before
command start ⇒ delete) delete the entry; spec-1520 semantics keep it. B11
proves the floor did not disable the janitor (a 2 h-old dir + file are
swept, the dir recursively), B12 proves the #1507 `commandStartedAt` guard
still wins over the floor, B13 proves the configured root is swept under the
same guard stack.

## Success-criteria trace

- **SC-1** — B8: every step child of one `zfa tdd run` logged the SAME
  `zfa-090-tdd-fixture-<random>` TMPDIR (12 step invocations, one scratch);
  `Directory(scratch).existsSync()` false after the run.
- **SC-2** — B9 + B2: `.zfa.json` `tdd.tmpDir` end-to-end (scratch inside
  the configured root, cleaned at run end); fast tier proves `ZFA_TMPDIR` >
  `.zfa.json` > effective temp root with empty-value fallthrough.
- **SC-3** — B10: young-but-pre-start `dart_test.kernel.*` DIRECTORY
  survives the sweep (pre-spec: deleted).
- **SC-4** — B11 + the #1507 suite: 1 h+-old dirs/files swept exactly as
  before (the 1507 fixtures are backdated 1 h; the age floor adds command
  duration on top, so they stay eligible).
- **SC-5** — B6 (`runTimed` POSIX probe child prints the injected TMPDIR) +
  B7 (`StepRunner(zfaBin: probe, childEnvironment: …)` step child prints
  the injected TMPDIR).
- **SC-6** — `dart analyze` → **112 issues found**, identical to the
  pre-branch baseline (0 errors, 0 warnings — all 112 are pre-existing
  `info`s in unrelated files); the #1507 (6/6) and #1333 (4/4) regression
  suites are green.

## Constraint audit

- Fix scoped to TMPDIR handling: `tdd_timeout.dart` (optional
  `environment` → `Process.start`), `step_runner.dart` (optional
  `childEnvironment` forwarded by the default spawner), the five spec'd
  spawn sites (realize, realize-mock, dream, differential + their driving
  commands' scratch lifecycle), `kernel_cache.dart` (age floor + injectable
  knobs + configured-root sweep), `run_driver_core.dart`/`run_command.dart`
  (scratch lifecycle + `drive(childEnvironment:)`). No test runner
  semantics, state machine, or loop logic changed — every new parameter is
  optional with today's behavior as the default.
- Per-run scratch deletion is best-effort in `finally` blocks
  (run_command, realize, realize-mock, dream, corpus-differential).
- The janitor never deletes anything written after the command start
  (B12) nor anything younger than ~1 h (B10).
- One deliberate non-lib change: `bug_1333_refactor_reproof_retry_test.dart`'s
  seeder backdates its `$TMPDIR` kernel marker 1 h — the marker models a
  HISTORICAL leak and the age floor protects fresh entries; same fixture
  discipline the #1507 suite already uses.

## Disk housekeeping

`df -h /home/z` before each phase and after every suite run — peak usage
1.4 GB used / 8.0 GB free at all observations (baseline 86 MB used). No
kernel-dir accumulation during the cycle; the per-run scratch of each test
run is deleted at run end, and the janitor's own sweeps were exercised only
against injected roots.
