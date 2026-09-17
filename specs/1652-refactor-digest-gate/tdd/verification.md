# TDD Verification — Spec 1652-refactor-digest-gate

**Audited**: 2026-09-15 (cold-context audit, LLM-guided — repo not zfa-wired)
**Verdict: FAIL (pass 1) → remediation → PASS (final)**

## Phase 1 — Test-first evidence

Source: `tdd/cycle-log.md` (reds recorded before their fixes; the red
test and its fix share one commit per the tdd-profile convention).

| Behavior | Red evidence | Green evidence |
| -- | -- | -- |
| A1 (inheritance hit) | C1: `+7 -1` — the economics assertion itself: `Expected: <0> Actual: <1>` suite spawn (the pipeline ran where it must inherit), no `make-post-state` evidence | C3 `+8`, post-remediation `+10` |
| A2 (lib drift → pipeline) | none — GUARD, green pre-fix by design | C1 `+7 -1` run |
| U1a–c (baseline/config/exempt mismatch) | none — GUARD | C1 |
| U2 (corrupt record → pipeline) | none — GUARD | C1 (harness deletes the #1588 ledger per iteration so the record's fallback is the exercised path) |
| U3 (flag-less / --full-reproof → pipeline) | none — GUARD | C1 |
| U4 (ledger precedence) | none — GUARD | C1 |
| U5 (driver records at make-green) | C2: `+0 -4` — no record exists (no writer); U6 shares the root cause | C3 `+4` |
| U6 (stale record inert) | C2, same root cause as U5 | C3 |
| U7/U8 (remediation, M1/M7 killers) | added post-audit, green by construction under the fix (they pin contract facets the pass-1 mutants exposed) | `+10` |

The defect is an ECONOMICS defect in existing code — A1's honest red is
the redundant pipeline itself; every fallback row is green-by-design
pre-fix and recorded as such in the test list.

## Phase 2 — Test-smell rubric

- Every spawn-count assertion is the measurable economics claim; the
  inheritance evidence lines are asserted by their stable tokens
  (`1652`, `make-post-state`, the behavior id).
- Guards assert BOTH directions: zero spawns on the inherited path,
  strictly-more spawns on every fallback path (never a silent no-op).
- Fixtures are per-test temp dirs torn down in `tearDown`; the logging
  suite wrapper is the #1588 harness shape; no real AOT compile anywhere.
- No test doubles the SUT: the record is written through the same JSON
  contract and shared key helpers (`PassBatchLedger.treeDigest`,
  `baselineKeyFor`, `configKeyFor`) both production sides use.

No material smells.

## Phase 3 — Mutation sampling (rubric fallback; no CI mutation gate)

Changed region: `make_post_state.dart` (matches/read/write),
`refactor_command.dart` (the fast path), `run_driver_core.dart` (the
hook). One mutant at a time, `cmp`-restored after each.

| Mutant | Change | Result |
| -- | -- | -- |
| M1 | `matches()` drops the `test/` digest comparison | pass 1 **SURVIVED** (`+12`) — no test drifted `test/` |
| M2 | `matches()` drops the exempt-set comparison | **killed** (`+7 -1`, U1c) |
| M3 | the fast path loses the `--pass-batch` opt-in | **killed** (`+7 -1`, U3 flag-less arm) |
| M4 | the fast path loses the `--full-reproof` bypass | **killed** (`+7 -1`, U3 reproof arm) |
| M5 | the driver hook drops the `outcome=='green'` condition | **killed** (`+3 -1`, U5b — the #741 skip must not rewrite) |
| M7 | `matches()` drops the suite-template comparison | pass 1 **SURVIVED** (`+8`) — no test varied the template |

Pass-1 score: 4 killed, 2 survived, 0 timed out → FAIL; remediation
tests U7 (test-drift → pipeline) and U8 (template change → pipeline)
appended as the Phase-4 remediation tasks R1/R2.

Re-run after remediation: M1 **killed** (`+9 -1`, U7), M7 **killed**
(`+9 -1`, U8). Final: **6/6 killed**, restoration `cmp`-verified and the
suite re-run green (`+10`) after restoration.

## Phase 4 — Acceptance-criteria coverage

| SC | Evidence |
| -- | -- |
| SC-1 zero suite spawns on the inherited path, honest evidence | A1 (red→green), U5a |
| SC-2 every mismatch dimension re-runs the pipeline | A2, U1a–c, U2, U3, U7, U8 |
| SC-3 per-behavior refactor cost collapses on the inherited path; full gates unchanged | A1 spawn-count; the #1588 suite (+16, `--preset=all`) proves the ledger contract untouched; run_command_test + refactor_command_test neighbors green except the pre-existing A12 (below) |

## Findings carried to the PR (not remediation — the audit passes)

1. `refactor_command_test.dart` A12 fails on CLEAN `master` @ 06cbf85e
   (verified in a throwaway master worktree: `Expected: contains
   'build' / Actual: []`) — the fake-zfa build spawn it expects is
   already absent on master before this branch. Pre-existing, flagged
   for the maintainer.
2. The accepted trade-off (recorded in the spec's Assumptions): a
   cross-behavior regression from behavior k's make now surfaces at the
   phase-2b batch pass (or the next full gate) instead of behavior k's
   refactor — the run still fails honestly, one gate later, at N→1
   preflight cost instead of N.

## Final gate verdict

**PASS** — TDD discipline proven (evidence-shape reds for the economics
defect, guards green-by-design recorded honestly), mutation sampling
6/6 killed after one remediation pass, acceptance criteria covered,
regression scope green (one pre-existing master failure documented).
