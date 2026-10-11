# Bug Test: first refactor after every master bump pays a one-time ~85s dart compile exe of the zfa CLI — even when the parent runs from a current installed binary

- **Slug**: 1664-first-refactor-cli-compile
- **Tested**: 2026-09-15 (this session)
- **Fix report**: ./fix.md
- **Verification**: ../tdd/verification.md (real runs), ./red-evidence.md (pre-fix)

## What was verified

The `tdd.verify` audit ran against the working tree on
`fix/1664-first-refactor-cli-compile` with Dart 3.13.4 (stable, linux_x64).
Static analysis, the format gate, the targeted suites for the changed file
and every direct consumer (StepRunner, PipelineRunner, refactor passes,
staleness reader), and the fast-tier sweeps for the touched scopes
(`test/cli/`, `test/core/`, `test/plugins/tdd/services/`) all executed for
real in this session; the counts below are the runner's own output, not
estimates.

## Acceptance criteria → evidence

1. **First refactor after master bump uses an existing compiled binary (no
   85s compile)** — PROVED at the seam level.
   `test/cli/zfa_executable_1664_installed_binary_reuse_test.dart`
   U-1664-b1 was RED pre-fix (the seam did not exist — the resolution had no
   installed-binary awareness; ./red-evidence.md) and GREEN post-fix: the
   running binary is returned for the canonical candidate when the marker
   equals the checkout HEAD. The wiring sits exactly on the would-compile
   path `_compileCached` owns — the path the issue's measured
   `dart compile exe … zfa_exe.tmp` argv flows through — and after the
   fresh-cache check, so it fires precisely on the post-`rebuild.sh`
   cache-miss shape the report describes.
2. **Child seam detects the current installed binary and reuses it** —
   PROVED: U-1664-b1 pins the probe's full contract (returns the running
   executable; exactly one `git rev-parse HEAD` probe, cwd = the candidate
   source root). The probe is public and injectable, so every branch is
   exercised hermetically; `_compileCached` supplies
   `Platform.resolvedExecutable` in production.
3. **`.build_commit` comparison prevents stale binary reuse** — PROVED:
   U-1664-b2 (marker `a111…` vs HEAD `c5ed…` → null → compile), U-1664-b4/b5
   (missing / empty marker → null), U-1664-b6 (git probe exits 128 → null).
   Strict full-SHA equality; no prefix acceptance. The fail-open direction
   means every unprovable input keeps the pre-fix behavior.
4. **Steady-state refactor time unchanged (0.4–0.6s)** — PROVED by
   construction and by the pre-existing contract suites: the fresh-cache
   verdict runs FIRST (U3 of `test/cli/zfa_executable_test.dart` pins
   reuse-without-compiler-call, unchanged and green), the probe adds zero
   subprocesses for VM drivers (rejected before any I/O — U-1664-b3, and the
   U-1664-b9 wiring pin proves the compile path is untouched under
   `dart test`), and one marker read + one `git rev-parse` for a compiled
   parent on a cache miss. The U4/U5 staleness suites (lib/ and pubspec
   invalidation) ran green unchanged.

## Regression evidence

- Direct contracts of the changed file + consumers:
  `zfa_executable_test.dart`, `binary_staleness_test.dart`,
  `step_runner_test.dart`, `bug_1636_running_binary_tier_test.dart`,
  `bug_1645_pipeline_running_binary_tier_test.dart`,
  `refactor_passes_test.dart` → `00:16 +82: All tests passed!`
- Scopes: `test/cli/ + test/core/` → `+901 (1 skipped): All tests passed!`;
  `test/plugins/tdd/services/` → `+1135: All tests passed!`
- `test/plugins/tdd/commands/` full scope is flaky under sandbox load
  independent of this change: different single tests fail per run, and a
  stashed PRE-FIX tree failed four different tests in the same scope
  (A/B documented in ../tdd/verification.md §3). Every flagged test passes
  in isolation with and without the change (`+16: All tests passed!` both
  ways). Flagged as pre-existing environment flakiness, not a regression.

## Hard-constraint check

`git diff --stat` = one source file, 129 insertions, 0 deletions; the diff
touches no refactor-pass logic, no build-relevance gate, and no CLI entry
point. One PR per bug.
