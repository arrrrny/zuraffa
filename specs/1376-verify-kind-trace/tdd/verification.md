# TDD Verification — feature `1376-verify-kind-trace`

Generated from the red-green-refactor loop that closed issue #1376
(EPIC #1133 exit criterion 3).

## Gate

- gate: `pass`

## Test evidence

- RED: `dart test test/plugins/tdd/services/behavior_kind_trace_test.dart`
  — loading failure (`BehaviorKindTrace` unresolved) before any
  production code. Recorded in `tdd/cycle-log.md`.
- GREEN: 15/15 passed — parser (kind cells, polarity cells, bare
  `sequence`, comma-bearing literals, dedupe + canonical order), unknown
  tokens → `not-traced`, registry trace (missing file / header-less /
  unknown token), report markdown section, stdout line + JSON payload,
  NOT_ASSESSED byte-compatibility.
- Regression: 44/44 passed across
  `mutation_auditor_test.dart`,
  `bug_837_mutation_verify_pipeline_test.dart`,
  `bug_1044_verify_runner_test.dart`,
  `bug_1045_verify_preflight_classification_test.dart`,
  `bug_924_verify_preflight_test.dart`,
  `verify_command_test.dart`.
- Static: `dart analyze` on the 4 touched files — No issues found.

## E2E (SC-1 / SC-2)

- command: `cd example && zfa tdd verify --feature 004-login-ui`
- stdout gained the machine summary line:
  `kinds: presence=2 absence=1 route-outcome=2 enabled-state=1 sequence=1 not-traced=1`
- `specs/004-login-ui/tdd/verification.md` gained
  `## Behavior kinds (issue #1376)`: per-kind counts + per-behavior
  list + W1 honestly not-traced (its generated test predates the
  taxonomy header).
- the `--json` verdict envelope `details.behavior_kinds` carries
  counts + by_behavior + not_traced.
- gate verdict, exit classes, mutation buckets, restoration scope:
  unchanged (additive reporting only).

## Traceability

- `U-1376-1` → FR-001 (parser)
- `U-1376-2` → FR-002 (unknown tokens)
- `U-1376-3` → FR-001, FR-002, SC-2 (registry trace + not-traced)
- `U-1376-4` → FR-003, FR-006 (report fields + markdown section)
- `U-1376-5` → FR-004, FR-005 (stdout line + envelope details)
- `U-1376-REG1` → FR-006, SC-3 (byte-compatibility guard)
