---
feature: .specify/bugs/tdd-make-regression-false-positive (bug #731, pinned per bug extension TDD mode)
verdict: PASS_WITH_GAPS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
verified_at: b832c1f0
behaviors: 2
proven: 2
likely: 0
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 3
criteria_covered: 3
mutation_score: 2/3 caught # scope: make_command.dart guard-verdict condition only, manual deliberate mutants
mutants_survived: 1 # triaged: defensive clause with no pinning test (finding 1)
suite: "make_command_test +26 −2 (2 pre-existing, pristine-identical); chunked fast suite: all chunks passed; dart analyze: clean"
---

# TDD Verification: bug #731 — tdd make regression false positive

**Verdict: PASS_WITH_GAPS.** The red→green cycle is real (both new tests failed
against the pre-fix code with the exact #731 signature and pass against the
fix), all three acceptance criteria from the issue are covered end-to-end
through the real CLI (`CliRunner` → `zfa tdd make` → real `dart test`
subprocesses), and no existing test was weakened. The gaps: the bug workflow
has no `tdd/test-list.md` (ordering evidence is session-recorded, the commit is
atomic), one defensive clause of the new verdict condition is not pinned by any
test (mutant M1 survived), and three pre-existing failures elsewhere in the
suite pre-date this branch and are documented, not fixed, here.

## Test-first evidence

| Behavior | Class  | Evidence                                                                                                                                        |
| -------- | ------ | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| B1 — skip transition tolerates pre-existing reds with unstable failing-test ids | PROVEN | RED captured verbatim (pre-fix run): `baseline exit: 1, failed: 1` → `regression detected — 1 NEW failure(s)` → `outcome=regression`; GREEN post-fix: `outcome=skipped`, exit 0, green evidence appended. Session red-phase run precedes the fix; the commit is atomic, so git history alone shows LIKELY ordering. |
| B2 — generation path tolerates failures confined to already-red files    | PROVEN | RED captured verbatim: target green (`target test exit: 0`) yet `outcome=regression` from the sibling's unstable id; GREEN post-fix: `outcome=green`, exit 0. Same atomicity caveat as B1. |

No existing test was modified by this fix (`git diff` on the test file shows
insertions only), so the rubric's weakened-existing-test check is clean.

## Findings

| #   | Severity | Finding                                                                                                                         | Evidence                                                        |
| --- | -------- | ------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------- |
| 1   | MED      | No test pins the `inCurrentBehaviorFile` clause: a NEW failing test inside the current behavior's OWN test file is classified a regression by the fix, but no fixture exercises it — mutant M1 survived | `lib/src/plugins/tdd/commands/make_command.dart:628`; M1 run: `+26 −2` (identical to fixed tree) |
| 2   | LOW      | The workflow stated `.specify/bugs/<slug>/{issue,assessment}.md` were already committed; they exist on no branch. Records were reconstructed in this PR from GitHub issue #731 (the sole triage input) and this session's root-cause work | `.specify/bugs/tdd-make-regression-false-positive/assessment.md` header |
| 3   | LOW      | Three pre-existing failures pre-date this branch and are intentionally not remediated here (single-purpose PR): bug 657 message wording and spec 052 A11/U17 in `make_command_test.dart`, bug #691 run-state skip in `run_command_test.dart` | Pristine-tree runs: `+24 −2` and `+28 −1`, identical failing tests |

## Mutation results (deliberate mutants, manual — no mutation tool in profile)

Scope: the new guard-verdict condition in `make_command.dart` only (the files
the fix changed). Every mutant was restored exactly and the suite was re-run
green after each restore.

| Mutant                                                    | Behavior    | Survived | Judgment                                                                          |
| --------------------------------------------------------- | ----------- | -------- | --------------------------------------------------------------------------------- |
| M2 — scoping disabled (`if (true)`): raw name-diff verdict | B1, B2      | No       | Caught by both new tests (`+0 −2`) — the tests own the #731 false positive        |
| M3 — collateral clause dropped (`if (inCurrentBehaviorFile)`) | A8 (existing) | No    | Caught by A8, sibling regression still reported (`+0 −1`) — clause is load-bearing |
| M1 — current-file clause dropped (`if (!fileWasAlreadyRed)`) | none       | Yes      | No fixture puts a second, newly-failing test inside the target's own file — genuine gap, finding 1 |

## Traceability (issue #731 Expected → tests)

| Criterion (issue #731 "Expected")                                                    | Test(s)                                                                                                  | Entry point |
| ------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------- | ----------- |
| Compare the current behavior's test file (or test name) against the baseline, not the full suite | B1, B2 (new); A8, A9 (existing, still green)                                                               | real CLI    |
| If only the current test passes, report `outcome=skipped` regardless of other behaviors being red | B1 (new)                                                                                                  | real CLI    |
| A regression only when a previously-passing test now fails because of this make       | A8 (existing, green — previously-green sibling file broken by the make); M3 mutant proves the clause is exercised | real CLI    |

All tests claiming these criteria exist and run (verified in the session runs
below); B1/B2 drive the real `zfa` CLI surface against real `dart test`
subprocesses in a temp fixture project, not unit doubles.

## Suite evidence (real runs, this session)

- `dart test --preset=all -t slow test/plugins/tdd/make_command_test.dart -N "bug 731"` → RED `+0 −2` pre-fix; GREEN `+2` post-fix.
- `dart test --preset=all -t slow test/plugins/tdd/make_command_test.dart test/plugins/tdd/services/suite_guard_test.dart` → `+26 −2` (make file; the 2 failures pre-date the branch) and `+9` (guard file, all passed).
- Consumers of make outcomes (slow tier, isolated): `verify_red_command_test` +19, `refactor_command_test` +14, `verify_command_test` +1, `compose_command_test` +14, `runner_suite_test` +13, `run_command_test` +28 −1 (pre-existing, pristine-identical), `test/plugins/tdd/models/` +59.
- `tools/run_tests_chunked.sh` (fast tier, cloud-agent-safe) → `OK: all chunks passed.`
- `dart analyze` → No issues found. `dart format` → both changed files stable.
- Monolithic `dart test --preset=all -t slow test/plugins/tdd/` → 59 suite-load errors that all pass when their folders run in isolation (kernel-cache exhaustion on a ~10 GB disk, the exact hazard `dart_test.yaml` documents); the chunked runner is the repo's prescribed form for this environment.

## What was not audited

- No mutation tool ran; the deliberate-mutant sample covered only the new
  verdict condition's three clauses, not the file-extraction helpers
  (`_testFileOf` / `_sameTestFile`) or any other file.
- Coverage was not run (the profile lists a coverage command; it was skipped —
  corroboration only per the rubric).
- The `integration`, `property`, and `benchmark` slow tiers were not run
  (temp-project + `build_runner` tiers; `dart_test.yaml` marks them unsafe on
  small cloud agents, and disk/RAM here is ~8 GB free).
- Performance/runtime of the suite guard was not assessed.
- The audit is not independent of the implementation (same session wrote the
  tests, the fix, and this report); the smell pass was performed against the
  rubric by the same agent, which the rubric flags as a limitation.

## Remediation suggestions

1. (Finding 1) Add a fixture where the target behavior's own test file carries
   a second test that the make newly breaks, and assert `outcome=regression`;
   the command that proves it done is `dart test --preset=all -t slow
   test/plugins/tdd/make_command_test.dart`.
2. (Finding 3) File the three pre-existing failures as their own issues; they
   are message-wording and run-state drift from earlier merges, not #731.
