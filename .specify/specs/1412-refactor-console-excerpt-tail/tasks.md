# Tasks: 1412-refactor-console-excerpt-tail

- **Spec ID**: 1412-refactor-console-excerpt-tail
- **Created**: 2026-09-15

Dependency order: T001 (driver-tier RED tests + fixture flood shape, red
evidence recorded) → T002 (console excerpt fix, GREEN) → T003 (secondary
ownership-aware gate remedy + unit tests, MVP-optional) → T004 (verify +
artifacts). T002 unblocks T004; T003 is independent of T001/T002 and may land
in the same PR (the issue's "if scope permits").

## T001: Red — driver-tier excerpt tests + fixture flood shape (MVP)

- `test/plugins/tdd/helpers/tdd_fixture.dart` — ADDITIVE refactor outcome
  `flood` in the fake zfa's refactor stanza (mirrors gen's #1329 flood):
  realistic transcript (preflight head, applying-passes block, failing
  build pass, misfire-stop), 251 captured lines, exit 1. No existing
  outcome touched.
- `test/plugins/tdd/bug_1412_refactor_excerpt_tail_test.dart` — new driver
  suite (bug_1329 harness):
  - U-1412-1 (SC-1): failing refactor flood → captured stdout contains
    `pass: build`, `exit: 1`, `pass "build" failed — misfire-stop.`; does
    NOT contain `preflight exit: 0`
  - U-1412-2 (SC-2): the honest truncation marker (`truncated`,
    `last 10 of`) appears in the console excerpt
  - U-1412-3 (SC-3): short `boom` transcript → excerpt prints its
    non-empty lines, no marker
  - U-1412-4 (SC-4): the cycle-log error section for the flood still shows
    `200 of 251` and the final diagnostic line — the #1329 recorded path
    regression pin (hard constraint)
- RED evidence recorded in tdd/cycle-log.md before any lib/ change.

## T002: Green — console excerpt routes through _outputTail

- `lib/src/plugins/tdd/commands/run_driver_core.dart`:
  - `static const int _consoleExcerptLines = 10` (documented, issue #1412)
  - `_printOutputExcerpt`: compact non-empty lines → `_outputTail(compact,
    maxLines: _consoleExcerptLines)` → print each line with the 3-space
    indent; empty output prints nothing
  - NO change to `_outputTail` or its journal/cycle-log call sites
- T001 suite goes green; re-run full touched suites.

## T003: Secondary — ownership-aware build-gate remedy (scope-permitting)

- `lib/src/commands/build_command.dart`:
  - `@visibleForTesting static List<String> analyzerOffendingPaths(String)`
    — deduped `path:line:col` fields of error/warning lines only (#1035
    line format, line-anchored)
  - `@visibleForTesting static List<String> analyzeGateRemedyLines(String)`
    — ownership verdict lines per plan.md's decision table
  - `verifyAnalyzeOrFail`: verdict line 1 byte-identical; remedy lines now
    the returned ownership lines
- `test/commands/build_command_unit_test.dart` — new groups (SC-5):
  - hand-authored-only offenders → ownership-naming remedy, no "Fix the
    generator"
  - generated-only offenders → existing "Fix the generator" remedy
  - info lines / summary counts never produce offenders; duplicates dedupe;
    >3 hand-authored names cap with a `+N more` remainder

## T004: Verify + artifacts

- `dart analyze` on the changed files (no issues)
- Targeted `dart test` on the touched suites (real counts recorded)
- `dart format .` clean (CI format gate)
- tdd/verification.md written from the REAL run outputs (no stale copy)
- spec.md / plan.md / tasks.md / analysis.md committed with the code
