# TDD test list — bug 1187 (test timeout scale)

Behaviors that must exist before the fix is accepted. Each maps to a test in
`test/helpers/zfa_test_timeout_scale_test.dart` (fast tier, no subprocesses)
or to a whole-suite property proven by running the suite itself.

| # | Behavior | Test |
|---|----------|------|
| B1 | A missing `ZFA_TEST_TIMEOUT_SCALE` parses to the 1.0 identity scale (defaults unchanged when unset) | `parseTimeoutScale > missing variable parses to the 1.0 identity scale` |
| B2 | Blank values parse to 1.0 (empty env var in CI is the same as unset) | `parseTimeoutScale > blank values parse to the 1.0 identity scale` |
| B3 | Integer/decimal values parse to their numeric value (whitespace-trimmed) | `parseTimeoutScale > integer and decimal strings parse to their numeric value` |
| B4 | Values below 1.0 clamp up to 1.0 — the scale relaxes budgets, never tightens them below what CI validates against | `parseTimeoutScale > values below 1.0 clamp up to 1.0 (never tighten budgets)` |
| B5 | Unparsable / NaN / infinite values fall back to 1.0 (they would otherwise poison every budget into a hang) | `parseTimeoutScale > invalid values fall back to the 1.0 identity scale` |
| B6 | The process-wide scale is read ONCE at isolate start from the environment the process actually started with | `process-wide scale > matches the environment the test process started with` |
| B7 | The effective `runZfaSource` default child budget is 75s × scale and never below 75s | `scaled budgets > default child timeout is 75s stretched by the process scale` |
| B8 | The AOT compile budget is 100s × scale and never below 100s | `scaled budgets > AOT compile budget is 100s stretched by the process scale` |
| B9 | `scaleDuration` stretches an arbitrary base (suite `Timeout` declarations) proportionally | `scaled budgets > scaleDuration stretches an arbitrary base proportionally` |

Whole-suite properties (proven by suite runs, recorded in `cycle-log.md` /
`verification.md`):

| # | Property | Evidence |
|---|----------|----------|
| P1 | With the scale unset, `test/feature_flags` is green with byte-identical semantics (74/74) | `dart test test/feature_flags --preset=all` |
| P2 | With `ZFA_TEST_TIMEOUT_SCALE=2`, the same suite is green through the scaled ceilings (no behavior change, only budgets move) | same command with the variable set |
| P3 | The new tests discriminate the fix: on the unfixed helper they fail (undefined symbols), on the fixed helper they pass | `git stash` cycle in `cycle-log.md` §4 |

Non-behavioral constraints:

- Explicit call-site child budgets in the helper's callers are unchanged;
  only the default scales.
- The suite files that spawn subprocesses keep their `@Tags(['slow'])` —
  the fast tier stays meaningful; no new tags, no new skips, no assertion
  edits in existing tests.
