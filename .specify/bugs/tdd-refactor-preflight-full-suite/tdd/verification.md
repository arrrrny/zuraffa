---
feature: tdd-refactor-preflight-full-suite
verdict: PASS_WITH_GAPS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md # rubric graded against
verified_at: 8869db5d (branch fix/754-v2-refactor-preflight-full-suite, pre-commit)
behaviors: 4
proven: 3
likely: 0
test_after: 1
no_test: 0
high_smells: 0
criteria_total: 3
criteria_covered: 3
mutation_score: n/a # no mutation tool in profile; deliberate mutants 3/3 caught
mutants_survived: 0
suite: bug-734-v2 driver tests 3/4 RED on pristine master (reopened signature captured verbatim) -> 4/4 GREEN post-fix; run_command_test --preset=all 34/35 (the 1 failure is the pre-existing bug-691 case, reproduced on pristine master via stash in this session); chunked fast tier 66/66 chunks, 2557 cases, 0 failed; dart analyze: No issues found; dart format lib/ test/: 0 changed; refactor_command.dart byte-untouched vs master (git diff = 0 lines)
---

# TDD Verification: run driver tolerates refactor preflight refusals from unmodeled suite redness (#734 reopened as #754)

**Verdict: PASS_WITH_GAPS.** The reopened deadlock is real and the fix is proven at
the driver level in this session: 3 of the 4 new driver tests fail on PRISTINE
master (8869db5d, fix stashed/unapplied) with the exact reopened signature —
`[run] A1 refactor -> not-green`, `zfa tdd run: step failed — behavior=A1
step=refactor outcome=not-green`, `result=stopped pending=1 red=0 green=1 done=0
stopped_at=A1:refactor`, the pending behavior never driven — and all 4 pass
post-fix. The remediation addresses the root cause from
`regression-analysis-v2.md` on two layers: the pre-spawn deferral now sees
on-disk stubs the registry misses (the model gap), and the side-effect-free
preflight refusal becomes per-behavior information (defer in phase 1, skip with
a recorded reason in phase 2b) instead of a pass-fatal stop (the safety net for
redness no row model can see). `refactor_command.dart` is byte-untouched vs
master, so the standalone full-suite preflight (spec 048 FR-001/FR-002) is
unchanged. Gaps: same-session audit (Hard Rule 2), test-after classification of
the regression-guard behavior (it is green both pre- and post-fix by design),
and no real-CLI scratch repro was re-run for the v2 state (the driver-level RED
evidence reproduces the issue's signature exactly; the v1 session's real-CLI
repro is recorded in git history of this file).

## Test-first evidence

| Behavior | Class | Evidence |
| -------- | ----- | -------- |
| B1 — phase-1 refactor defers while any behavior sits PENDING with gen artifacts IN THE REGISTRY OR ON DISK (bug #734 v2 widens `_hasPendingWithArtifacts` to the gen-default test path `test/tdd/<snake_id>_test.dart`) | PROVEN | RED first on pristine master: "bug 734 v2: refactor defers while a pending behavior has a red stub on disk WITHOUT a registry record…" fails — U1's stub file exists on disk with NO registry record, the deferral does not engage, and the run dies at A1:refactor instead of the expected `gen U1 → verify-red U1 → make U1 → refactor U1 → refactor A1` order with `result=complete … done=2`. Post-fix: exact order, `[run] A1 refactor -> deferred (phase 2)`, exit 0, state `{A1: done, U1: done}` |
| B2 — a spawned refactor whose preflight REFUSES (outcome=not-green, side-effect-free) is per-behavior information, not a pass-fatal failure: phase 1 DEFERS (stays GREEN, pending rows still driven, deferred refactor re-spawns in phase 2b); phase 2b SKIPS with a recorded reason (stays GREEN, never a fake DONE) while the pass completes for everyone else | PROVEN | RED first on pristine master, two tests: (a) phase-1 test — actual `step failed — behavior=A1 step=refactor outcome=not-green`, exit 1, `stopped_at=A1:refactor`, U1 never invoked (invocations = `['refactor A1']` where 6 steps expected); (b) phase-2b test — pass dies AT `refactor A1`, `refactor U1` never spawned. Post-fix both pass: (a) `refactor A1 → not-green` then `→ deferred (phase 2)`, U1 driven, phase-2b completes A1, exit 0 `result=complete … done=2`; (b) `→ skipped (suite not green)`, `refactor U1 -> clean (phase 2)` continues, exit 1, `result=stopped pending=0 red=0 green=1 done=2 stopped_at=A1:refactor`, state `{A1: green, U1: done, U2: done}` |
| B3 — the safety net does NOT capture real refactor failures: a `regression` (re-proof failure) still stops the run honestly | TEST_AFTER | regression guard: "bug 734 v2: a refactor regression (re-proof failure) still stops the run honestly" passes BOTH pre-fix (verified in this session's RED run: +1 −3) and post-fix — the guard exists to prove the mutant-kill boundary; it cannot be RED-first against a fix it constrains |
| B4 — pre-existing driver contracts unchanged: the original #734 registry-based deferral, the #635 RED deferral, the phase-2b certified-green gate, U19 fresh-run ordering, FR-007/FR-008 honesty | TEST_AFTER | existing suite green post-fix: run_command_test.dart --preset=all = 34/35 (the single failure is the pre-existing bug-691 case, Findings #2 — reproduced on PRISTINE master via `git stash` in this session, `+0 −1`); dart analyze clean; refactor_command_test suite untouched and green in the chunked fast tier |

No pre-existing test was weakened: the only test-file change is 4 ADDED
`test(...)` blocks (303 inserted lines); zero assertions edited, zero tags
changed, zero skips introduced (`git diff --stat test/plugins/tdd/run_command_test.dart`
= 303 insertions, 0 deletions).

## Deliberate mutants (no mutation tool in the profile; mutants on the changed driver logic, one at a time, each restored byte-identically and re-verified green)

| # | Mutant (one small change, restored exactly after) | Result |
| --- | --- | --- |
| 1 | Deferral operand dropped: `await _hasPendingWithArtifacts(rows, updated, registry, projectRoot: projectRoot)` replaced by `false` in the pre-spawn deferral condition | CAUGHT — 2 of the 4 v2 tests fail (+2 −2): the disk-stub deferral test reverts to the reopened signature and the phase-1 refusal test loses its expected order. Restored byte-identically (`diff` clean vs saved fix); v2 quartet re-ran green |
| 2 | Safety net dropped: `if (step == 'refactor' && result.outcome == 'not-green')` guarded with `false &&` (pre-fix pass-fatal behavior restored in place) | CAUGHT — 2 of the 4 v2 tests fail (+2 −2): the phase-1 refusal defers test and the phase-2b skip test both see the honest-stop path again. Restored byte-identically |
| 3 | FR-008 violation: the not-green advance in phase 2b fakes DONE — `updated.advance(row.id, state)` becomes `advance(row.id, deferralAllowed ? state : BehaviorState.done)` | CAUGHT — the phase-2b skip test fails (+3 −1): final state asserts `{A1: green, …}` but the mutant reports A1 done and `result=complete`-adjacent summaries. Restored byte-identically; v2 quartet re-ran 4/4 green |

## Findings

Ordered by severity. No `HIGH` findings.

| # | Severity | Finding | Evidence |
| --- | -------- | ------- | -------- |
| 1 | MED | Same-session audit (Hard Rule 2): the tests, the fix, and this report were produced in one session, so the smell pass is not independent. Mitigation: the 4 tests were authored against the reopened signature FIRST and executed against pristine master before the fix existed (RED evidence above); they follow the file's established fake-zfa harness (`TddFixture`), seeding helpers, and assertion style; the mutant pass was executed blind, one mutant at a time, against the already-written assertions | session transcript; `git diff test/` = pure insertions |
| 2 | LOW (pre-existing, NOT introduced by this branch) | `run_command_test.dart` "bug #691: verify-red reporting unexpected-green…" fails on PRISTINE master (re-verified this session with the working tree stashed: `+0 −1` at 8869db5d). The #682 bootstrap promotes B-001 to DONE from its red+green evidence, so the #691 skip-to-make path is never exercised. Out of scope — one PR per bug; needs its own assessment | stash-and-run evidence in this session; also documented in the v1 verification (Findings #3) and the v2-branch analysis |
| 3 | LOW | The deferral's disk check (`File(defaultTestPath).existsSync()`) assumes the gen default layout `test/tdd/<snake_id>_test.dart`; a stub at a non-default path still reaches the spawn. Deliberate residual risk by design: the row model cannot enumerate arbitrary layouts, and the post-spawn refusal skip (B2) is the safety net for exactly that class — the behavior is skipped with a recorded reason instead of the pass dying | `_hasPendingWithArtifacts` implementation + `_snakeCase` helper; safety-net tests B2 |
| 4 | LOW | The phase-1 refusal deferral re-spawns refactor in phase 2b even when the suite redness has not cleared; the spawned `zfa tdd refactor` runs its full-suite preflight each time (one extra `dart test` per green behavior per run in the worst case). Cost is bounded by the per-step `--timeout` (bug #742) and matches the pre-existing phase-2b pass behavior; flagged as a future optimization (a run-level refusal cache), not a correctness gap | driver code path: phase-1 defer → phase-2b re-spawn |

## Traceability

| Issue criterion (expected behavior) | Behavior(s) | Test(s) / evidence |
| --- | --- | --- |
| "A run where U8 is green and 36 others are pending should let U8:refactor pass (or skip cleanly)" (issue #754 §Verification) | B1, B2 | phase-1 deferral engages on disk stubs without registry records (B1 test: U1 stub on disk, no record → A1 defers pre-spawn, U1 driven, A1 completes in phase 2b); the refusal, when it still spawns, defers/skips instead of pass-fatally stopping (B2 tests) |
| "Direct `zfa tdd refactor U8` should succeed when `dart test test/tdd/u8_test.dart` passes" — standalone contract unchanged (issue #754 §Verification) | B4 | `refactor_command.dart` byte-untouched vs master (`git diff master -- …/refactor_command.dart` = 0 lines); sc_010 and refactor_command_test run green in the chunked fast tier |
| "The full suite should only be required at the very end (phase 2b absolute green)" (issue #754 §Verification) | B2, B4 | phase-2b refusal skip ends the run honestly (`result=stopped … stopped_at=A1:refactor`, A1 stays GREEN, resume path printed) when the suite cannot go green within the run; FR-008 no-fake-DONE pinned by mutant 3 |
| Assessment remediation honored: driver layer only, refactor_command.dart untouched, spec 048 FR-001/FR-002 unchanged | B3, B4 | `git diff --stat` = run_command.dart + run_command_test.dart + bug-dir records only |

## What was not audited

- The pre-existing bug-691 test failure (Findings #2) was re-confirmed on
  pristine master but NOT fixed or assessed; it predates this branch.
- No new real-CLI scratch repro was run for the v2 state in this session (the
  driver-level RED run reproduces the issue's output block exactly; the v1
  session's real-CLI repro remains in this file's git history). The heavy
  presets (`--preset=all` beyond the single run_command_test.dart file and the
  chunked fast tier; regression/integration/property/benchmark tiers) were not
  run in this sandbox per dart_test.yaml's disk/RAM warnings for disposable
  agents.
- Mutation testing used 3 deliberate mutants on the changed driver logic only;
  no mutation tool ran, and no mutants were applied to untouched files.
- The performance of the per-refactor registry+disk checks (Findings #3/#4)
  was not measured.
