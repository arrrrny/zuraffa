# TDD Verification Ledger — tdd-refactor-preflight-full-suite

This file is a per-round ledger: each fix round appends its verification
below, preserving earlier rounds verbatim. The LATEST round (top) is the
current verdict for this bug record.

---
---

# TDD Verification — fix(922): refactor preflight excludes pre-existing red
# from done gate

- **Slug**: tdd-refactor-preflight-full-suite
- **Feature (bug dir)**: .specify/bugs/tdd-refactor-preflight-full-suite
- **Branch**: fix/922-refactor-preflight-preexisting-red
- **Verified**: 2026-09-03
- **Cycle log**: ./cycle-log.md (red + green evidence, real runs)
- **Reproduction suite**: test/plugins/tdd/bug_922_refactor_preflight_baseline_test.dart
- **Verdict**: **passed** — all four mutants killed, test-first evidence
  complete, acceptance criteria covered. Pre-existing red exists in the
  repo's slow tier and is documented below; it does not touch the fix.

## 1. Test-first evidence (FR: red before green)

The fix was driven red-first; the reproduction suite was written and
executed BEFORE the implementation changed.

- RED (pre-fix): `dart test
  test/plugins/tdd/bug_922_refactor_preflight_baseline_test.dart
  --preset=all` → 7 failing / 1 passing. The end-to-end test reproduced the
  exact issue #922 signature against the REAL CLI (exec forwarder to
  `bin/zfa.dart`, real `dart test` suites, real pass registry):
  `result=stopped pending=0 red=0 green=1 done=0
  stopped_at=B-001:refactor`. The five command-level tests failed on the
  then-nonexistent `--suite-baseline` option; the driver argv test failed
  because refactor spawns did not receive the run baseline.
- GREEN (post-fix): same suite → 9/9 passing. The end-to-end run completes:
  `result=complete pending=0 red=0 green=0 done=1`,
  run-state `{"B-001": "done"}`.
- Evidence integrity: both runs are recorded verbatim in ./cycle-log.md;
  neither was re-derived after the fact. The pre-fix output was captured in
  the same session, on the same branch, before the first implementation
  edit (git history is the witness).

## 2. Mutation results (real runs — mutate, test, record, revert)

Four representative mutants were applied to the changed code, one at a
time; the reproduction suite ran against each. Every mutant was killed.

| Mutant | File | Change | Targeted run | Verdict |
|--------|------|--------|--------------|---------|
| M1 | refactor_command.dart | preflight verdict inverted (`newFailures.isEmpty` → `isNotEmpty`) | baseline-tolerance group | **killed** (3 failed: tolerance tests see refusals; new-failure test sees a pass-through) |
| M2 | refactor_command.dart | re-proof parseable guard dropped (`reproofSnapshot.parseable &&` removed) | unparseable-re-proof test | **survived first pass → test strengthened → killed** |
| M3 | step_runner.dart | refactor removed from the baseline handoff (`step == 'make' \|\| step == 'refactor'` → `step == 'make'`) | driver argv test | **killed** (refactor spawn no longer carries `--suite-baseline`) |
| M4 | refactor_command.dart | tolerated-failure counter zeroed (`preflightTolerated = preflightSnapshot.failedTests.length` → `= 0`) | re-proof evidence test | **killed** (evidence would claim `green` instead of `tolerated N … (issue #922)`) |

M2 remediation (recorded honestly per the remediation loop): the original
suite never reached an unparseable RE-PROOF transcript (the unparseable
test died at the preflight), so the re-proof parseable guard was
untested. A new test (`an UNPARSEABLE re-proof transcript is a regression,
never baseline-tolerated`) drives a two-phase suite spy — parseable
baseline-matching red at preflight, garbage at re-proof — and asserts
`outcome=regression` with `test/` byte-identical. Re-applied M2 against the
strengthened suite: killed. Final mutant score: **4/4 killed, 0 survived,
0 timed out.**

## 3. Test-smell rubric

- Assertion-Poor Tests: none — every test asserts outcome tokens
  (`outcome=clean` / `not-green` / `regression`), exit codes, argv
  contracts, run-state files, and file-tree checksums, not just "no
  exception".
- Tautological assertions: one was introduced during the M2 remediation
  (`expect(fx.checksumTestTree(), equals(fx.checksumTestTree())))` —
  caught in review and replaced with a real before/after snapshot before
  commit. None remain.
- Fixed-vs-live mismatch: the command-level tests run the REAL `dart test`
  in temp fixtures; the driver tests use the scripted fake zfa (the
  repo's standard two-tier discipline); the end-to-end test runs the REAL
  refactor through an exec forwarder (the sc_017 pattern). No test mocks
  the unit under test.
- Hidden ordering: the two-phase re-proof test counts its own invocations
  from a log file; no sleep/timeout coupling.
- Evidence honesty: the refactor's cycle-log evidence records
  `preflight: tolerated N pre-existing failure(s) (issue #922)` instead of
  claiming an absolute green that did not exist (M4 pins this).

## 4. Acceptance-criteria coverage (issue #922 "Expected")

| Issue #922 expectation | Where proven |
|------------------------|--------------|
| Mark behaviors done when make returns green even if the refactor preflight fails for suite-wide reasons | e2e test: green behavior + baseline-red suite → `result=complete`, `done=1` (with the real refactor in the loop) |
| Refactor preflight uses baseline-recorded pre-existing red instead of refusing | command tests: only-baseline-red tolerated (`outcome=clean`), NEW failure refuses (`outcome=not-green` naming it) |
| Run continues past suite-wide refactor refusals | e2e + driver tests: spawned refactor receives `--suite-baseline` (argv asserted); genuine refusals still skip with a recorded reason (existing #734 v2 behavior preserved) |
| Re-proof treats same-as-baseline red as "no regression" | re-proof tolerance test with applied passes → `outcome=refactored`, exit 0 |
| 13 green behaviors marked done | the 13-behavior count is the consumer repo's fixture (spec 004, not committed here); the mechanism is proven at N=1 (e2e, real refactor) and N=3 (driver suites unchanged, still complete). The fix scales per-behavior: every green behavior's refactor now passes the same gate. |
| verification.md produced even with pre-existing failures | this file; the pre-existing failures are enumerated in §5 and do not gate the verdict |

## 5. Pre-existing failures (repo baseline — NOT introduced by this fix)

Verified by `git stash` + re-run on the pristine master tree; identical
results with and without the fix:

- `test/plugins/tdd/run_command_test.dart` — bug #691 unexpected-green
  skip test (1 failure, slow tier).
- `test/plugins/tdd/make_command_test.dart` — bug 657 unexpressible-hint,
  U-829g/U-829h entity-pipeline, SC-004 no-compose (4 failures, slow tier).
- `examples/todo_tdd/` — `dart analyze` errors from never-committed
  generated artifacts (47 issues, all inside `examples/`).

The fast tier (`tools/run_tests_chunked.sh`, 68 chunks) passes 100% with
the fix applied. `dart analyze lib test bin` → 1 pre-existing warning
(unused import, `test/commands/entity_help_test.dart`, untouched).

## 6. Contract guardrails preserved

- Standalone `zfa tdd refactor` (no `--suite-baseline`) keeps the
  absolute-green preflight (spec 048 FR-001) — regression test included;
  the `--skip-preflight` flag remains nonexistent (FR-002, existing test).
- A missing/corrupt baseline cache falls back to the absolute-green
  contract (safe failure, never a silent pass).
- An unparseable red transcript is never baseline-tolerated, at preflight
  or re-proof (M2's strengthened test).
- The existing issue #741 / #731 / #734-v2 / bug #828 / bug #829 suites
  all pass unchanged.

---
---

# Prior round (preserved verbatim): bug #734 v2 — refactor preflight refusals are per-behavior information, not pass-fatal (reopened)

> Everything below this line is the previous round's verification.md, kept unchanged for provenance (branch fix/734-v2-refactor-preflight-full-suite).

feature: tdd-refactor-preflight-full-suite
verdict: PASS_WITH_GAPS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md # rubric graded against
verified_at: 14651299 (branch fix/734-v2-refactor-preflight-full-suite, pre-commit)
behaviors: 4
proven: 3
likely: 0
test_after: 1
no_test: 0
high_smells: 0
criteria_total: 3
criteria_covered: 3
mutation_score: n/a # no mutation tool in profile; deliberate mutants 3/3 caught, restored, re-run green
mutants_survived: 0
suite: v2 driver tests 3/3 RED pre-fix -> 4/4 GREEN post-fix; run_command file 34/35 green (the 1 being the KNOWN pre-existing bug-691 master failure, Findings #3 of the previous report); tdd plugin folder 599/613 (all 14 failures classified pre-existing-on-pristine / documented-sandbox-e2e / load-flake, zero introduced); real-CLI repro on live fixtures: the issue's deadlock block verbatim pre-fix -> pre-spawn deferral + honest per-behavior refusal record post-fix (V1) and defer + phase-2b skip + honest stopped (V3); refactor_command_test.dart 100% green (standalone FR-001 refusal intact, refactor_command.dart byte-untouched); dart analyze: No issues found; dart format lib/ test/: 0 changed

# TDD Verification: bug #734 v2 — refactor preflight refusals are per-behavior information, not pass-fatal (reopened)

**Verdict: PASS_WITH_GAPS.** The reopen is real and reproducible on pristine master at
two levels: (1) three new driver tests fail on pristine master with the reopened
signature (a refactor spawn into a knowingly-red suite, then the pass-fatal
`not-green` stop), and (2) a real-CLI scratch repro (real `zfa tdd run` spawning the
real `zfa tdd refactor` against a real `dart test` suite with a red
`UnimplementedError` stub on disk and no registry record) prints the issue's
reproduction block verbatim — `[run] A1 refactor -> not-green … preflight exit: 1 …
result=stopped … stopped_at=A1:refactor` — with the pending stub row never attempted.
Post-fix: the deferral engages BEFORE the spawn (the disk check catches the
registry-less stub), the pending row is attempted, and a residual refusal is recorded
per behavior (defer in phase 1, skip with a recorded reason in phase 2b) instead of
stopping the pass for every other behavior. The same repro scripts that deadlock on
pristine master complete their refactor windows honestly post-fix, and the standalone
`zfa tdd refactor` refusal contract (spec 048 FR-001/FR-002) is untouched.

## Scope

Bug fix, not a feature: the audit covers the branch's changed files
(`lib/src/plugins/tdd/commands/run_command.dart`,
`test/plugins/tdd/run_command_test.dart`) and the reopened issue's three criteria
(issue §Verification), graded against the rubric. The previous report
(git history, written at 49496d55) covered the original fix; this report overwrites
it for the reopened fix per the verify contract.

## Test-first evidence

The four v2 tests were written FIRST and run against pristine master (stash/unstash,
this session):

| # | Test (run_command_test.dart) | Pre-fix (pristine master) | Post-fix | Class |
| --- | --- | --- | --- | --- |
| B1 | refactor defers while a pending behavior has a red stub on disk WITHOUT a registry record | RED — `stepInvocations[0]` is `refactor A1` (spawn into the knowingly-red suite) instead of `gen U1`; exit 1 | GREEN — deferral engages pre-spawn, order `gen U1 → … → refactor A1`, result=complete | PROVEN |
| B2 | a phase-1 refactor whose preflight refuses (not-green) defers instead of stopping the run | RED — exit 1, `step failed — behavior=A1 step=refactor outcome=not-green`, U1 never driven | GREEN — spawn → refuse → DEFER, pending row driven, deferred refactor completes in phase 2b, result=complete | PROVEN |
| B3 | a phase-2b refactor whose preflight refuses is skipped with a recorded reason while the rest of the pass completes | RED — pass dies AT `refactor A1`; `refactor U1` never spawns | GREEN — refusal skip recorded (`[run] A1 refactor -> skipped (suite not green)`), pass continues, honest `result=stopped … stopped_at=A1:refactor` with the resume path | PROVEN |
| B4 | a refactor regression (re-proof failure) still stops the run honestly | GREEN (boundary guard by design — passes pre- AND post-fix) | GREEN | TEST_AFTER (guard written with the fix to pin the conservative boundary; it is a regression pin, not a behavior driver) |

Real-CLI evidence (scratch repro, `scripts/repro_734_real.sh` outside the repo, real
`dart pub get` + real `dart test` suites):

- **V1 pre-fix (pristine master)**: `[run] A1 refactor -> not-green` /
  `zfa tdd run: step failed — behavior=A1 step=refactor outcome=not-green` /
  `preflight exit: 1` / `result=stopped pending=1 red=0 green=2 done=0
  stopped_at=A1:refactor` — the issue's reproduction block verbatim; the run's own
  #741 baseline line names the 1 pre-existing failure (u2's stub) that the pre-spawn
  deferral failed to see.
- **V1 post-fix**: `[run] A1 refactor -> deferred (phase 2)` +
  `[run] U1 refactor -> deferred (phase 2)` + U2 ATTEMPTED (gen runs — never reached
  pre-fix) → the real FR-008 ownership conflict is named → honest stop at
  `U2:gen` with the resume path. No not-green refusal, no A1:refactor deadlock.
- **V3 pre-fix**: pass-fatal refusal on the only behavior (outside-red suite).
- **V3 post-fix**: spawn → not-green → `deferred (phase 2)` → phase-2b re-spawn →
  `skipped (suite not green)` → `refactor skipped for A1 — suite not green` +
  `resume: restore the suite green … then re-run` → honest `result=stopped`.
- **Standalone regression**: `refactor_command.dart` is byte-untouched
  (`git diff` names exactly the two files above); `refactor_command_test.dart`
  passed 100% in the folder run (0 `[E]` across all US1–US4 cases including
  U14/A2 red-suite refusal and FR-002 no-flag).

## Findings

Ordered by severity. No `HIGH` findings.

| # | Severity | Finding | Evidence |
| --- | -------- | ------- | -------- |
| 1 | MED | The phase-2b refusal skip records the behavior's id and the `suite not green` reason, but the SKIPPED BEHAVIOR's own failing-test names are only in the spawn's output excerpt, not structured in the summary line. An operator triaging a 40-behavior feature reads the excerpt above the summary, not a per-behavior list. Deliberate scope cut: the spawned refactor already prints the failing tests (named) into the run transcript; threading parsed names into the summary would duplicate refactor's own `_extractFailingTestNames` into the driver | `_driveBehavior` refusal branch (`_printOutputExcerpt(result.output)`); end-of-run block |
| 2 | LOW | The pre-spawn disk check probes only the gen DEFAULT layout (`test/tdd/<snake_id>_test.dart`). A stub at a non-default path (a custom `test_path` written by an older pipeline) is invisible pre-spawn and handled post-spawn instead (one wasted suite run, then the honest skip). Acceptable: without a registry record the driver cannot know a custom path; the safety net bounds the cost | `_hasPendingWithArtifacts` disk branch |
| 3 | LOW (pre-existing, NOT introduced by this branch) | `run_command_test.dart` "bug #691: verify-red reporting unexpected-green…" fails on PRISTINE master (re-confirmed by stash this session): the bug #682 bootstrap promotes B-001 to DONE on its red+green evidence, so the #691 skip-to-make path is never exercised. Same finding as #3 of the previous report; still needs its own assessment | failure reproduced with the fix stashed |
| 4 | LOW (environment) | The tdd plugin folder run (concurrency 2, `--preset=all`) shows 14 failures, ALL classified non-attributable: (a) re-confirmed on pristine master by stash — make bug-657 message content, make spec-052 A11/U17, generation_planner_real_cli bug #696 (30s real-CLI timeout); (b) documented sandbox e2e (real build_runner misfire) — sc_011.A6, sc_012.A1, sc_012.A9 (previous report Findings #4); (c) load-flake, passing in isolation on BOTH trees — runner U11, gen honest-red, sc_019.U3 (explicitly re-run green on both), sc_018, sc_019.A6/B1 by family; (d) bug #691 (Finding #3). Zero failures introduced | stash/unstash baselines, isolation re-runs |
| 5 | LOW | Same-session audit (Hard Rule 2): the tests and the fix were written in this session, so the smell pass is not independent. Mitigation: the four v2 tests follow the file's established fake-zfa harness and assertion style verbatim, and the mutant pass was executed blind against the assertions before results were recorded | session transcript |

## Test strength (deliberate mutants)

No mutation tool in the profile; three deliberate mutants, applied ONE AT A TIME to
the changed driver logic, each restored byte-identical and the targeted suite re-run
green after the restore:

| Mutant | Change | Test | Result |
| --- | --- | --- | --- |
| M1 | Invert the phase check in the refusal branch (`if (!deferralAllowed)` defers) | B2 | CAUGHT — `Expected: contains '[run] A1 refactor -> deferred (phase 2)'` failed (phase-1 refusal took the skip path; run stopped) |
| M2 | Disable the disk check in `_hasPendingWithArtifacts` (`if (false && …)`) | B1 | CAUGHT — `at location [0] is 'refactor A1' instead of 'gen U1'`: the exact reopened spawn-into-red-suite signature |
| M3 | Sever the wiring (`refactorBlocked: true` → `false` on the phase-2b return) | B3 | CAUGHT — exit 2 (`internal error — runner-error`) instead of the honest stopped(1): the pass treated the refusal as success and hit the driver's own invariant guard |

Mutants survived: 0. Restore verified: `git diff` clean of mutant markers; the
targeted tests re-run green after each restore.

## Traceability

| Issue criterion (expected behavior) | Behavior(s) | Test(s) / evidence |
| --- | --- | --- |
| "A run that processes A1-A5 + U1-U2 then stops (any reason) should still be able to refactor those 7 behaviors" — refactors of already-green behaviors must not be blocked by pending U3+ stubs (issue §Verification) | B1, B2 | B1 (registry-less disk stub: deferral pre-spawn → pending row driven → complete); real-CLI V1 (pre-fix deadlock verbatim → post-fix deferrals + U2 attempted); the original #734 tests (registry-record state) still green |
| "Refactor for A5 should pass if `dart test test/tdd/a5_test.dart` exits 0, even if `dart test` (full) fails due to U3+" (issue §Verification) | B2, B3 | Driver-layer remediation per the original assessment's preferred path: phase 1 keeps refactor spawns out of every knowingly-red context the driver can see (RED rows; pending rows with artifacts in the registry OR on disk) and records residual refusals per behavior without stopping the pass; phase 2b skips them with a recorded reason and the honest end-of-run resume path. The spawned command's full-suite preflight (spec 048 FR-001) remains the absolute authority; the strict "refactor RUNS despite a red full suite" reading would require a spec-048 amendment and is documented as out of scope (regression-analysis-v2.md) |
| "Standalone `zfa tdd refactor` still refuses on a red full suite (regression for spec 048 FR-001)" (assessment §Tests to add or update) | — | `refactor_command.dart` untouched (git diff: exactly run_command.dart + its test); `refactor_command_test.dart` 100% green in the folder run (U13/U14/U15/U22, FR-002, A4-A12) |
| Assessment v2 §Remediation honored: (1) widen the pre-spawn model with the disk check; (2) make residual refusals non-fatal (defer phase 1 / skip phase 2b); regression/runner-error/missing-summary stay fatal | B1-B4 | B1 pins (1); B2+B3 pin (2); B4 pins the conservative boundary (`regression` still stops the run) |

## What was not audited

- The pre-existing bug-691 test failure (Finding #3) was re-confirmed on pristine
  master but NOT fixed or assessed here; one PR per bug.
- The load-flaked folder-run failures (Finding #4c) were verified green in isolation
  on both trees but not root-caused as to their contention sensitivity; the
  real-pipeline e2e family (sc_011/012/017/018/019) remains sandbox-hostile
  (previous report Findings #4) and was not triaged further.
- `tools/run_tests_chunked.sh` (fast tier) was executed this session and its result
  is recorded in the PR; the heavy presets beyond the tdd plugin folder were not run
  in this sandbox beyond the folders listed.
- Mutation testing used deliberate mutants on the changed driver logic only; no
  mutation tool ran, and no mutants were applied to untouched files.
- The examples/ subtree's pre-existing `dart format` drift (a formatter-version
  difference visible on pristine master, outside lib/ + test/) was deliberately
  left out of this branch's diff.
