---
feature: tdd-refactor-preflight-full-suite
verdict: PASS_WITH_GAPS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md # rubric graded against
verified_at: 49496d55 (branch fix/734-tdd-refactor-preflight-full-suite, pre-commit)
behaviors: 4
proven: 2
likely: 0
test_after: 2
no_test: 0
high_smells: 0
criteria_total: 3
criteria_covered: 3
mutation_score: n/a # no mutation tool in profile; deliberate mutants 3/3 caught
mutants_survived: 0
suite: new driver tests 2/2 RED pre-fix -> GREEN post-fix; run_command + path-format + sc_013..016 51/51 green (1 pre-existing master failure excluded, see Findings #3); chunked fast tier 66 chunks, 2461 cases, 0 failed, "OK: all chunks passed"; sc_010 standalone-refactor regression 3/3 green; dart analyze: No issues found; real-CLI repro on a live fixture: deadlock verbatim pre-fix -> deferral + bounded honest progress post-fix
---

# TDD Verification: tdd run defers refactor past pending-with-artifacts rows and gates phase-2b refactor per behavior (#734)

**Verdict: PASS_WITH_GAPS.** The deadlock is real and the fix is proven at three
levels: (1) both new driver tests fail on pristine master with the exact #734
signature and pass post-fix; (2) a real-CLI scratch repro (real `zfa tdd run`
spawning the real `zfa tdd refactor`, real `dart test` suite, red
`UnimplementedError` stub on disk) prints the issue's reproduction block
verbatim pre-fix — `[run] A1 refactor -> not-green … preflight exit: 1 …
result=stopped … stopped_at=A1:refactor` with 3 green behaviors blocked — and
post-fix defers all three refactors (`[run] A1/U1/U2 refactor -> deferred
(phase 2)`), drives the pending behavior through gen → verify-red → make, and
stops honestly at that behavior's own genuine blocker with the greens
resumable; (3) 3/3 deliberate mutants caught. `refactor_command.dart` is
byte-untouched, so the standalone full-suite preflight (spec 048 FR-001/FR-002)
is unchanged and sc_010 still pins the refusal. Gaps: same-session audit, the
phase-2b gate keys on the certified green evidence rather than a live test run
(deliberate — see Findings #2), and two environment-bound test groups were not
independently triaged (Findings #3, #4).

## Test-first evidence

| Behavior | Class | Evidence |
| -------- | ----- | -------- |
| B1 — phase-1 refactor defers while ANY behavior sits PENDING with gen artifacts (bug #734 extends the bug #635 deferral); the run drives the pending behavior first, then refactors on the now-green suite | PROVEN | RED first: `run_command_test.dart` "bug 734: refactor defers…" fails on pristine master — actual spawn order `refactor A1, refactor U1, refactor U2, gen U3, …` (refactors attempted while U3's generated stub sits red — the real preflight refuses, the recorded deadlock) instead of the expected `gen U3, …, refactor A1…`, and no `deferred (phase 2)` lines. Post-fix: exact expected order + 3 deferral lines + `result=complete … done=4`. Corroborated by the real-CLI repro below |
| B2 — phase-2b gates refactor PER BEHAVIOR on that behavior's own test being green (its certified green evidence, decided BEFORE the spawn); a green claim without green evidence is skipped with a recorded reason, stays GREEN, and the run reports `result=stopped … stopped_at=<id>:refactor` with a resume path instead of dying at the post-spawn evidence misfire | PROVEN | RED first: the gate test fails on pristine master with the misfire signature — `[run] A1 refactor -> clean` then `step failed … outcome=runner-error` ("refactor certified but evidence for \"A1\" is incomplete (red: true, green: false)"), `result=runner-error … stopped_at=A1:refactor`, exit 2, U1/U2 never refactored. Post-fix: `[run] A1 refactor -> skipped (own test not green)` + reason line, no `refactor A1` spawn, `refactor U1 -> clean (phase 2)`, exit 1, `result=stopped pending=0 red=0 green=1 done=2 stopped_at=A1:refactor`, state `{A1: green, U1: done, U2: done}` |
| B3 — standalone `zfa tdd refactor` still refuses on a red full suite; no `--skip-preflight` (spec 048 FR-001/FR-002 unchanged) | TEST_AFTER | regression guard: `refactor_command.dart` is byte-untouched by the branch diff (`git diff --stat` = run_command.dart + run_command_test.dart only); sc_010 (real red-suite refusal, real runner-error path, FR-002 flag rejection) 3/3 green post-fix; refactor_command_test.dart green post-fix. The change cannot have altered the standalone contract — the file never changed |
| B4 — pre-existing driver contract window unchanged: phase-1 refactors still spawn for artifact-less pending rows (fresh-run ordering, U19), the bug #635 RED deferral still engages, phase-2 make windows and state semantics unchanged | TEST_AFTER | existing suite green post-fix: run_command_test.dart U19/U20/U21/U22/U23/U24/U27/U28/U29 + bug-625/bug-635 trio + FR-008 pass unchanged (35/36; the 1 failure is the pre-existing bug-691 case, Findings #3); sc_013..016 16/16; path-format suite green |

No pre-existing test was weakened: the only test-file changes are two ADDED
`test(...)` blocks plus their seeds; zero assertions edited, zero tags added,
zero skips introduced (`git diff test/plugins/tdd/run_command_test.dart` shows
only insertions).

## Real-CLI repro (scratch fixture, deleted after capture)

Fixture: temp project with pubspec (`test` dep) + `dart pub get`,
`.specify/memory/tdd-profile.md` (suite `dart test`), 4-row test list
(A1 acceptance; U1-U3 unit), artifacts.json for all four, cycle-log with
red+green evidence for A1/U1/U2, run-state `{A1,U1,U2: green, U3: pending}`,
green test files for A1/U1/U2 and a RED `UnimplementedError` stub for U3
(canonical `test/tdd/u3_test.dart` layout). Invoked as
`dart run <repo>/bin/zfa.dart tdd run 004-forklift --project <fixture>` — the
driver spawns the REAL step commands; every refactor spawn runs the REAL
full-suite preflight.

- Pre-fix (lib change stashed): `[run] A1 refactor -> not-green` /
  `zfa tdd refactor: preflight suite / command: dart test / preflight exit: 1` /
  `result=stopped pending=1 red=0 green=3 done=0 stopped_at=A1:refactor`, exit 1
  — the issue's Reproduction block verbatim (A1 stands in for the reported A5;
  U3 was never driven).
- Post-fix: `[run] A1 refactor -> deferred (phase 2)` ×3, then
  `[run] U3 gen -> ok`, `[run] U3 verify-red -> certified`,
  `[run] U3 make -> generation-error` (U3's own genuine planner mismatch in the
  scratch fixture — the honest blocker), `result=stopped pending=0 red=1
  green=3 done=0 stopped_at=U3:make`, exit 1 — bounded, resumable progress
  instead of the deadlock; the refactors of the green behaviors are no longer
  blocked and run in phase 2b once the pending row resolves.

## Deliberate mutants (no mutation tool in the profile; mutants on the changed driver logic)

| # | Mutant (one small change, restored exactly after) | Result |
| --- | --- | --- |
| 1 | `\|\| await _hasPendingWithArtifacts(…)` replaced by `\|\| false` (the bug #734 deferral condition dropped — pre-fix behavior restored in place) | CAUGHT — both new tests fail: spawn order degrades to `refactor A1` before `gen U3` (the #734 signature) and the gate test sees `runner-error` instead of the skip. Restored exactly; bug-734 pair re-ran green |
| 2 | Phase-2b gate inverted: `!certifiedGreen.contains(id)` → `certifiedGreen.contains(id)` | CAUGHT — gate test fails (skips the certified behavior, refactors the uncertified one). Restored exactly |
| 3 | Skip path fakes DONE: `current = current.advance(id, BehaviorState.done)` inserted before the skip print (FR-008 violation) | CAUGHT — gate test fails: run reports `result=complete`, exit 0 instead of the honest `result=stopped`, exit 1. Restored exactly; restore verified byte-identical against the saved fix diff, pair re-ran green |

## Findings

Ordered by severity. No `HIGH` findings.

| # | Severity | Finding | Evidence |
| --- | -------- | ------- | -------- |
| 1 | MED | The phase-2b per-behavior gate keys on the CERTIFIED green evidence (the cycle-log entry make appended when the behavior's test target exited 0), not on a live re-run of the test file. Deliberate: a live run per behavior per pass would spawn `dart test` N times per phase-2b pass (the profile has no file-scope template loader; the single template keys on a test name), the fake-zfa driver harness has no `dart pub get` in its fixtures (a live gate would misclassify every fixture test as red), and a stale green that regresses after make is still caught downstream by the spawned refactor's own full-suite preflight (FR-001) — the gate's job is to keep ONE uncertified behavior from stopping the pass for everyone, which the evidence key does with zero new subprocesses | gate comment in run_command.dart; `_evidenceMisfire` refactor branch (the pre-fix post-spawn failure this replaces) |
| 2 | LOW | The deferral check consults the registry per refactor-coming-due (O(rows) JSON reads per behavior). At the reported scale (49 behaviors) this is negligible; flagged only as a future cache candidate if features grow 10x | `_hasPendingWithArtifacts` implementation |
| 3 | LOW (pre-existing, NOT introduced by this branch) | `run_command_test.dart` "bug #691: verify-red reporting unexpected-green…" fails on PRISTINE master (verified with the fix stashed at 49496d55 AND at 8c80bdcd): the bug #682 bootstrap promotes B-001 to DONE on its red+green evidence (no run-state seeded), so the #691 skip-to-make path is never exercised. Out of scope here — one PR per bug; needs its own assessment/fix | failure reproduced pre-fix in this session; assertion wants `[run] B-001 verify-red -> unexpected-green`, actual output shows `1 already done — skipping` |
| 4 | LOW (environment) | sc_011/sc_012/sc_017 (real-pipeline refactor e2e) fail in this sandbox BOTH pre- and post-fix (identical count): the real `build` pass misfire-stops inside the container. Not triaged here — they pass in the project's own CI per the #720 verification record, and the failure is independent of the driver change (the driver never touches RefactorPasses) | pre/post-fix runs both +3 failed / identical signatures |
| 5 | LOW | Same-session audit (Hard Rule 2): the tests and the fix were written in this session, so the smell pass is not independent. Mitigation: both tests follow the file's established fake-zfa harness and assertion style, and the mutant pass was executed blind against the assertions before results were recorded | session transcript |

## Traceability

| Issue criterion (expected behavior) | Behavior(s) | Test(s) / evidence |
| --- | --- | --- |
| "A run that processes A1-A5 + U1-U2 then stops (any reason) should still be able to refactor those 7 behaviors" — refactors of already-green behaviors must not be blocked by pending U3+ stubs (issue §Verification) | B1, B4 | `run_command_test.dart` bug-734 deferral test (order + deferral lines + complete); real-CLI repro (pre-fix deadlock verbatim → post-fix deferral + U3 driven); U19 pins the fresh-run artifact-less ordering as unchanged |
| "Refactor for A5 should pass if `dart test test/tdd/a5_test.dart` exits 0, even if `dart test` (full) fails due to U3+" (issue §Verification) | B1, B2 | phase-1 deferral keeps refactor spawns out of knowingly-red contexts; phase-2b per-behavior gate refactors exactly the behaviors whose own test is certified green and skips the rest with a recorded reason instead of a mid-pass runner-error |
| "Standalone `zfa tdd refactor` still refuses on a red full suite (regression for spec 048 FR-001)" (assessment §Tests to add or update) | B3 | `refactor_command.dart` untouched (git diff); sc_010 3/3 (red-suite refusal + FR-002 no-flag) + refactor_command_test green post-fix |
| Assessment §Files likely to change honored: driver gate logic + comment in run_command.dart; phase-2b scenario in run_command_test.dart | B1, B2 | `git diff --stat`: exactly those two files |

## What was not audited

- The pre-existing bug-691 test failure (Findings #3) was diagnosed but NOT
  fixed or assessed here; it reproduces on pristine master and predates this
  branch.
- sc_011/sc_012/sc_017 real-pipeline e2e failures in this sandbox (Findings
  #4) were confirmed pre-existing but not root-caused; no CI-independent
  verdict on them is claimed.
- The heavy presets (`--preset=all` beyond the folders run here, regression/
  integration/property tiers) were not run in this sandbox beyond the listed
  folders; the fast chunked tier (2461 cases) plus the TDD slow tier folders
  named above are the recorded baseline.
- Mutation testing used deliberate mutants on the changed driver logic only;
  no mutation tool ran, and no mutants were applied to untouched files.
- The performance of the per-refactor registry reads (Findings #2) was not
  measured.
