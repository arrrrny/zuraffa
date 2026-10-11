# TDD Test List — Spec 1520 per-run scratch TMPDIR + age-guarded janitor + configurable root

One behavior per line, traced to the FRs / SCs in spec.md. Every behavior is
written as a failing test FIRST (RED), then made to pass (GREEN). Red for
this feature: the scratch service and the new parameters do not exist
pre-fix (analyzer/compile errors = the spec-1333 red-protocol pattern, re-run
after the skeleton lands), and the CLI fixture observes children logging the
ambient user TMPDIR with no scratch dir (behavioral red).

## Behaviors

| # | Behavior | Trace | Test file |
|---|--------|--------|-----------|
| B1 | `ScratchTmpDir.acquire` creates a `zfa-<label>-<random>` dir under the effective temp root of the INJECTED environment (TMPDIR/TEMP/TMP, else systemTemp); labels sanitize `[^A-Za-z0-9._-]` to `_` | FR-1 / SC-1 | test/plugins/tdd/scratch_tmpdir_test.dart |
| B2 | `ZFA_TMPDIR` (non-empty) names the scratch root; `.zfa.json` `tdd.tmpDir` names it when `ZFA_TMPDIR` is absent; `ZFA_TMPDIR` wins over `.zfa.json`; empty values fall through | FR-6 / SC-2 | test/plugins/tdd/scratch_tmpdir_test.dart |
| B3 | `childEnvironment` overrides `TMPDIR`/`TEMP`/`TMP` to the scratch path and preserves every other base variable (PATH merge) | FR-2 | test/plugins/tdd/scratch_tmpdir_test.dart |
| B4 | `dispose()` deletes the scratch recursively (files inside are gone) and is idempotent; a second dispose never throws | FR-1 | test/plugins/tdd/scratch_tmpdir_test.dart |
| B5 | An unusable configured root (`ZFA_TMPDIR` names an existing FILE) makes `acquire` return null — never a throw | FR-1 edge | test/plugins/tdd/scratch_tmpdir_test.dart |
| B6 | `runTimed(..., environment: {'TMPDIR': X})` children observe `TMPDIR=X` (POSIX probe child) | FR-2 / SC-5 | test/plugins/tdd/scratch_tmpdir_test.dart |
| B7 | `StepRunner(zfaBin: <probe>, childEnvironment: env)` spawned step children observe the injected `TMPDIR` | FR-2 / SC-5 | test/plugins/tdd/scratch_tmpdir_test.dart |
| B8 | A full `zfa tdd run` records a fresh `zfa-090-tdd-fixture-*` TMPDIR in EVERY step child and that scratch dir does not exist after the run completes | FR-1, FR-3 / SC-1 | test/plugins/tdd/bug_1520_run_scratch_tmpdir_test.dart |
| B9 | With `ZFA_TMPDIR=<root>` exported into the child env via the fixture's `.zfa.json`/env surface, the run's scratch lands inside `<root>` and is cleaned at run end | FR-6 / SC-2 | test/plugins/tdd/bug_1520_run_scratch_tmpdir_test.dart |
| B10 | A `dart_test.kernel.*` DIRECTORY older than the command start but younger than the age floor SURVIVES the sweep (pre-fix: deleted) | FR-5 / SC-3 | test/plugins/tdd/kernel_cache_age_guard_test.dart |
| B11 | A `dart_test.kernel.*` DIRECTORY and FILE older than the age floor (and the command start) are swept — the floor does not disable the janitor; directories go recursively | FR-5 / SC-4 | test/plugins/tdd/kernel_cache_age_guard_test.dart |
| B12 | An entry modified AFTER the command start survives regardless of age — the #1507 `commandStartedAt` guard still wins | FR-5 | test/plugins/tdd/kernel_cache_age_guard_test.dart |
| B13 | The sweep covers the configured scratch root (`ZFA_TMPDIR`) alongside the ambient TMPDIR root, under the same guard stack | FR-7 | test/plugins/tdd/kernel_cache_age_guard_test.dart |

## Red protocol

Run per file, never the full suite (disk ceiling):

```
dart test test/plugins/tdd/scratch_tmpdir_test.dart                # B1-B7 (fast)
dart test test/plugins/tdd/kernel_cache_age_guard_test.dart        # B10-B13 (fast)
dart test test/plugins/tdd/bug_1520_run_scratch_tmpdir_test.dart   # B8-B9 (CLI, slow tier)
```

Expected RED evidence (pre-fix): B1–B7 — `ScratchTmpDir` /
`environment:` / `childEnvironment` do not exist (analyzer errors, the
red-protocol TODO re-run after skeleton); B10 — the sweep deletes the
young-but-pre-start entry; B11–B13 — analyzer errors on the new parameters;
B8–B9 — step children log the ambient user TMPDIR (no `zfa-` scratch) and no
scratch dir is ever created.
