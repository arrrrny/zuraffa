---
feature: tdd-run-clean-state-skips-gen (bugfix #720, branch mode)
verdict: PASS_WITH_GAPS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
verified_at: 078891de
behaviors: 3
proven: 3
likely: 0
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 5
criteria_covered: 5
mutation_score: 100 # scope: the changed guard logic's full decision surface, 3 deliberate mutants (no mutation tool in profile)
mutants_survived: 0
suite: fast tier chunked 61 chunks passed / 5 skipped / 0 failed (2526 test cases); driver suite 28 passed, 1 failed (pre-existing bug #691, fails identically on pristine 078891de); scenario slow tier sc_013 4, sc_014 5, sc_015 3, sc_016 4, sc_018 1 — all passed
---

# TDD Verification: #720 run driver on clean state goes straight to make — skips gen

**Verdict: PASS_WITH_GAPS.** The failing behavior is pinned by a driver test
whose RED was recorded against the pre-fix source (the run reproduces the
issue's exact failure shape: `make B-001` first, no gen), the fix demotes
artifact-less state claims to gen in `_stepsFor` only, and all three deliberate
mutants were caught. Gaps: the branch is a single commit, so git history alone
cannot corroborate test-first ordering (the recorded pre-fix run is the
evidence); mutation was deliberate-mutant sampling, not a tool; and this audit
was produced by the same session that wrote the tests (not independent).

## Root cause (from issue #720, confirmed in source)

`lib/src/plugins/tdd/commands/run_command.dart`, `_stepsFor` (line 476 at
`078891de`): the state-implied start index trusted the `BehaviorState` claim
unconditionally — `red => 2` re-enters at `make`. On a clean state
(`run-state.json`, `artifacts.json`, gen files wiped) with residual red
evidence in `tdd/cycle-log.md` from a prior interrupted run, the #682 bootstrap
promotes the behavior to RED (no in-flight marker), `_stepsFor` returns
`[make, refactor]`, and the real `make` refuses with "no gen artifacts" —
exactly the issue's repro. The #682 bootstrap itself is correct; the sequencer
was the only place trusting a claim the artifacts could not back.

## The fix

`_stepsFor` gains a required `hasGenArtifacts` parameter, computed per
non-DONE behavior in the phase-1 loop via
`ArtifactRegistry(featureDir: featureDir).findRecord(row.id)` — the same
registry contract the real `make` enforces with its "no gen artifacts"
refusal. When there is no in-flight marker (null/empty) and no artifact
record, the state-implied start is demoted to `gen` regardless of state.
Marker precedence (U23) and artifacts-present resume windows are unchanged.
Phase-2 windows are untouched (a behavior can only reach them having run gen
in the same or a prior resumed run). No other file's logic was changed.

## Test-first evidence

| Behavior                                                              | Class  | Evidence                                                                                                                                                                                                                                                                                            |
| --------------------------------------------------------------------- | ------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| B-720a: clean state + residual red evidence starts at gen, not make   | PROVEN | New test recorded RED against pre-fix source: expected `['gen B-001', ...]`, actual `['make B-001', 'refactor B-001', ...]` — the issue's exact failure shape; the fix turns it green with the full 12-step sequence and `result=complete`                                                            |
| B-720b: in-flight marker re-enters at its step even without artifacts | PROVEN | Test green pre-fix and post-fix (a guard that must not regress); MUTANT-3 (artifact check applied over the marker) caught by it                                                                                                                                                                      |
| B-720c: red claim WITH gen artifacts still re-enters at make          | PROVEN | Test green pre-fix and post-fix (the certified-resume contract); MUTANT-2 (condition inverted) caught by it                                                                                                                                                                                          |

Existing-test changes: 7 pre-existing tests (U21, U22, bug 682 ×2 in
`run_command_test.dart`; A4 and bug 625 phase-boundary in `sc_014`; A9 in
`sc_015`) encoded "red claim without artifacts re-enters at make" — the
contract #720 revises. Each was updated by seeding the gen artifacts its
scenario logically presupposes (`registerBehavior`); every expectation,
assertion, and name is unchanged, and none was skipped or weakened. The
artifact-less variants those tests accidentally modeled are now covered by the
dedicated B-720a test. No assertion was removed, loosened, or weakened
anywhere in the diff.

## Findings

| #   | Severity | Finding                                                                                                                                                                                                                             | Evidence                                          |
| --- | -------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------- |
| 1   | LOW      | The "bug #720 demotes artifact-less claims to gen" rationale comment is repeated across the 7 updated tests; a shared fixture-level note would read better                                                                          | `test/plugins/tdd/run_command_test.dart` (U21/U22/682 seeds), `sc_014`, `sc_015` |
| 2   | INFO     | Pre-existing master failures, unrelated to this fix, verified identical on pristine `078891de` by stash-run: bug #691 (verify-red unexpected-green premise superseded by the #682 done-promotion) and 2 × `make_command_test.dart` | this audit's baseline runs                        |
| 3   | INFO     | `dart format .` on pristine `078891de` reformats 22 files — pre-existing drift vs the Dart 3.13.3 formatter; left untouched (minimal-fix constraint); the PR's 4 touched files are format-clean                                      | `dart format --output=none --set-exit-if-changed` on touched files → 0 changed |

No `HIGH` smells in the new tests: they assert concrete step sequences and
summary contracts through the real entry point (`CliRunner` → `RunCommand` →
real subprocess spawns of the scripted fake zfa), use the suite's recorded
helpers (`TddFixture`, `writeFakeZfa`, `stepInvocations`), are deterministic
(dead-pid technique matches the neighboring U23/A5 exemplars), contain no
conditional logic, and their failure output names the broken behavior.

## Mutation results (deliberate mutants — no mutation tool in profile)

| Mutant                                                                                       | Behavior | Survived | Judgment                                                                                     |
| -------------------------------------------------------------------------------------------- | -------- | -------- | ---------------------------------------------------------------------------------------------- |
| MUTANT-1: guard disabled (`else if (false)`) — restores the pre-fix state-trusting sequencer | B-720a   | No       | Caught by the clean-state test (`make B-001` instead of `gen B-001`); restored, suite green    |
| MUTANT-2: condition inverted (`else if (hasGenArtifacts)`) — demotes certified resumes       | B-720c   | No       | Caught by the artifacts-present guard test; restored, suite green                             |
| MUTANT-3: artifact check applied over the marker — weakens U23 precedence                    | B-720b   | No       | Caught by the marker-precedence test; restored exactly, suite green                           |

Sample: 3 of 3 mutants over the changed logic's full decision surface (guard
removal, inversion, precedence) — exhaustive for this guard; the rest of
`run_command.dart` was not mutated.

## Traceability (issue #720 criteria → tests)

| Issue criterion                                                                    | Test / evidence                                                                                | Real entry point?                                        |
| ----------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------- | --------------------------------------------------------- |
| No run-state → start with `gen` for the first behavior                              | B-720a asserts `gen B-001` first                                                                | yes — driver through `CliRunner` + real subprocess spawns  |
| No artifacts.json + no gen files → `gen` runs and creates them                      | B-720a asserts gen runs first on a wiped tree; file creation itself is gen's own suite (044)     | yes, for the sequencing criterion                          |
| Full gen → verify-red → make → refactor cycle per behavior in list order            | B-720a asserts the full 12-step sequence over three behaviors                                   | yes                                                        |
| Interrupted run resumed from a fresh wipe starts at gen for artifact-less behaviors | B-720a + B-720b (marker precedence preserved)                                                   | yes                                                        |
| Full suite: no NEW failures                                                         | chunked fast tier 0 failed; every slow-tier failure re-verified as pre-existing on `078891de`   | yes — repo's own chunked runner and presets                |

Untested criteria: none. Tests tracing to nothing: none.

## What was not audited

- The audit is not independent: the same session wrote the fix and the tests.
  A fresh-context reviewer should treat this report as the author's own grade.
- No mutation tool was used (profile has none); the deliberate-mutant sample
  covers only the changed guard logic, not the whole driver.
- Gen's file-creation contract (spec 044) and make's refusal contract (spec
  047) are relied upon as tested by their own suites; they were not re-audited.
- The fast-tier chunked run covers the default suite; the regression/
  integration/property/benchmark presets outside `test/plugins/tdd` were not
  run (dart_test.yaml advises against them on small cloud agents).
- Performance and wall-time characteristics of the added per-behavior registry
  read (one small JSON read per non-DONE behavior) were not measured.
