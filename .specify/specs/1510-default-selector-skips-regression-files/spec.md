# 1510-default-selector-skips-regression-files

- **Spec ID**: 1510-default-selector-skips-regression-files
- **Created**: 2026-09-13
- **Source**: GitHub issue #1510 (SPEC 1510 — Default test selector skips make-command regression files)
- **Type**: bug (P1 — false-green validation: honest direct-file invocations silently run zero tests)
- **Branch**: feat/1510-default-selector-skips-regression-files

## Problem

Running either make-command regression suite by direct file path under the
repository's default preset exits 79 with `No tests ran. No tests match the
requested tag selectors: include: "<all>" exclude: "slow"`:

```bash
dart test test/plugins/tdd/make_command_test.dart            # exit 79
dart test test/plugins/tdd/make_command_declared_071_test.dart # exit 79
```

Both files carry `@Tags(['slow'])` and `dart_test.yaml` line 74 declares the
global default `exclude_tags: slow`. The `package:test` runner applies that
exclusion as a suite-level filter regardless of which paths were passed
explicitly on the command line, so a directly-named slow-tagged file is
silently emptied: zero tests are selected, the runner reports success-shaped
output ("No tests ran"), and the exit code 79 is the only honest signal —
one that automated validation loops (pool agents certifying PR fixes) have
already misread as a pass. This is the same false-green class as issue
#1382, one level up: #1382 broke the tier's own aggregate invocation;
#1510 breaks per-file invocations used to validate individual fixes.

The two files are precisely the suites a contributor reaches for when
changing the make pipeline (`MakeCommand`): the 42-behavior CLI-surface
suite and the declared-entity routing pin (issue #951 / feature 071).

## Goal

`dart test <file>` for each named make-command regression file runs the
tests that file actually contains (exit 0, real pass/fail counts) under the
default preset, without inflating the fast tier that CI's `dart_core` job
(30-minute budget, currently ~22.3 minutes) depends on.

## Root cause (verified in this session)

- `dart_test.yaml` declares `exclude_tags: slow` at the top level (the
  default preset). `test_core` merges CLI `--exclude-tags` by UNION with
  the file value, so the default exclusion always applies.
- `test_core` (0.6.20) has no per-path selector config and no
  CLI-args-conditional config: `dart_test.yaml` cannot express "do not
  exclude `slow` when the user named a file". The only selector-side lever
  is an explicitly-chosen preset (`all`, `regression`, …), which direct
  one-file validation runs do not use.
- Therefore the fix must come from the files' tagging (spec criterion 2),
  which the issue explicitly allows as the alternative to a selector
  change (criterion 1).

## Success criteria (measurable)

- **SC-1**: `dart test test/plugins/tdd/make_command_test.dart` exits 0
  under the default preset and executes all 42 behaviors in that file
  (no `No tests ran`, no exit 79).
- **SC-2**: `dart test test/plugins/tdd/make_command_declared_071_test.dart`
  exits 0 under the default preset and executes its 1 behavior.
- **SC-3**: The two files remain out of CI's `dart_core` fast lane: the
  lane's selected test set is unchanged (the 30-minute budget is not
  inflated), via the lane's selector rather than via the `slow` tag.
- **SC-4**: The two files are covered by the repo's heavy lanes:
  `dart test --preset=regression` and `dart test --preset=all` both select
  them (the issue's stated workaround selectors become truthful).
- **SC-5**: No other test file's tier membership changes: default preset
  still excludes every file that was excluded before this fix (except the
  two named files, whose re-tagging IS the fix), and the regression-tier
  integrity pin (#1382) still passes.
- **SC-6**: `dart analyze` on every changed file reports no new issues;
  changed Dart files are `dart format`-clean.

## Hard constraints

- Fix ONLY the test selector or the test files' tagging (`@Tags`
  annotations, `dart_test.yaml`, and selector invocations in CI lanes).
- Do NOT change test logic, the make command, or the state machine.
- Must not break other tests dependent on the current selector: CI's fast
  lane must keep its current composition; `--preset=integration`,
  `--preset=property`, `--preset=benchmark`, `--tags ffi`, and the
  `flutter` lane are untouched.
- No new `dependency_overrides`; no pubspec changes.
