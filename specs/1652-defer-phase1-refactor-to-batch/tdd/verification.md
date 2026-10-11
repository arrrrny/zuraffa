# TDD Verification — Spec 1652-defer-phase1-refactor-to-batch

**Audited**: 2026-09-16 (cold-context audit, LLM-guided — repo not
zfa-wired for `tdd verify`; same protocol as the merged digest-gate
audit, every command below really run)
**Verdict: PASS (one remediation pass added a missing mutant killer)**

## Phase 1 — Test-first evidence

Source: `tdd/cycle-log.md`. Subject under test:
`lib/src/plugins/tdd/commands/run_driver_core.dart` (`_driveBehavior` —
the phase-1 refactor scheduling). Suite:
`test/plugins/tdd/issue_1652_defer_phase1_refactor_test.dart`
(scripted fake zfa, fast tier).

| Behavior | Red evidence (pre-fix) | Green evidence (post-fix) |
| -- | -- | -- |
| A1 (forward-run deferral) | RED — refactor spawned between makes (`firstRefactor < lastMake`; transcript: `[run] B-001 refactor -> clean` right after `make -> green`) | pass |
| A1b (#694 skip defers) | RED — same root cause | pass |
| A1c (exit-disagreeing skip token defers — verify remediation, M3 killer) | not present pre-audit (drives the bug-986 arm the other tests never reach) | pass |
| A2 (batch-boundary scheduling + `--pass-batch`) | RED — refactor argv interleaved with makes | pass |
| A3 (resume re-entry window unchanged) | none — GUARD, green by design pre-fix (the bug-1624 contract) | pass |
| A4 (blocked-contract composition) | RED — the unit's refactor spawned in phase 1 (the `--exempt-behaviors` half held as designed) | pass |
| A5 (honest stop, no fabricated evidence) | RED — B-001's refactor spawned before the stop | pass |

Red run: `dart test test/plugins/tdd/issue_1652_defer_phase1_refactor_test.dart`
→ `+1 -5` (5 red / 1 green-by-design), recorded BEFORE the driver
change. Green run after the change: `+6`; after the verify remediation
(A1c): `+7 — All tests passed!`. Red test and fix share the commit per
the tdd-profile convention; the red transcript is quoted verbatim in
the cycle log.

The defect is a SCHEDULING defect: the honest red is the eager
phase-1 spawn itself, so the reds assert spawn placement (argv log,
step log, deferral lines) — exactly the observable the fix changes.

## Phase 2 — Test-smell rubric

- Every scheduling assertion is measurable and mechanical: the argv log
  (`tdd refactor <id>` lines), the step log ordering, the exact
  deferral line, the persisted run-state (`done`/`green`/`blocked`).
- Guards assert BOTH directions: A1/A1b/A1c/A2/A4/A5 pin the deferral;
  A3 pins that the resume-window refactor STILL spawns in phase 1
  (a mutant that over-defers is killed — see M4).
- Fixtures are per-test temp dirs torn down in `tearDown`; fast tier
  (`writeProfile: false`) — no real suite spawns anywhere.
- The fake zfa double sits at the process boundary (the same harness
  every driver suite uses); the SUT — the run driver — runs in-process
  through `CliRunner.runCapturing`. No test re-implements driver logic.
- The A1c fixture shape (`skip-fail`) is an additive fake-zfa config
  token in the shared helper; no existing case changed.

No material smells.

## Phase 3 — Mutation sampling (rubric fallback; no CI mutation gate)

Changed region: `_driveBehavior` in `run_driver_core.dart` — the
`madeGreenThisDrive` flag, its two assignments, and the one-disjunct
gate extension. One mutant at a time against the new suite, `cmp`-
verified restore after each (`cmp` against the pristine copy),
re-run green after restoration.

| Mutant | Change | Result |
| -- | -- | -- |
| M1 | gate drops `madeGreenThisDrive \|\|` (reverts to the pre-feature predicate) | **killed** (`+1 -5`: A1, A1b, A2, A4, A5 red; A3 survives — the window guard, by design) |
| M2 | generic success path stops setting the flag | **killed** (`+1 -5` incl. A1b — an exit-0 `skipped` token grades as SUCCESS, so it flows through the generic path) |
| M3 | skip/adopt terminal arm stops setting the flag (the bug-986 exit-disagree arm) | pass 1 **SURVIVED** (`+6`) — no test drove the exit-disagreeing skip shape. Remediation: fake-zfa `skip-fail` token + test A1c. Re-run: **killed** (`+0 -1`, A1c red — the deferral line absent) |
| M4 | gate over-defers: `madeGreenThisDrive` → `true` (resume window included) | **killed** (`+4 -1`: A3 red — the resume re-entry must NOT defer) |

Final score: **4/4 killed** after one remediation pass (A1c), 0 timed
out; restoration `cmp`-verified; suite re-run green (`+7`) after
restoration.

## Phase 4 — Acceptance-criteria coverage

| SC | Evidence |
| -- | -- |
| SC-1 zero phase-1 refactor spawns, deferral lines, DONE through the batch | A1/A1b/A1c red→green; A1 post-fix transcript in the cycle log (`deferred (phase 2)` ×2, then the batch's `clean (phase 2)` ×2, `result=complete ... done=2`) |
| SC-2 all makes precede all refactors; every spawn carries `--pass-batch`; completion | A2 (argv-order assertion + per-line flag assertion) |
| SC-3 resume-window phase-1 spawn preserved | A3 + the existing bug-1624 test (`bug_1588_phase2_refactor_batch_and_parked_exempt_test.dart`) passing UNMODIFIED |
| SC-4 adjacent suites | two_cycle 21/21 (pinned sequences updated — they pinned exactly the removed scheduling; update documented in the cycle log); `bug_922`, `bug_1652` (command + driver), `run_driver_1652_make_post_state` all pass UNMODIFIED. Full fast-tier TDD scope re-run: commands 495 pass (+1 PRE-EXISTING failure, below), scenarios+services 1097, root tdd files 500, writers+setup 64 |
| SC-5 per-behavior refactor cost after make | driver-level: the deferral spawns NOTHING between make-green and the batch (argv log empty of refactors there) — zero preflight/registry cost, a print + state save; batch economics carried by the UNMODIFIED #1588 command-level suite (suite-spawn counting via the logging wrapper) and the #1662 record suite. Per the spec's Assumptions the zcalc ≤5 s claim is verified at this driver level |
| SC-6 analyze + format | `dart analyze` on the three changed files: `No issues found!`; `dart format --set-exit-if-changed`: clean |

## Findings carried to the PR (not remediation — the audit passes)

1. `bug_1303_dep_override_preflight_test.dart` ("stale path override
   stops the meta run before ANY lane step") fails on CLEAN `master`
   too — verified by stashing this branch's driver change and re-running
   the test against the unmodified file (same `+495 -1`). Pre-existing,
   unrelated to the deferral, flagged for the maintainer.
2. The accepted trade-off (recorded in the digest-gate verification as
   well): a cross-behavior regression introduced by behavior k's make
   now surfaces at the phase-2b batch pass instead of behavior k's
   eager phase-1 refactor — the run still fails honestly, one gate
   later, at at-most-one full pipeline per lane per run instead of N.
3. The `skip-fail` fake-zfa token is test-infra-only (shared helper,
   additive case); production make skip logic is untouched (hard
   constraint honored).

## Final gate verdict

**PASS** — TDD discipline proven (spawn-scheduling reds recorded before
the fix, guards green-by-design recorded honestly), mutation sampling
4/4 killed after one remediation pass, acceptance criteria covered,
full TDD fast-tier scope green (one pre-existing master failure
documented and isolated).
