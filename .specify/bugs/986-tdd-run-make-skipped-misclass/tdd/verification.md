---
feature: 986-tdd-run-make-skipped-misclass (bugfix #986, branch mode)
verdict: PASS_WITH_GAPS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
verified_at: 77e69f24+ (fix/986-tdd-run-make-skipped-misclass, incl. the driver-layer mapping commit)
behaviors: 5
proven: 5
likely: 0
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 3
criteria_covered: 3
mutation_score: 100 # scope: StepRunner make terminal-success set (1 deliberate mutant: `skipped` removed — caught by the new bug-986 pin) + the driver failure-branch mapping (1 deliberate mutant: mapping removed — caught by the new disagreeing-exit tests); mutants restored, suite green again
mutants_survived: 0
suite: run_command_test 43/43 (slow tier; was 39 pass + 1 committed-broken at base), step_runner_test 17/17, run_baseline_cache_test 7/7, run_command_path_format_test 5/5, chunked fast suite 75/75 chunks green (0 failed)
---

# TDD Verification: #986 `zfa tdd run` make=skipped terminal contract

**Verdict: PASS_WITH_GAPS.** The driver-layer contract demanded by the issue —
`zfa tdd run` treats a make reporting `outcome=skipped` as a terminal success
that advances to refactor — is now proven on EVERY driver path and at three
levels (parser unit, driver outcome mapping, end-to-end #986 pin) plus a
real-CLI reproduction outside the test harness. Gap: the reporter's exact
in-run drift-check failure (forklift tree, 39 pending stubs) is
environment-dependent and does not reproduce here; the corresponding residual
risk is documented, not fixed (fixing it would change make's #942 tolerance
gate, which the task forbids).

## Root cause (from issue, re-diagnosed against source)

The report's attribution ("the driver's parser does not treat skipped as a
terminal make outcome") is imprecise in one half and precise in the other:

- **Disproved half:** `StepRunner` has accepted exit-0 `outcome=skipped`
  since the #694 remediation (d7ec22ed / PR #708), and
  `green-with-failed-build` since #942. The report's own transcript proves
  it: `A1 make -> skipped` was ACCEPTED and advanced. The transcript's
  `A2 make -> generation-error` means the make CHILD honestly printed
  `outcome=generation-error` because its in-run drift check failed
  (`alreadyGreen == false`) while the driver-spawned run carried the
  project's pending-stub noise, so make entered the generation path and the
  terminal build step failed with analyzer errors — the #737 tolerance
  cannot engage under the #942 no-analyzer-errors gate. The driver then
  stops per FR-007 (honest stop). That environmental drift-check failure
  does not reproduce outside the reporter's machine (two real-CLI
  reproductions of the resumed state here both flow past skipped makes
  cleanly).

- **Confirmed half (the driver-layer defect):** when #694 renamed the
  already-green outcome from `drift` (which exited NON-ZERO under the #657
  contract) to `skipped` (exit 0), the driver's own already-green mapping
  from the #693 remediation (`drift -> green` in `_driveBehavior`'s failure
  branch) was dropped with the old token. A `skipped` token that reaches the
  failure branch — exit code disagreeing with the token (binary skew, or the
  #657/#694-era non-zero already-green contract) — falls through to the
  honest stop: the run halts on an already-green behavior. Reproduced
  deterministically (RED evidence below): `result=stopped ...
  stopped_at=B-001:make` with the stop line `outcome=skipped`. The
  #693-to-#694 rename re-opened the exact mapping-table gap #693 closed.

## What this fix delivers (test-first, within the task's hard constraints)

The driver now recognizes `skipped` as a terminal make outcome on every path
it owns, and the contract is pinned so it cannot silently regress. The skip
transition semantics (#694) are untouched: `make_command.dart` and
`step_runner.dart` are byte-identical to base — nothing in make, verify-red,
or the reconcile changes.

| Behavior | Class | Evidence |
| --- | --- | --- |
| U-986a: the #691 flow — verify-red reports unexpected-green on a stuck-red behavior whose test is already green, driver skips to make, make=skipped advances, feature completes | PROVEN | `run_command_test.dart` bug #691 test REPAIRED FIRST (red evidence only — the committed version over-seeded green evidence, which the #682 reconcile promotes to DONE before the drive, so the test failed at its own commit 33241f86 and at base 77e69f24); fails as committed (RED recorded below), passes after the seed repair |
| U-986b: a resume whose makes ALL report the #694 skip transition completes exit 0, every behavior done, no generation-error anywhere in the transcript | PROVEN | `run_command_test.dart` NEW bug 986 test; passes at HEAD (the contract holds); MUTATION-KILLED by removing `skipped` from the StepRunner make terminal-success set (test turns red — the run halts at the first skipped make, the exact #986 symptom), restored, green again |
| U-986c: real-CLI end-to-end — resumed feature (behaviors red-evidenced, subjects already implemented) driven by `dart bin/zfa.dart tdd run … --timeout 15` flows past BOTH skipped makes | PROVEN | scratch project outside the repo (gen → verify-red → subjects implemented → run): `[run] A1 make -> skipped`, `[run] A2 make -> skipped`, both deferred refactors, run advances; transcript captured in the work log |
| U-986d: a make reporting `outcome=skipped` through the driver's FAILURE branch (exit code disagreeing with the token — binary skew / the #657-era non-zero contract) is a terminal success: the behavior advances GREEN, refactor proceeds, the feature completes — never a step-failed stop | PROVEN | `run_command_test.dart` NEW bug #986 test (the fake's literal `skipped` token prints `outcome=skipped` and exits 1). RED at base HEAD (fall-through stop, recorded below), GREEN after the driver-layer mapping in `run_command.dart` `_driveBehavior` (records the provenance-labeled green evidence when make's write did not land — idempotent, the #693 driver-recorded pattern — advances GREEN, prints `[run] <id> make -> green (skipped)` + the exit-disagreement note, continues the window). MUTATION-KILLED by removing the mapping (test reverts to the RED transcript) |
| U-986e: the driver-recorded green evidence for a disagreeing-exit skipped make is idempotent — an existing green entry is never duplicated | PROVEN | `run_command_test.dart` NEW bug #986 test: exactly one `## Cycle: B-001 (green)` section after the run |

## RED evidence (recorded before the fixes)

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

Driver failure-branch fall-through (RED for U-986d, at base 77e69f24 with the
repaired #691 test in place):

```
dart test --preset=all --plain-name "bug #986" test/plugins/tdd/run_command_test.dart
00:05 +0 -1: bug #986: make reporting skipped is a terminal success even when its
  exit code disagrees — the run advances instead of stopping [E]
  Expected: <0>
    Actual: <1>
  [run] B-001 make -> skipped
  zfa tdd run: step failed — behavior=B-001 step=make outcome=skipped
     make: behavior=B-001 outcome=skipped feature=090-run-driver
  run: feature=090-run-driver result=stopped pending=2 red=1 green=0 done=0 stopped_at=B-001:make
00:10 +0 -2: bug #986: an existing green evidence entry is not duplicated when make reports skipped [E]
  Expected: <0>
    Actual: <1>
  run: feature=090-run-driver result=stopped pending=2 red=0 green=1 done=0 stopped_at=B-001:make
```

The pre-fix driver hard-stopped the whole feature at `B-001:make` with the
already-green behavior RED — the #986 symptom at the driver layer,
reproduced deterministically.

## GREEN evidence (after the fixes)

```
dart test --preset=all --plain-name "bug #986" test/plugins/tdd/run_command_test.dart
00:11 +2: All tests passed!

dart test --preset=all test/plugins/tdd/run_command_test.dart
04:1x +43: All tests passed!

dart test test/plugins/tdd/services/step_runner_test.dart
00:00 +17: All tests passed!

dart test --preset=all test/plugins/tdd/scenarios/sc_013_run_drives_feature_test.dart
        test/plugins/tdd/scenarios/sc_014_run_resumes_test.dart
        test/plugins/tdd/scenarios/sc_015_run_stops_on_failure_test.dart
        test/plugins/tdd/scenarios/sc_016_run_summary_contract_test.dart
01:17 +16: All tests passed!

dart test --preset=all test/plugins/tdd/scenarios/sc_006_requires_certified_red_test.dart
        test/plugins/tdd/scenarios/sc_008_misfire_stop_test.dart
        test/plugins/tdd/scenarios/sc_009_summary_contract_test.dart
# passed (incl. A6 — the real make #694 skip transition: exit 0, outcome=skipped,
#  green evidence, no generation)

dart test test/plugins/tdd/        # fast tier, whole plugin
05:55 +1091: All tests passed!

dart analyze lib test --no-fatal-warnings
# 0 errors; every warning/info pre-existing in unrelated files; no issue
# names the changed files (run_command.dart, run_command_test.dart)

dart format .
Formatted 1978 files (0 changed).
git diff --stat     # zero formatting diffs — only the intentional edits

tools/run_tests_chunked.sh   # fast suite, chunked
75/75 chunks green, 0 failures. The single script run was cut off by the
sandbox's 10-minute foreground ceiling after 62 green chunks (mid-flight in
chunk 63, test/secure_storage — re-ran green 11/11); the remaining 12 chunks
ran through the script's IDENTICAL loop body (same `dart test <chunk>
--exclude-tags flutter < /dev/null` + kernel-cache cleanup between chunks)
and finished `OK: remaining chunks passed.` Background/detached invocations
do not persist in this sandbox (the same limitation the #693 verification
disclosed).
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
3. sc_012's two failures (sandbox `zfa build` pass limitations) and sc_022's
   FFI golden lane (native toolchain absent) are pre-existing environment
   constraints, identical on the unmodified parent, and unrelated to the
   changed files.
