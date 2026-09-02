---
feature: tdd-run-per-behavior-slow-cold-binary (bugfix #741, branch mode)
verdict: PASS_WITH_GAPS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
verified_at: bac65adf
behaviors: 7
proven: 7
likely: 0
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 6
criteria_covered: 6
mutation_score: 100 # scope: the fix's full changed decision surface (skip-transition bypass, cache consumption, flag plumbing), 3 deliberate mutants (no mutation tool in profile)
mutants_survived: 0
timing: skip-transition re-runs 10 suite runs / 95.8s -> 0 / 83.7s; one tdd run over 5 red behaviors (real make) 10 suite runs / 113.7s -> 1 / 104.3s (real `dart test` processes in pub-getted fixtures; suite-run count is the structural metric, wall time scales linearly with it)
suite: fast tier chunked 66 chunks — 61 passed / 5 skipped (no fast-tier tests) / 0 failed, 2535 test cases all passed; driver contract suite 28 passed, 1 failed (pre-existing bug #691, fails identically on pristine bac65adf); make contract suite 27 passed, 2 failed (pre-existing bug 657 + A11/U17, fail identically on pristine bac65adf); e2e scenarios sc_018 +1, sc_021 A1 +1, A2 +1 — all passed; new cache tests 7/7
---

# TDD Verification: #741 tdd run per-behavior slow on cold binary — baseline caching + skip-on-green

**Verdict: PASS_WITH_GAPS.** The two cost structures the issue names are pinned
by tests whose RED was recorded against the pre-fix source (the skip transition
ran the suite twice per already-green behavior; the driver wrote no baseline
cache), the fix demotes the per-behavior full-suite runs to one cached baseline
per run plus scoped single-test evidence, all three deliberate mutants were
caught, and the timing measurement on real `dart test` processes shows 10 → 0
suite runs for the skip path and 10 → 1 for a full 5-behavior driver run —
extrapolating to the issue's 1–3 min suite and 39 U* behaviors, ~78–234 min of
suite wait collapses to ~1–3 min. Gaps: the branch is a single uncommitted
batch on `bac65adf`, so git history alone cannot corroborate test-first
ordering (the recorded pre-fix RED runs are the evidence); mutation was
deliberate-mutant sampling, not a tool; and this audit was produced by the
same session that wrote the fix and the tests (not independent).

## Root cause (from issue #741 + assessment, confirmed in source)

`lib/src/plugins/tdd/commands/make_command.dart` ran a full-suite baseline
(`runner.runSuite`, line 248 at `bac65adf`) before every generation and a
full-suite guard (`guardRun`, line 417) after it — 2 full `dart test` runs per
behavior, unconditionally, including on the issue #694 skip transition where
nothing is generated. The profile itself warns the full suite is "slow; do not
run for feature work" (`.specify/memory/tdd-profile.md`). With 39 U* behaviors
that is 78 sequential full-suite runs at 1–3 min each. The assessment also
confirmed verify-red was NOT the bottleneck (already scoped via
`runSingle`) — the issue's attribution there was a misfire.

## The fix

Three coordinated changes, no exit-code / summary-line / evidence-rendering
changes anywhere:

1. **`run_command.dart` — cache the baseline once per run.** Before driving
   the loop (and only when at least one behavior is short of DONE), the
   driver loads the profile's suite template, runs the suite ONCE, parses
   the transcript into a `SuiteSnapshot`, and — only when the snapshot is
   parseable — persists it to `specs/<feature>/tdd/run-baseline.json` and
   hands its path to every make step. Best-effort and fail-safe: a missing
   profile or an unusable transcript disables caching and every make falls
   back to its own live baseline (exactly the pre-#741 behavior). The
   baseline is re-established fresh on every invocation, so an interrupted
   run never reuses a stale snapshot.
2. **`step_runner.dart` — plumb the cache to make only.** `StepRunner.run`
   takes an optional `suiteBaselinePath` and appends
   `--suite-baseline <path>` to make's argv (all other steps ignore it).
3. **`make_command.dart` — consume the cache, skip the suite on skip.**
   On the #694 already-green skip transition NO suite runs at all — the
   scoped drift re-run is the evidence run, and the green entry records the
   honest zeros (`baseline=0 guard=0 new=(none)`; rendering unchanged). With
   a readable cached baseline the pre-run suite is skipped and the
   post-generation guard is certified from the scoped single-test result;
   a missing, corrupt, or unparseable cache — or an unparseable scoped
   transcript — falls back to the live full-suite baseline/guard with its
   existing U18 safe-failure checks verbatim. The #731 attributable-regression
   scoping is unchanged. Standalone `make` (no flag) behaves exactly as
   before.

New files: `lib/src/plugins/tdd/services/run_baseline_cache.dart` (snapshot
read/write, fail-safe). The `--suite-baseline` flag is registered on make.

## Test-first evidence

| Behavior                                                                    | Class  | Evidence                                                                                                                                                                                                                                                                       |
| --------------------------------------------------------------------------- | ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| B-741a: skip transition (already-green) runs NO suite at all                | PROVEN | New test recorded RED pre-fix: suite spy log held 2 invocations (baseline + guard) for a single already-green make; the fix turns it green with an empty log and `baseline=0 guard=0 new=(none)` in the evidence                                                              |
| B-741b: make with a cached baseline runs zero live suites, guards scoped    | PROVEN | RED pre-fix: `--suite-baseline` was an unknown option (usage error); post-fix: suite log empty, single spy ran exactly twice (drift + post), evidence `baseline=1 guard=0 new=(none)` from the cache + scoped transcript                                                          |
| B-741c: standalone make (no flag) keeps live baseline + guard               | PROVEN | Guard test, green pre- and post-fix — the flag-less contract must not regress; exactly 2 suite invocations either way                                                                                                                                                             |
| B-741d: corrupt cache file is a safe failure (live fallback)                | PROVEN | RED pre-fix (unknown flag); post-fix the garbage file falls back to the live suite, 2 invocations, still green                                                                                                                                                                    |
| B-741e: driver caches the baseline once per run and passes it to every make | PROVEN | RED pre-fix: no cache file written, zero suite runs at driver level; post-fix: cache JSON exists with the snapshot contract, suite spy ran exactly 1× for a 3-behavior run, all 3 make argv lines carry `--suite-baseline <path>`                                                |
| B-741f: unusable suite disables caching; the run still completes            | PROVEN | Safety-contract test, green pre- and post-fix; post-fix it also asserts no make argv carries the flag when no cache was written                                                                                                                                                   |
| B-741g: interrupted run resumes with a fresh cached baseline                | PROVEN | Seeded mid-flight residue (red claim + artifacts + red evidence), resumed run completes, suite ran exactly once on the resume, cache rewritten, both make argv lines carry the flag — the assessment's "resume still works with the cached baseline" criterion                     |

Existing-test changes: `test/plugins/tdd/helpers/tdd_fixture.dart` gained
additive helpers only (spy runner scripts, argv log, `runBaselinePath`,
`rewriteProfile`); the scripted fake zfa gained one argv log line. No
assertion was removed, loosened, renamed out of a filter's reach, skipped, or
weakened anywhere in the diff; no exclusion or threshold was touched.

## Findings

| #   | Severity | Finding                                                                                                                                                                        | Evidence                                                              |
| --- | -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------- |
| 1   | LOW      | With a cached baseline the post-generation guard is scoped to the target test; collateral breakage of OTHER baseline-green files is not re-checked per behavior (the accepted trade-off the assessment prescribes) — the driver's run-start baseline plus the final feature state carry that signal instead | `make_command.dart` section 9 (issue #741 comment); assessment "Risks & Considerations" |
| 2   | INFO     | Pre-existing master failures, unrelated to this fix, verified identical on pristine `bac65adf` by stash-run: bug #691 (run_command_test) and bug 657 + A11/U17 (make_command_test) — #720's audit recorded the same three       | this audit's baseline runs                                              |
| 3   | INFO     | `dart format .` sweeps `examples/`, which CI's format job does not cover (`dart format --set-exit-if-changed lib test`); master carries pre-existing drift there. Reverted to keep the PR scoped; the PR's lib/test files are format-clean (0 changed, idempotent) | CI `ci.yaml` format job; this audit                                     |
| 4   | INFO     | On the skip transition the green evidence's suite numbers are the honest zeros (no suite ran); the profile's suite command is still loaded, so a missing `suite:` key misfires there as before | `make_command.dart` section 10 comment                                  |

No `HIGH` smells in the new tests: they assert concrete invocation logs,
cache-file contracts, evidence lines, and summary lines through the real
entry point (`CliRunner` → `RunCommand`/`MakeCommand` → real subprocess
spawns), reuse the suite's recorded fixture helpers (`TddFixture`,
`writeFakeZfa`, spy scripts mirroring `writeFakeZfa`'s shape), are
deterministic (no wall-clock or ordering dependencies; transcripts are
fixed), contain no conditional logic in the tests themselves, and their
failure output names the broken behavior.

## Mutation results (deliberate mutants — no mutation tool in profile)

| Mutant                                                                                        | Behavior | Survived | Judgment                                                                                          |
| --------------------------------------------------------------------------------------------- | -------- | -------- | --------------------------------------------------------------------------------------------------- |
| MUTANT-1: skip-transition bypass disabled (`if (true)` restores the unconditional baseline run) | B-741a   | No       | Caught: the skip test's suite-log-is-empty assertion failed; restored exactly, test green again      |
| MUTANT-2: cache consumption disabled (`if (false && cached…`) — every make falls back to the live suite | B-741b | No | Caught: the cached-baseline test's zero-suite-runs + evidence assertions failed; restored, green     |
| MUTANT-3: flag plumbing cut (`if (false && step == 'make'…`) — make steps never receive the cache path | B-741e | No | Caught: the driver test's argv assertions failed; restored, full new-suite green (7/7)               |

Sample: 3 of 3 mutants over the fix's full changed decision surface (bypass
removal, cache disablement, plumbing cut) — exhaustive for the three
decision points this fix introduced; the rest of both commands was not
mutated. (Audit note: the MUTANT-3 restore initially used `git checkout`,
which reverted the uncommitted fix and broke the suite load; the exact change
was re-applied and all 7 tests re-verified green — no mutant survived.)

## Timing evidence (real `dart test` in pub-getted fixtures)

| Scenario                                                                                  | Pre-fix (OLD)              | Post-fix (NEW)          |
| ----------------------------------------------------------------------------------------- | -------------------------- | ------------------------- |
| A: 5 × `tdd make` on already-green behaviors (the #694 re-run path)                        | 10 suite runs / 95.8s      | **0 suite runs** / 83.7s  |
| B: one `tdd run` over 5 certified-red behaviors with the real `make` under the driver      | 10 suite runs / 113.7s     | **1 suite run** / 104.3s  |

Suite runs were counted by a logging wrapper around the profile's real suite
command; wall time is dominated by per-process Dart VM startups in the scaled
fixture. At the issue's scale (1–3 min per suite run, 39 U* behaviors) the 78
sequential suite runs (2 per behavior) collapse to 1 per run plus per-behavior
scoped single tests — the ~3+ hour projected wait drops to minutes.

## Traceability (issue #741 criteria → tests)

| Issue criterion                                                                                       | Test / evidence                                                              | Real entry point?                            |
| ------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------ | ---------------------------------------------- |
| Per-behavior cycle no longer dominated by full-suite runs (sub-30s target)                                | B-741a/b/e + timing table                                                      | yes — CliRunner + real subprocess spawns        |
| The full `dart test` should not be needed to verify a single test (scoped runs stay the evidence path)    | B-741b (single spy ran exactly twice: drift + post); verify-red untouched      | yes                                            |
| Suite baseline cached once per feature/run in run_command instead of per-behavior                          | B-741e (1 suite run for 3 behaviors; cache file + argv contract)               | yes — real driver via CliRunner                 |
| #694 skip transition (already-green) does not run the full suite at all                                    | B-741a (0 suite runs; zeros in evidence)                                       | yes — real make via CliRunner                   |
| Post-generation guard compares scoped single-test results where possible, full suite as safe fallback      | B-741b (scoped guard) + B-741d (corrupt cache → live fallback) + B-741c (standalone unchanged) | yes                             |
| Resume after interruption still works with the cached baseline                                             | B-741g (fresh baseline on resume; run completes; flag present)                 | yes — real driver, seeded mid-flight state      |
| Exit codes, summary lines, evidence contracts unchanged (hard constraint)                                  | fast suite 2535/2535 + contract suites (only pre-existing failures) + unchanged renderings asserted by the existing make tests | yes                                  |

Untested criteria: none. Tests tracing to nothing: none.

## What was not audited

- The audit is not independent: the same session wrote the fix and the tests.
  A fresh-context reviewer should treat this report as the author's own grade.
- No mutation tool was used (profile has none); the deliberate-mutant sample
  covers only the three decision points the fix introduced, not both commands
  in full.
- The regression/integration/property/benchmark presets were not run
  (dart_test.yaml advises against them on small cloud agents; the same scope
  decision as the #720 audit). sc_021's two e2e scenarios were verified
  individually (each ~5 min of real pub get + build_runner); the other slow
  scenario files were not run.
- The standalone-make live path's behavior with a VALID `--suite-baseline`
  cache whose snapshot has grown stale relative to on-disk changes is guarded
  only by the driver's fresh-per-run contract; a user hand-crafting a stale
  cache file and passing the flag bypasses that (documented flag contract,
  not separately tested).
- Wall-time characteristics on the issue's real codebase (1–3 min suites)
  were extrapolated from the scaled fixture, not measured there.
- Phase 7 remediation tasks were not appended: this is a bug-mode audit (no
  feature `tasks.md` exists) and no finding rises above LOW/INFO.
