# TDD Verification — Spec 1333 refactor false regression transient runner

## Test-first evidence

Every behavior on `tdd/test-list.md` was written BEFORE its implementation
and observed RED against the pre-fix code, then GREEN after:

| Behavior | RED evidence (pre-fix / skeleton) | GREEN evidence (post-fix) |
|---|---|---|
| B1 (classifier matrix, FR-1) | Skeleton reproduced the bug (every failure → regression): 9/13 unit tests failed — all six infra-tier cases, `parseFailingTestNames`, and both tail cases (`dart test test/plugins/tdd/reproof_failure_classifier_test.dart`) | 13/13 pass |
| B2 (tail truncation, FR-3) | Same red run (2 assertions failed) | 13/13 pass |
| B3 (one infra failure retried green, FR-1/FR-2) | Skeleton run: `outcome=regression`, counter `2`, exit non-zero — the exact issue #1333 signature (transient infra counted as a genuine regression) | `outcome=clean/refactored`, counter `3`, exit 0, both kernel markers cleared |
| B4 (exhaustion → runner-error + diagnostics, FR-1/FR-2/FR-3) | Skeleton run: `outcome=regression` (false regression, no diagnostics) | `outcome=runner-error`, counter `4`, cycle-log carries `re-proof verdict: infra-runner-error (exit 255)`, `re-proof retries: 2`, transcript tail |
| B5 (assertion regress immediate + recorded, FR-4/FR-3) | Skeleton run: verdict red-side already regression (unchanged), but the cycle-log diagnostic entry was MISSING — the issue's "not appended to cycle-log.md" signature | counter `2` (no retry), `re-proof verdict: regression (exit 1)` + tail in cycle-log, cache markers survive (no clear fired) |
| B6 (diagnostics on the clean verdict, FR-3) | Skeleton run: evidence entry carried only `re-proof: green` — no verdict line, no retries, no tail | `re-proof verdict: green (exit 0)` + `re-proof retries: 0` + tail block present |

Red runs: `dart test test/plugins/tdd/reproof_failure_classifier_test.dart`
(unit tier) and `dart test --preset=regression
test/plugins/tdd/bug_1333_refactor_reproof_retry_test.dart` (CLI tier) —
per-file only, never the full suite (disk ceiling).

## Test-smell rubric

- No test doubles for the classifier: pure functions exercised with literal
  transcripts from the issue's observed failure grammar.
- CLI tests drive the PUBLIC surface (`CliRunner` → `zfa tdd refactor`)
  against temp fixtures; the flaky runner is a counting shell script (the
  bug #922 two-phase discipline), not a mocked `runSuite`.
- Invocation counts, exit codes, cycle-log content, and cache-marker
  lifecycle are all asserted — no vacuous green checks.
- Backward-compat pins run unchanged: `refactor_command_test.dart` (14/14),
  `bug_922_refactor_preflight_baseline_test.dart` (9/9 — includes the
  mutation-M2 guard: an unparseable re-proof transcript is STILL a
  regression, never retried into a pass), `bug_1311_refactor_receipt_refresh_test.dart`
  (9/9), `corpus_economics/incremental_verify_test.dart` (10/10 — scoped
  re-proof untouched).

## Mutation results

Mutants applied to the fix, each killed by the spec-1333 suite:

| Mutant | Mutation | Result |
|---|---|---|
| M-A | `_maxReproofRetries 2 → 0` (retry disabled) | KILLED — B3 fails (counter 2 ≠ 3, outcome=regression) |
| M-B | classifier collapsed to `return regression` for every branch (infra tier deleted) | KILLED — B3 fails (no retry, false regression verdict) |

Pre-existing guard kept green: bug #922 M2 (unparseable re-proof red must
stay a regression) passes unchanged — the classification gate does not
weaken the baseline tolerance contract.

## Acceptance-criteria coverage

1. **Classify infra vs assertion (AC1/FR-1)** — B1 unit matrix + B3/B4/B5
   CLI verdicts. PROVED.
2. **Retry re-proof on infra failure with kernel-cache clear (AC2/FR-2)** —
   B3 (recovers after one clear; both markers deleted) and B4 (exhaustion
   → runner-error, never regression). PROVED.
3. **Diagnostic recording on every verdict (AC3/FR-3)** — B4/B5 (failure
   entries with exit code + truncated tail) and B6 (clean verdict line +
   tail). PROVED.
4. **Backward compatibility (AC4/FR-4)** — B5 (assertion red: 2 invocations,
   no retry) + the unchanged pre-existing suites listed above. PROVED
   (with one flagged environmental exception below).

## Environment notes (honesty)

- `sc_012_reproves_green_test.dart` (A1, A9) fails on this sandbox BOTH
  with and without the fix (verified on the base commit) — the build pass
  cannot resolve a working `zfa` entrypoint in the fixture without
  `--zfa-bin`. Unrelated pre-existing environmental failure, not a
  regression of this change.
- Only the suites touched by this change were run (disk ceiling); the full
  suite was never executed.
