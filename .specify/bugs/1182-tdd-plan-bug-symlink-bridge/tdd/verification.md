# TDD Verification — bug #1182 (`tdd plan` cannot resolve features under `.specify/bugs/<slug>`)

Hand-authored verification record for the bug-fix PR
`fix/1182-tdd-plan-bug-symlink-bridge`. Every number below is from an
actually executed command in this environment (Dart SDK 3.13.3, Linux
x64). Nothing here is projected or copied from a passing run that did not
happen. Machine-generated `zfa tdd verify` output (mutation gates) does
NOT apply to this record: the fix's surface is the CLI resolver itself,
not a feature with a test list — stated explicitly under "Not proved".

## Red (before the fix) — ACTUAL

Test: `test/plugins/tdd/commands/plan_command_bug_1182_test.dart`
(seed feature at `.specify/bugs/tdd-run-baseline-timeout` in a temp root,
then `zfa tdd plan --project <root> .specify/bugs/tdd-run-baseline-timeout`).

```
dart test test/plugins/tdd/commands/plan_command_bug_1182_test.dart
→ 00:00 +1 -4: Some tests failed.
```

The four RED failures reproduce the reported bug exactly:

- `a bug feature plans without a symlink bridge` — plan exited non-zero,
  no test list written.
- `artifacts land beside the bug spec...` — no artifact (plan never found
  the spec).
- `a missing bug spec reports the RESOLVED path...` — envelope carried no
  spec path.
- `a specs/-prefixed reference resolves the same feature` — stderr
  printed the doubled path, the exact reported defect:

```
zfa tdd plan: spec not found at /tmp/bug_1182_SWDXDU/specs/specs/1190-plain-feature/spec.md
zfa tdd plan: spec not found at /tmp/bug_1182_DRAPGW/specs/.specify/bugs/nope/spec.md
```

(The plain-name regression guard passed in the same run: legacy behavior
was intact before and after.)

## Green (after the fix) — ACTUAL

Fix: `TddFeaturePaths.resolve` (new,
`lib/src/plugins/tdd/services/feature_path_resolver.dart`) is routed
through `plan_command.dart`; artifacts and the prior-list read now use the
resolved directory; the not-found failure carries the resolved path in
the verdict envelope (`exitClass: spec-not-found`, `details.spec`).

```
dart test test/plugins/tdd/commands/plan_command_bug_1182_test.dart
→ 00:00 +11: All tests passed!
```

11/11: 3 bug-repro tests, 2 documented-shape command tests, 6 resolver
unit-contract tests (plain / specs-prefixed / bug dir / trailing slash /
absolute / undeclared-shape fallback).

## Full-suite verification — ACTUAL

- `dart analyze` — touched files:
  `No issues found!` (3 files). Whole repo: 135 issues, ALL pre-existing
  (104 infos + `examples/todo_tdd` unresolved-package errors); errors
  outside `examples/`: 0.
- `tools/run_tests_chunked.sh` discipline (same chunk list, same
  `--exclude-tags flutter`, kernel cache cleared between chunks), run via
  a resumable wrapper with identical per-chunk semantics:
  - 90 chunks: **84 PASS / 6 SKIP / 0 FAIL** (SKIP = folders whose tests
    are all slow-tier by design).
  - The repo runner's threshold-split (THRESHOLD=40) drops three
    directories' DIRECT test files from its chunk list — pre-existing
    runner blind spot, NOT touched by this PR. Those were run explicitly:
    - `test/plugins/tdd/commands` (46 files, includes this bug's tests):
      **+295: All tests passed!**
    - `test/plugins/tdd/services` (78 files): **+685: All tests passed!**
    - `test/plugins/tdd` (58 direct files): +1471 −23. A/B against the
      PRISTINE baseline (changes stashed, same chunk): +1467 −16, the −16
      being the same subprocess-heavy files (`bug_1162_subject_shape`,
      `bug_924_verify_preflight`, `issue_990_migrate_spec`). The with-fix
      delta is load-dependent flakiness in `run_baseline_cache_test.dart`
      (spawns child `dart test` processes): it passes standalone with the
      fix (+7), and all four flaky-prone files pass TOGETHER with the fix
      at moderate load (+35: All tests passed!). This flaky family is
      already recorded in the repo (`1096-cross-suite-cwd-race`,
      `test-harness-subprocess-deadlock`, `tdd-run-baseline-timeout`).
- `dart format .` — `Formatted 2389 files (0 changed)` after the initial
  pass formatted the new test file; `git diff --stat` afterwards shows
  only this PR's files.

## Success criteria

- PROVED: `zfa tdd plan .specify/bugs/<slug>` resolves the spec directly,
  writes artifacts beside it, needs no symlink bridge (red → green, real
  runs).
- PROVED: plain-name and `specs/<name>` shapes keep their contracts;
  artifacts never land under a fabricated `specs/...` path.
- PROVED: the not-found failure names the resolved path (stderr + verdict
  envelope).
- NOT proved: `zfa tdd run` / `zfa tdd verify` against a
  `.specify/bugs/<slug>` argument — run deliberately enforces a single
  plain segment (`validateFeatureSegment`) and its supported bug shape is
  the `bug-<slug>` name (specs/ bridge), per issue #1162's
  `isBugFeatureDir`. Widening run/verify to path-shaped arguments is a
  follow-up concern beyond this bug's minimal fix.
- NOT proved: mutation gate (`zfa tdd verify`) — no feature test list
  exists for a CLI-bug fix; suite-level verification above stands in.
