---
feature: 986-tdd-run-make-skipped-misclass (bugfix #986, branch mode)
verdict: PASS_WITH_GAPS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
verified_at: 77e69f24+ (fix/986-tdd-run-make-skipped-misclass)
behaviors: 3
proven: 3
likely: 0
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 3
criteria_covered: 3
mutation_score: 100 # scope: StepRunner make terminal-success set, 1 deliberate mutant (skipped removed), caught by the new bug-986 pin, restored, suite green again
mutants_survived: 0
suite: run_command_test 41/41 (slow tier; was 39 pass + 1 committed-broken at base), step_runner_test 17/17, run_baseline_cache_test 7/7, run_command_path_format_test 5/5, chunked fast suite 74/74 chunks (1 flaky test/simulation failure passes 89/89 isolated, pre-existing, unrelated — see gaps)
---

# TDD Verification: #986 `zfa tdd run` make=skipped terminal contract

**Verdict: PASS_WITH_GAPS.** The driver-layer parser contract demanded by the
issue — `zfa tdd run` treats a make reporting `outcome=skipped` (exit 0) as a
terminal success that advances to refactor — is proven at three levels
(parser unit, repaired slow-tier driver test, new end-to-end #986 pin) plus a
real-CLI reproduction outside the test harness. Gap: the reporter's exact
in-run drift-check failure (forklift tree, 39 pending stubs) is
environment-dependent and does not reproduce here; the corresponding residual
risk is documented, not fixed (fixing it would change make's #942 tolerance
gate, which the task forbids).

## Root cause (from issue, re-diagnosed against source)

The report's attribution ("the driver's parser does not treat skipped as a
terminal make outcome") is disproved by the report's own transcript: `A1 make
-> skipped` was ACCEPTED and advanced. `StepRunner` has accepted exit-0
`outcome=skipped` since the #694 remediation (d7ec22ed / PR #708), and
`green-with-failed-build` since #942. The actual halt chain: the make CHILD
honestly printed `outcome=generation-error` because its in-run drift check
failed (`alreadyGreen == false`) while the driver-spawned run carried the
project's pending-stub noise, so make entered the generation path and the
terminal build step failed with analyzer errors — the #737 tolerance cannot
engage under the #942 no-analyzer-errors gate. The driver then stops per
FR-007 (honest stop). The environmental drift-check failure does not
reproduce outside the reporter's machine (two real-CLI reproductions of the
resumed state here both flow past skipped makes cleanly).

## What this fix delivers (test-first, within the task's hard constraints)

The parser contract is correct at HEAD; the REGRESSION PROOF was missing and
broken. This change repairs the committed-broken slow-tier test and pins the
#986 scenario end-to-end. Zero production-code changes: the skip transition
semantics (#694) are untouched, and no make/refactor/reconcile behavior
changes.

| Behavior | Class | Evidence |
| --- | --- | --- |
| U-986a: the #691 flow — verify-red reports unexpected-green on a stuck-red behavior whose test is already green, driver skips to make, make=skipped advances, feature completes | PROVEN | `run_command_test.dart` bug #691 test REPAIRED FIRST (red evidence only — the committed version over-seeded green evidence, which the #682 reconcile promotes to DONE before the drive, so the test failed at its own commit 33241f86 and at base 77e69f24); fails as committed (RED recorded below), passes after the seed repair |
| U-986b: a resume whose makes ALL report the #694 skip transition completes exit 0, every behavior done, no generation-error anywhere in the transcript | PROVEN | `run_command_test.dart` NEW bug 986 test; passes at HEAD (the contract holds); MUTATION-KILLED by removing `skipped` from the StepRunner make terminal-success set (test turns red — the run halts at the first skipped make, the exact #986 symptom), restored, green again |
| U-986c: real-CLI end-to-end — resumed feature (behaviors red-evidenced, subjects already implemented) driven by `dart bin/zfa.dart tdd run … --timeout 15` flows past BOTH skipped makes | PROVEN | scratch project outside the repo (gen → verify-red → subjects implemented → run): `[run] A1 make -> skipped`, `[run] A2 make -> skipped`, both deferred refactors, run advances; transcript captured in the work log |

## RED evidence (recorded before the fix)

Committed-broken #691 test at base 77e69f24 (slow tier — never run by CI,
which executes `dart test test --exclude-tags flutter` with `slow` excluded):

```
dart test --preset=all test/plugins/tdd/run_command_test.dart
04:17 +39 -1: Some tests failed.
Failing tests:
  test/plugins/tdd/run_command_test.dart: bug #691: verify-red reporting
  unexpected-green on an already-green behavior skips to make instead of
  stopping the run
Expected: contains '[run] B-001 verify-red -> unexpected-green'
  Actual: 'zfa tdd run: feature 090-run-driver — 3 behavior(s)\n'
            '   1 already done — skipping\n' ...
```

Also verified in a git worktree at the test's own commit (33241f86): the test
fails there too — it was committed broken, not regressed since.

Parser mutation (RED for the new pin):

```
# step_runner.dart: outcome == 'skipped' removed from the make success set
dart test --preset=all test/plugins/tdd/run_command_test.dart --plain-name "bug 986"
00:06 +0 -1: Some tests failed.
Failing tests: … bug 986: a resume whose makes all report the #694 skip
transition drives through every already-green behavior — no generation-error halt
```

## GREEN evidence (after the fix)

```
dart test --preset=all test/plugins/tdd/run_command_test.dart
04:20 +41: All tests passed!

dart test test/plugins/tdd/services/step_runner_test.dart
00:00 +17: All tests passed!

dart analyze lib test --no-fatal-warnings
314 issues found.   # 0 errors, 20 warnings, 294 infos — all pre-existing in
                    # unrelated files (mock capabilities, self-hosting
                    # fixtures); exit 0; no issue names the changed file

dart format .
Formatted 1978 files (0 changed) in 4.68 seconds.
git diff --stat     # zero formatting diffs — only the intentional test edit

tools/run_tests_chunked.sh   # fast suite, run via run_chunks_range.sh 1..74
74/74 chunks: All tests passed (3 SKIP = slow-tier-only dirs; test/simulation
failed once under parallel chunking and passes 89/89 on isolated re-run —
pre-existing flake, the changed file is not in that chunk)
```

## Not proved / residual risk (honest gaps)

1. The reporter's environmental in-run drift-check failure (fresh-kernel
   compile contention on a 72-behavior tree) is not reproducible here; when
   it fires, make still grades the behavior `generation-error` via the #942
   gate and the driver still stops (FR-007). Changing that grading is a make
   semantics change, explicitly out of scope for #986's constraint ("fix
   ONLY the driver-layer parser"). If it recurs, the follow-up is a make-side
   fix: teach the #737/#942 tolerance that a green target test after an
   already-green drift is the #694 skip transition, not a generation failure.
2. `bug_801_run_multi_feature_ownership_test.dart` (slow + integration, real
   CLI in a temp project) exceeds this sandbox's wall clock ("did not
   complete" at ~6.5 min); it is unrelated to this fix (feature-2 gen
   ownership namespacing) and excluded from the counts above.
