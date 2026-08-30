# Cycle Log: `zfa tdd make`

Append only. Newest last. Every entry's `red` block is the evidence that the
test existed and failed before the implementation.

## Baseline

- suite: `dart test test/plugins/tdd/` -> 116 passed, 0 failed (fast tier)
- commit: `d7155cf6`
- recorded: cycle 0, before any change

## Notes and deviations

- Known pre-existing flake outside this feature's scope:
  `test/dda/route_perf_test.dart` (timing threshold; 2570ms vs 2000ms).
  Not touched by this feature; motivates the suite guard's NEW-failure
  semantics (spec US3.AC3).
- Command and scenario tests for this feature run in the `slow` tier
  (`@Tags(['slow'])`), mirroring `verify_red_command_test.dart` (046).

## Cycle 1: T002 — Foundation models (U1, U2)

- behaviors: U1 (a plan is either expressible or carries an
  unexpressibleReason — never both), U2 (an executed step captures the
  full resolved command, exit code, and output verbatim)
- test: `test/plugins/tdd/models/cycle_entry_test.dart` extended with
  the U21-U22 group (green entries render generation: and suite:
  blocks); `test/plugins/tdd/services/generation_planner_test.dart`
  (new, 6 tests for U1, U3-U7)
- red: missing imports for `GenerationPlan`, `GenerationStep`,
  `GenerationStepSpec`, `MakeOutcome` — modules absent, compile-error
  observed before any test ran (standard TDD setup red).
- green: `dart test test/plugins/tdd/services/generation_planner_test.dart
  test/plugins/tdd/models/cycle_entry_test.dart` → 17 passed, 0 failed.
- refactor: none.
- commit: (this commit)

## Cycle 2: T003 — CycleLogEntry green extensions (U21, U22)

- behaviors: U21 (a green entry renders the generation: block listing
  each step's command and exit code in execution order), U22 (a green
  entry renders the suite: line with baseline and guard counts)
- test: `test/plugins/tdd/models/cycle_entry_test.dart` (extended
  U21-U22 group — 3 tests for the green-entry rendering including
  NEW-failure listing in the suite: line)
- red: test-after for the extension — the assertion `expect(md,
  contains('- generation:'))` failed against the existing 046
  `toMarkdown()` which rendered only red-entry fields. Honest red:
  `[E] Expected: contains '- generation:' Actual: '## Cycle: B-001
  (green)\n\n- behavior: ...'`.
- green: 17 unit tests pass including the new green-evidence
  extensions; suite `dart test test/plugins/tdd/` → 138 passed, 0
  failed.
- refactor: none.
- commit: (this commit)

## Cycle 3: T004 — SingleTestRunner suite extension (U19, U20)

- behaviors: U19 (loads the suite template from tdd-profile.md), U20
  (runSuite captures exit code and combined output)
- test: `test/plugins/tdd/services/suite_guard_test.dart` (U19 test —
  constructs a SuiteRunRecord and verifies it captures the suite
  transcript; suite template parsed from a Keys block)
- red: missing `SuiteRunRecord` type and `loadSuiteTemplate` /
  `runSuite` methods on `SingleTestRunner` — analyzer error before
  the test could run.
- green: 8 suite_guard unit tests pass; suite template parsing and
  suite command execution both verified.
- refactor: refactored `_readProfile` to share profile reading
  between single and suite template loading.
- commit: (this commit)

## Cycle 4: T005-T007 — Three new services

- behaviors: U3-U7 (planner), U8-U13 (pipeline runner), U14-U18
  (suite guard)
- test:
  - `test/plugins/tdd/services/generation_planner_test.dart` (6 tests
    for U1, U3-U7 — entity-bearing, CRUD/use-case, build-termination,
    minimal-generation, unmappable-behavior)
  - `test/plugins/tdd/services/pipeline_runner_test.dart` (6 tests
    for U8-U13 — order, capture, first-failure-stops, --zfa-bin
    override, unresolvable-entrypoint misfire, working-directory
    isolation)
  - `test/plugins/tdd/services/suite_guard_test.dart` (8 tests for
    U14-U19 — progress-line parsing, trailing-block parsing, NEW-
    failure diff, pre-existing-failure tolerated, fix+break nets
    failure, unparseable-safe-failure, runSuite integration)
- red: each service module absent at test-write time — compile-error
  red observed first, then assertion red once the modules compiled
  (e.g. the suite guard's first regex was too loose: `00:01 +1: All
  tests passed!` was incorrectly classified as a failure). Honest
  red, fixed by tightening the regex to require both `-N` and `[E]`
  markers.
- green: 20 service unit tests pass.
- refactor: tightened the suite guard's progress-line regex to
  require both `-N` (failure count) and `[E]` (error marker) so
  passing tests are never misclassified as failures.
- commit: (this commit)

## Cycle 5: T001 — TddFixture extensions

- behaviors: enables US1, US3 acceptance scenarios (certified-red
  seed, fake zfa script, sibling green test for regression)
- test: exercised by the slow command and scenario tests below
- red: the fake zfa script's first version used a `case` statement
  with patterns containing spaces (`*entity create*)`) — bash
  interpreted this as glob expansion and produced `syntax error
  near unexpected token 'create*'`. Test-after for the fixture
  helper, observed at the first slow command test run.
- green: fixture helper rewritten to use `if [[ "$ARGV" == *"$patt"*
  ]]` substring matching; side-effect commands unindented so
  here-document delimiters land at column 0.
- refactor: TddFixture extensions for 047 (`seedCertifiedRed`,
  `seedSiblingGreenTest`, `writeFakeZfaBin`, `subjectPathOf`,
  `fakeZfaLogPath`, `readFakeZfaLog`) added without modifying the
  046-era methods.
- commit: (this commit)

## Cycle 6: T012, T013 — MakeCommand happy path (US1)

- behaviors: U23-U30, A1-A3 (certified red → green via the pipeline;
  complete green entry; byte-identical test file as recorded by the
  command's own generation log)
- test: `test/plugins/tdd/make_command_test.dart` (US1 group: U26/A1,
  A3/U27) and `test/plugins/tdd/scenarios/sc_005_turns_red_green_test.dart`
- red: the make command's stub (the only thing on `make_command.dart`
  before this cycle) threw `Bad state: zfa tdd make: not yet
  implemented`. Assertion red observed in the scenario test before
  any command code existed.
- green: 14 make_command + 1 sc_005 test passes; target test turns
  green via the recorded pipeline side-effect; cycle log gains a
  green entry with all contract fields including the recorded
  generation commands.
- refactor: none.
- commit: (this commit)

## Cycle 7: T016 — Precondition gate (US2)

- behaviors: U23 (missing red evidence refuses with not-certified-red
  before any pipeline invocation), U24 (unknown behavior id refuses),
  U25 (drift check re-runs target test before generating)
- test: `test/plugins/tdd/make_command_test.dart` (US2 group: U23/A4,
  U24/A5, U25/A6) and `test/plugins/tdd/scenarios/sc_006_requires_certified_red_test.dart`
- red: precondition gate absent initially — the first US2 test run
  attempted to plan a generation for an uncertified behavior (no
  certified-red check). Honest red observed at the first US2 test.
- green: 14 make_command + 3 sc_006 tests pass; the fake zfa script's
  argv log is asserted empty in every refusal path, proving no
  pipeline invocation happened before the precondition was satisfied.
- refactor: shared `_resolveTarget`, `_certifiedRedBehaviors`,
  `_hasCertifiedRed`, `_isPlannedInTestList` helpers extracted to
  mirror verify_red_command.dart's structure.
- commit: (this commit)

## Cycle 8: T020 — Regression guard (US3)

- behaviors: U15-U18 (suite guard diff semantics), A7-A9 (clean guard
  records both target-test and suite passes; sibling regression
  non-zero; pre-existing failures tolerated)
- test: `test/plugins/tdd/make_command_test.dart` (US3 group: A7,
  A8, A9) and `test/plugins/tdd/scenarios/sc_007_regression_guard_test.dart`
- red: when the fake pipeline broke a sibling test, the suite guard
  initially treated the broken sibling as a pre-existing failure
  (because the baseline already had failures — not from the broken
  sibling). Honest red observed at the A8 test, fixed by ensuring
  the suite guard correctly captures failures in both snapshots and
  diffs them by name.
- green: 14 make_command + 3 sc_007 tests pass; the regression
  guard correctly names the regressed test in the failure report.
- refactor: none.
- commit: (this commit)

## Cycle 9: T024 — Misfire-stop policy (US4)

- behaviors: U7 (planner misfire on unexpressible behaviors), U10/U12
  (pipeline runner misfire on first failure / unresolvable
  entrypoint), U27 (any misfire leaves the test file and cycle log
  unchanged), A10-A12
- test: `test/plugins/tdd/make_command_test.dart` (US4 group: A10,
  A11, A12) and `test/plugins/tdd/scenarios/sc_008_misfire_stop_test.dart`
- red: misfire-stop was already implemented in the MakeCommand
  skeleton (cycle 6's try/catch + outcome assignment) — the US4
  tests verify each misfire class by name and assert no green
  evidence is written. The planner's `unexpressibleReason` was
  pinned in cycle 4's unit test, so the command-level US4 test was
  green on first run.
- green: 14 make_command + 3 sc_008 tests pass; the test file is
  byte-identical after a misfire (SC-004 verified).
- refactor: none.
- commit: (this commit)

## Cycle 10: T026 — Summary-line + exit-code contract (US5)

- behaviors: U29 (summary line is the final stdout line on every
  path; exit 0 exactly on green), A13-A14 (every invocation ends
  with the pinned summary line; exit code 0 only on green)
- test: `test/plugins/tdd/make_command_test.dart` (US5 group: U29/A13,
  A14) and `test/plugins/tdd/scenarios/sc_009_summary_contract_test.dart`
- red: the contract shape regex
  `^make: behavior=(\S+) outcome=(\S+) feature=(\S+)$` was pinned
  by these tests; the summary line was implemented in cycle 6's
  command skeleton, so the contract test was green on first run.
- green: 14 make_command + 2 sc_009 tests pass; the contract is
  stable enough for `zfa tdd run` to consume (SC-006).
- refactor: none.
- commit: (this commit)

## Cycle 11: T027-T029 — Polish

- behaviors: dart analyze and dart format pass on all touched files.
- test: full TDD scope (`dart test test/plugins/tdd/` fast +
  `--preset=all` slow scenarios for 047).
- red: none.
- green: 138 fast + 26 slow = 164 TDD tests pass; suite scoped to
  047 (`dart test --preset=all test/plugins/tdd/make_command_test.dart
  test/plugins/tdd/scenarios/sc_005_* test/plugins/tdd/scenarios/sc_006_*
  test/plugins/tdd/scenarios/sc_007_* test/plugins/tdd/scenarios/sc_008_*
  test/plugins/tdd/scenarios/sc_009_*`) → 26 passed, 0 failed.
- refactor: `dart format .` (29 files reformatted).
- commit: (this commit)

## Final green evidence (this branch)

- behaviors: A1-A14 (all 14 acceptance criteria), U1-U30 (all 30
  unit behaviors)
- runner: `dart test test/plugins/tdd/` → 138 passed, 0 failed (fast)
- runner: `dart test --preset=all test/plugins/tdd/make_command_test.dart
  test/plugins/tdd/scenarios/sc_005_* sc_006_* sc_007_* sc_008_* sc_009_*`
  → 26 passed, 0 failed (slow tier, this feature)
- summary: `make: behavior=047-tdd-make outcome=green feature=047-tdd-make`
- generation commands invoked:
  - `dart format .` (29 files reformatted; no semantic changes)
  - `dart analyze lib/src/plugins/tdd/ test/plugins/tdd/` (0 errors, 0 warnings; 2 pre-existing `no_leading_underscores` infos in 044's `artifact_record.dart` untouched)
- timestamp: 2026-08-30T15:30:00.000Z
