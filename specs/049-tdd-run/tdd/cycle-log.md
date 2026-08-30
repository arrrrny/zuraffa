# Cycle Log: `zfa tdd run`

Append only. Newest last. Every entry's `red` block is the evidence that the
test existed and failed before the implementation.

## Baseline

- suite: `dart test test/plugins/tdd/` -> 116 passed, 0 failed (fast tier)
- commit: `43841d0c`
- recorded: cycle 0, before any change

## Notes and deviations

- Driver/scenario tests run in the `slow` tier with scripted fake step
  binaries; steps 047 (make) and 048 (refactor) may be unmerged — the driver
  consumes their contracts, not their code.
- Known zuraffa gap (to file via the bug workflow, task T025):
  `plan_command.dart` writes 4-column test-list rows while
  `gen_command.dart`'s parser expects 6 columns — gen cannot parse what plan
  emits. Not fixed by this feature.

## Cycle 1: outer loop opens — A1..A12 acceptance scenarios written first

- test: `test/plugins/tdd/scenarios/sc_013_run_drives_feature_test.dart` (A1, A2, A3),
  `sc_014_run_resumes_test.dart` (A4, A5, A6),
  `sc_015_run_stops_on_failure_test.dart` (A7, A8, A9),
  `sc_016_run_summary_contract_test.dart` (A10, A11, A12, SC-006) (all new)
- red: `dart test --preset=all test/plugins/tdd/scenarios/sc_013_run_drives_feature_test.dart`
  -> `Expected: contains 'run: feature=090-run-fixture result=complete
  pending=0 red=0 green=0 done=3'` / `Actual: '❌ Could not find an option
  named "--project". Usage: zfa tdd run <feature>'` (13 failed across the
  four files — the misfire-stop stub exposes neither flags nor driver)
- state: A1..A12 RED (outside-in: the acceptance tests stay red until the
  units beneath them land)
- notes: fixture extensions (task T001: 4-column test-list seeding,
  run-state seeding, green-evidence seeding, scripted fake zfa binary with
  invocation log) written as test infrastructure before the scenarios
- commit: 9986bfec

## Cycle 2: U1..U3 test_list_reader parses the plan-format test list

- test: `test/plugins/tdd/services/test_list_reader_test.dart::U1: parses
  4-column rows in list order`, `::U2: kind is inferred from the section
  header`, `::U3: a malformed row stops with an error naming the line`
  (+ unknown-state and missing-list cases) (new)
- red: `dart test test/plugins/tdd/services/test_list_reader_test.dart`
  -> `Which: threw UnimplementedError` (5 failed)
- green: implemented `read()` — section-header kind tracking, separator/
  header skipping, 4-column parse with line-naming errors. Suite `dart
  test test/plugins/tdd/` -> 121 passed
- refactor: extracted `_parseDataRow` with a `Never malformed()` helper so
  null checks promote; suite re-run green
- commit: 9986bfec

## Cycle 3: U4..U6 cycle_evidence red/green sets from the cycle log

- test: `test/plugins/tdd/services/cycle_evidence_test.dart::U4: red
  evidence = behaviors with a kind: red section`, `::U5: green evidence =
  behaviors with a kind: green section`, `::U6: a missing cycle log yields
  empty sets, not an error` (+ no-behavior-line case) (new)
- red: `dart test test/plugins/tdd/services/cycle_evidence_test.dart`
  -> `Which: threw UnimplementedError` (4 failed)
- green: `_evidence(kind)` generalizes verify-red's `split('\n## ')`
  section parsing. Suite -> 125 passed
- refactor: none needed beyond the shared `_evidence` helper (the
  generalization IS the refactor of verify-red's private copy)
- commit: 9986bfec

## Cycle 4: U7..U11 run_state_store atomic persistence + guards

- test: `test/plugins/tdd/services/run_state_store_test.dart::U7: save ->
  load round-trips states and in-flight markers`, `::U8: saves are atomic
  — no tmp residue, previous intact on failure`, `::U9: corrupted JSON
  stops with the corruption and recovery path`, `::U10: a held in-flight
  marker refuses the second run`, `::U11: behaviors removed from the test
  list are retained as dropped` (new)
- red: `dart test test/plugins/tdd/services/run_state_store_test.dart`
  -> `Which: threw UnimplementedError` (8 failed)
- green: temp+rename atomic save, validating `_validated()` load mapping
  every shape violation to a corruption error naming the recovery path,
  `refusalReason` PID-liveness guard (injectable probe), `computeDropped`
  retention. Suite -> 133 passed
- refactor: `RunState` model gained `inFlightOwnerPid` carried through
  `advance`/`markInFlight`/`toJson`/`fromJson` (U30 semantics unchanged:
  `run_state_test.dart` still 4/4 green)
- commit: 9986bfec

## Cycle 5: U12..U18 step_runner spawns steps and consumes contracts

- test: `test/plugins/tdd/services/step_runner_test.dart::U12: steps spawn
  with argv tdd <step> <id> --feature --project`, `::U13: verify-red
  succeeds only on exit 0 AND certified=true`, `::U14: make succeeds only
  on exit 0 AND outcome=green`, `::U15: refactor succeeds on
  outcome=clean or outcome=refactored`, `::U16: gen succeeds on exit 0`,
  `::U17: a spawn failure yields a runner-error StepResult, not a crash`,
  `::U18: --zfa-bin overrides entrypoint resolution` (+ missing-summary
  and defaultZfaBin cases) (new)
- red: `dart test test/plugins/tdd/services/step_runner_test.dart`
  -> `Which: threw UnimplementedError` (9 failed)
- green: argv assembly (dart-prefixed `.dart` entries, direct exec
  otherwise), last-summary-line key=value parser, per-step success rules,
  ProcessException -> runner-error. Suite -> 144 passed
- refactor: none needed; the spawner seam keeps the fast tier hermetic
- commit: 9986bfec

## Cycle 6: U19..U29 the driver itself

- test: `test/plugins/tdd/run_command_test.dart::U19: per-behavior step
  order is gen -> verify-red -> make -> refactor`, `::U20: state is
  persisted after every completed step`, `::U21: a done claim without
  red+green evidence demotes to the evidence-backed state`, `::U22:
  resume skips DONE and re-enters at the state-implied step`, `::U23: an
  in-flight step at load re-executes that step`, `::U24: the failure
  matrix stops the run with correct residual state` (+ missing-binary and
  no-evidence misfire cases), `::U25: each step completion prints its
  progress line`, `::U26: the summary line carries feature, result,
  counts, stopped_at`, `::U27: exit 0 exactly on complete-with-evidence`,
  `::U28: an all-DONE run performs zero step invocations and exits 0`,
  `::U29: new test-list rows enter as PENDING, DONE behaviors untouched`
  (new)
- red: `dart test --preset=all test/plugins/tdd/run_command_test.dart`
  -> `❌ Could not find an option named "--project"` (13 failed against
  the misfire-stop stub)
- green: RunCommand.run() — load -> corruption/concurrency guards ->
  test-list read -> evidence reconcile (demotion + skip-if-unchanged) ->
  mark->save->spawn->advance->save loop with per-step evidence checks ->
  progress lines + machine summary + exit codes 0/1/2/3/4. Suite
  `dart test --preset=all test/plugins/tdd/` -> 238 passed
- refactor: spawn/tooling failures classified `runner-error` (exit 2)
  separately from contract `stopped` (exit 1) after the first green run
  exposed the conflation
- commit: 9986bfec

## Cycle 7: outer loop closes — A1..A12 green

- test: the four scenario files from Cycle 1
- green: `dart test --preset=all
  test/plugins/tdd/scenarios/sc_013_run_drives_feature_test.dart
  test/plugins/tdd/scenarios/sc_014_run_resumes_test.dart
  test/plugins/tdd/scenarios/sc_015_run_stops_on_failure_test.dart
  test/plugins/tdd/scenarios/sc_016_run_summary_contract_test.dart`
  -> +29: All tests passed (13 new acceptance tests + 16 pre-existing
  046 scenarios, all green)
- refactor: two scenario-side expectation corrections after the first
  green run (A7/A8 count semantics: a behavior whose make failed stays
  RED, one whose verify-red failed stays PENDING — the driver's counts
  were right, the tests were wrong); no production change
- commit: 9986bfec

## Notes and deviations (session 2, implement phase)

- Known zuraffa gap FILED (task T025):
  `.specify/bugs/plan-gen-test-list-column-mismatch/` — `plan_command`
  writes 4-column test-list rows while `gen_command`'s parser requires 6;
  reproduced locally (`zfa tdd gen: unknown behavior id`, exit 1). Not
  fixed here (044/041 own those commands).
- The repo's `dart_test.yaml` excludes the `slow` tag by default, so
  `dart test --tags slow <files>` (the command quickstart.md originally
  recorded from the planning profile) selects nothing; the working form
  is `dart test --preset=all <files>`. quickstart.md was corrected.
- Commits follow the repository's feature-scale convention (behavioral
  commit `9986bfec` carries each cycle's test+implementation together;
  the format-only drift fix `b8352205` is a separate structural commit)
  rather than one commit per cycle.

## Cycle 8: verification remediation (post-audit)

- test: `test/plugins/tdd/run_command_test.dart::U23` and
  `test/plugins/tdd/scenarios/sc_014_run_resumes_test.dart::A5`
  strengthened; new
  `run_command_test.dart::FR-008: the driver never modifies test/ or lib/ itself`
- red: deliberate-mutant audit — the ignore-the-in-flight-marker mutant
  survived U23/A5 (their seeds coincided with the state-implied step):
  `dart test --preset=all ... --plain-name "U23"` -> `+1: All tests
  passed!` WITH the mutant in place (the failure the tests failed to
  produce)
- green: discriminating seeds added (state PENDING + marker verify-red,
  dead owner) asserting first invocation `verify-red B-002` and zero
  `gen B-002` invocations; mutant re-applied -> `+0 -1: Some tests
  failed!` on both tests; restored exactly; suite `dart test --preset=all
  test/plugins/tdd/` -> 239 passed
- refactor: none
- commit: 075aab18
