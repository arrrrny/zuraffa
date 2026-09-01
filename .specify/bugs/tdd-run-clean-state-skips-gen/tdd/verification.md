---
feature: tdd-run-clean-state-skips-gen (bug 720)
verdict: PASS_WITH_GAPS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
verified_at: d6f7f517
behaviors: 4
proven: 4
likely: 0
test_after: 0
no_test: 0
baseline: 0
high_smells: 0
criteria_total: 3
criteria_covered: 3
mutation_score: 3/3 deliberate mutants caught # scope: the changed sequencing logic in run_command.dart (guard removal, condition inversion, marker-precedence drop); no mutation tool wired per tdd-profile
mutants_survived: 0
suite: 2,527 passed, 0 failed (chunked fast tier, 61 folder chunks) ; driver slow-tier files 45 passed / 1 pre-existing failure (#691, fails identically on master)
---

# TDD Verification: tdd run starts at gen on clean state (bug 720)

**Verdict: PASS_WITH_GAPS.** Every behavior this branch claims went through a
recorded red→green cycle (three at the driver-test level with the fix stashed
to reproduce the pre-fix state, one end-to-end with the real compiled binary
reproducing the issue's exact clean state), every criterion is covered, and
all three sampled mutants were caught. The gaps: mutation strength was
sampled with deliberate mutants (no tool is wired), not measured; one MED
edge in the new artifact check has no dedicated test; and the audit was
produced by the same session that wrote the tests, so it is not independent
(Hard Rule 2 disclosure) — every file was re-read cold for the smell pass.

## Context the verdict depends on

- `check-prerequisites.sh --json --paths-only` errors for bug-driven work (no
  `specs/<feature>` directory and no `.specify/feature.json`). FEATURE_DIR was
  resolved per the bug extension's per-bug layout (`BUG_DIR/tdd/`, matching
  `slice-commands-missing-from-extension` and the bug command docs).
- The issue's clean state is deterministic at base `d6f7f517`: wipe
  `run-state.json` + `artifacts.json` + generated files, keep the cycle-log's
  residual red evidence, run the real binary → `[run] A1 make -> runner-error`
  ("no gen artifacts"), exit 2. The fix flips exactly that into
  `gen -> ok`, `verify-red -> certified`, `make -> green`, `refactor -> clean`,
  `result=complete`, exit 0 (transcripts in `../red-evidence.md` and
  `../green-evidence.md`).
- The failure mechanism: the #682 bootstrap (`_reconcile`) promotes pending
  claims to RED/GREEN from residual cycle-log evidence, and `_stepsFor`
  sequenced from the claim alone — a RED claim starts at `make`, which
  runner-errors when the registry has no record for the behavior. The fix
  adds the missing half: absent gen artifacts override the state claim and
  re-enter at gen, unless a crashed run's in-flight marker says otherwise
  (U23 resume semantics unchanged, verified by mutant sampling).

## Test-first evidence

| Behavior | Class  | Evidence |
| -------- | ------ | -------- |
| U1       | PROVEN | cycle-log cycle 1: red recorded with output (`make B-001` first) with the fix stashed at `d6f7f517`; green after restore; per the profile's convention the red test and the implementation land in the same commit |
| U2       | PROVEN | cycle-log cycle 2: red (`make B-002` at location [1]) stashed-run; green restored |
| U3       | PROVEN | cycle-log cycle 3: red (B-002 wrongly at make) stashed-run; green restored |
| A1       | PROVEN | cycle-log cycle 4: real-binary red (issue signature, exit 2) and green (`result=complete`, exit 0) transcripts from the reproduction harness |

No `TEST_AFTER`, `NO_TEST`, or baseline-classified behaviors.

### What the diff did to existing tests

Seven existing driver tests encoded the artifact-blind contract (state claims
re-entering at make/refactor with no artifacts registered): U21 (part 1), U22,
both bug-682 tests, sc_014 A4 + bug-625 resume, sc_015 A9. Each was re-anchored
by adding `registerBehavior` calls and comments — **no assertion, expected
sequence, exit code, or state expectation was changed or removed** (verified by
reading every hunk of `git diff` for the two scenario files and the driver test
file; the only expectation edits in the diff are the three NEW bug-720 tests
whose first drafts guessed the #635 deferral composition wrong and were corrected
to the contract-correct sequences before any green run). No test was renamed
out of a filter, skipped, or excluded; no threshold or scope was lowered.
The diff also leaves `pubspec.lock` untouched (local resolution churn was
reverted) and excludes three files of pre-existing formatter drift
(`examples/mcp_demo/lib/src/mcp/tools.dart`,
`test/cli/writers/tdd/pubspec_dev_dependencies_patcher_test.dart`,
`test/plugins/tdd/commands/gen_command_test.dart`) that `dart format` (3.13.3)
re-wraps but this fix does not own.

## Findings

Ordered by severity. Nothing here blocks the verdict; the first two are
remediation candidates for a follow-up.

| # | Severity | Finding | Evidence |
| - | -------- | ------- | -------- |
| 1 | MED      | The "registry record present but recorded test file missing" edge of `_genArtifactIds` has no dedicated test: the fixture's `registerBehavior` always writes the test file, so the divert-to-gen path for a broken pair (record without file) is unpinned. A test seeding a record and deleting its test file (expecting `gen B-…` first) would pin it. | `lib/src/plugins/tdd/commands/run_command.dart` (`_genArtifactIds`); `test/plugins/tdd/run_command_test.dart` (no such case) |
| 2 | LOW      | The `inFlightStep.isNotEmpty` half of the marker precedence is unpinned: no test seeds an empty-string `in_flight_step` in `run-state.json`, so the assessment's "null/empty" wording is enforced only by code reading. | `lib/src/plugins/tdd/commands/run_command.dart:517`; `test/plugins/tdd/helpers/tdd_fixture.dart` (`seedRunState` accepts any string) |
| 3 | INFO (pre-existing, out of scope) | bug #691's driver test fails on unmodified master: its red+green seeding promotes B-001 to DONE via the #682 bootstrap, making the unexpected-green scenario unreachable through that path. Reproduced at `d6f7f517` before any change; not fixed here (hard constraint: sequencing only). | `test/plugins/tdd/run_command_test.dart:367` (post-change numbering); baseline run `00:02 +25 -1` |
| 4 | INFO (pre-existing, out of scope) | `PipelineRunner` tier 4 (`Platform.resolvedExecutable` + `Platform.script`) doubles the executable in the step argv when the CLI runs as an AOT binary and no `zfa` is on `PATH` (exit 64, usage error inside `make`'s generation pipeline). Observed during the A1 reproduction; with `zfa` on `PATH` (tier 3, the issue's install layout) the pipeline resolves correctly. Documented in `../green-evidence.md`. | `lib/src/plugins/tdd/services/pipeline_runner.dart` (`_resolveEntrypoint` tier 4) |

## Smell pass (new/changed test code, read cold)

Graded against the profile's conventions (sentence names, shared fixture
helpers, red committed alongside the implementation) and the driver-test
exemplars:

- **No HIGH smells.** The three new bug-720 tests assert the fake zfa's full
  invocation sequence — the driver's observable sequencing contract — not
  doubles, internals, or truthiness. No tautologies (the invocation log is
  produced by the spawned fake, not configured into an assertion), no doubled
  subject, no conditional logic, no vacuous predicates.
- Properties: deterministic (temp fixtures per test, scripted fake binary),
  fast (~2s for the driver file's 34 tests), specific about what broke
  (`at location [N] is 'X' instead of 'Y'` names the exact step divergence),
  refactoring-insensitive (they assert the step stream, not private state).
- MED-adjacent note, recorded not failed: each new test drives a
  three-behavior feature, so one test pins a rule across several behaviors —
  consistent with every existing driver test in the file (U19, U22, #682 use
  the same shape), so it is the file's established idiom, not a new debt.
- The scenario-file edits add fixture registration only; no new smells
  introduced.

## Mutation results

Scope: the changed sequencing logic in `lib/src/plugins/tdd/commands/
run_command.dart`. No mutation tool is wired (tdd-profile), so deliberate
mutants, one at a time, each restored exactly and the suite re-run to
baseline before the next.

| Mutant | Behavior it threatens | Survived | Judgment |
| ------ | --------------------- | -------- | -------- |
| Remove the gen-artifact guard (fix stashed = pre-fix tree) | U1, A1 | No | Caught by U1 (`make B-001` instead of `gen B-001`) and by the real-binary repro (issue signature) |
| Invert the condition (`else if (hasGenArtifacts)`) | U3, U22, #682 | No | Caught by U3 (`gen B-001` instead of `make B-001`) — behaviors WITH artifacts would be wrongly re-driven |
| Drop the in-flight marker precedence block | U23, A5 | No | Caught by U23 (invocation sequence differs) — resume semantics are load-bearing |

Not sampled (and therefore not measured): boundary mutants inside
`_genArtifactIds` (absolute/relative path resolution, non-active ids), the
phase-2 windows (unchanged by this fix), and everything outside the changed
file.

## Traceability

| Criterion | Tests | End to end |
| --------- | ----- | ---------- |
| issue.md Expected — "No run-state → start with gen for the first behavior, then verify-red, then make" | U1, A1 | Yes (A1 is the real compiled binary on the issue's own reproduction) |
| assessment.md Remediation — "inFlightStep null/empty AND no gen artifacts → gen regardless of BehaviorState" | U1, U2 | Yes at the driver contract level; the in-flight-marker precedence is pinned by pre-existing U23/A5 plus mutant 3 |
| assessment.md Risks — "#682 fix interaction: clean state with no evidence still starts at gen; resume semantics preserved" | U3 (+ re-anchored U21, U22, #682 x2, A4, bug-625, A9) | Covered at the driver contract level; the artifacts-exist resume path is asserted by U3's make-first sequence |

Untested criteria: none. Tests tracing to nothing: none.

## What was not audited

Say it plainly, every run.

- Mutation strength is **sampled, not measured**: three deliberate mutants on
  the changed file; no tool ran, no score exists beyond 3/3.
- The slow-tier presets beyond the driver files (regression, integration,
  property, benchmark) were not run on this branch (small-disk agent budget;
  the chunked fast tier — 2,527 tests — and all TDD driver/scenario files
  were run green).
- Coverage was not measured (opt-in per the profile, not a gate).
- `A1` is a reproduction harness (compiled binary + scratch project), not a
  committed test; its evidence lives in `../red-evidence.md` /
  `../green-evidence.md` and this report. It is not executable in CI.
- Findings 3 and 4 are pre-existing master conditions explicitly left
  unfixed by the hard constraint ("fix ONLY the step-sequencing logic in
  run_command.dart"); they are reported for triage.
- Remediation tasks: bug dirs carry no `tasks.md` in this repo's layout, so
  findings 1–2 are recorded here as remediation candidates instead of
  appended task rows (per the bug extension's per-bug artifact set).

## Verification commands (reproduce the audit)

```bash
dart analyze                                          # No issues found
tools/run_tests_chunked.sh                            # exit 0, all 61 chunks green
dart test --preset=all test/plugins/tdd/run_command_test.dart \
  test/plugins/tdd/run_command_path_format_test.dart  # +33 -1 (#691 pre-existing)
dart test --preset=all test/plugins/tdd/scenarios/    # +12 All tests passed
dart test --preset=all test/plugins/tdd/run_command_test.dart --plain-name 'bug 720'  # +3 All tests passed
dart format lib/src/plugins/tdd/commands/run_command.dart \
  test/plugins/tdd/run_command_test.dart \
  test/plugins/tdd/scenarios/sc_014_run_resumes_test.dart \
  test/plugins/tdd/scenarios/sc_015_run_stops_on_failure_test.dart   # 0 changed
```
