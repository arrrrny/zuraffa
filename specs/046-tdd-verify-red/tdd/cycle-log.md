# Cycle Log: `zfa tdd verify-red`

Append only. Newest last. Every entry's `red` block is the evidence that the
test existed and failed before the implementation.

## Baseline

- suite: `dart test test/plugins/tdd/` -> 104 passed, 2 failed
- commit: `0118a465`
- recorded: cycle 0, before any change

## Notes and deviations

- Pre-existing red at baseline (feature 044 tests, not caused by this
  feature): `verify_command_test.dart` NOT_ASSESSED expectation failure, and
  `gen_command_test.dart` PathNotFoundException from a temp-dir cwd restore
  after `verify_command_test` deletes its fixture. The loop must not start on
  top of these; fix or quarantine before cycle 1.

## Cycle 0 correction: baseline is green

- suite: `dart test test/plugins/tdd/` -> 106 passed, 0 failed, exit 0
- commit: `938a5aec`
- recorded: before cycle 1, re-verified at loop start

The two pre-existing 044 failures named in the original baseline note
(`verify_command_test.dart` NOT_ASSESSED expectation;
`gen_command_test.dart` temp-dir cwd restore) are fixed at `938a5aec`.
This entry corrects the record; the original note above is left untouched
because the log is append-only.

## Pre-cycle housekeeping (recorded before cycle 1)

- profile fix: `.specify/memory/tdd-profile.md` single-test command used
  `-P` which `dart test` interprets as `--preset` ("Undefined preset"),
  so every single-test invocation failed before reaching any test.
  Corrected to `dart test <file> --plain-name "<name>"` and a
  machine-readable Keys block added (same shape `zfa setup` writes).
- seed removal: the `zfa tdd gen B-003` demo pair committed in `938a5aec`
  (`test/tdd/b_003_test.dart`, `lib/tdd/b_003_subject.dart`, its
  `specs/044-test-tdd-generation/tdd/artifacts.json` record) was removed.
  Its registry record carried machine-local absolute paths
  (`/Users/.../zuraffa/...`) that resolve nowhere else, and its committed
  red test fails the full `dart test test` CI gate with no implementation
  to turn it green (`zfa tdd make` is a later feature). Nothing references
  the pair; the 046 test suite builds its own self-contained fixtures.

## Cycle 1: U15, U16 — CycleLogEntry 8-field contract + widened FailureClass

- behaviors: U15 (toMarkdown emits the 8 contract fields in fixed order),
  U16 (FailureClass gains skipped + runnerError, round-trips by name)
- test: `test/plugins/tdd/models/cycle_entry_test.dart` (new) — 4 new
  tests; 4 pre-existing tests updated for the widened constructor
  (sourceCriterion, testPath, timestamp are now required). Blast radius:
  `test/plugins/tdd/services/cycle_log_test.dart` call sites updated too.
- red: `dart test test/plugins/tdd/models/cycle_entry_test.dart` ->
  compile error (fields absent) -> minimal field stubs added -> assertion
  failure `Expected: <2> Actual: <1>` at the ordered-fields check:
  `"- criterion: FR-006" must appear after the previous contract field`
  (the stub toMarkdown did not emit criterion/test/at). That assertion
  failure is the recorded red for U15; U16's red was the same compile
  error phase (enum values absent).
- green: `toMarkdown()` now emits behavior, kind, classification,
  criterion, test, command, exit, at, output in the fixed order;
  `FailureClass` widened to six values. Suite
  `dart test test/plugins/tdd/` -> 110 passed, 0 failed.
- refactor: none needed — the rendering is one writeln cascade in the
  shape the contract pins.
- commit: (this commit)

## Cycle 2: U1-U10 — RedClassification model + pure classify()

- behaviors: U1-U10 (the full classifier fixture matrix) plus the
  RedClassification/RunRecord model contract
- test: `test/plugins/tdd/red_classifier_test.dart` (new) — 30 tests;
  canned outputs captured from real `dart test` 3.13 runs (assertion,
  flutter-shaped assertion, green, skipped, missing file, missing import,
  compile error, bare CFE/flutter compile shape, blended, uncaught error,
  timeout)
- red: `dart test test/plugins/tdd/red_classifier_test.dart` ->
  `Error: Error when reading
  'lib/src/plugins/tdd/models/red_classification.dart': No such file or
  directory` (modules absent — compile-level red, the language needs the
  symbols first)
- green: implemented `models/red_classification.dart` (six-way enum with
  kebab labels + remediation hints, RunRecord value object) and
  `services/red_classifier.dart` (pure `classify()` with the fixed
  precedence runner-start -> load -> compile -> count-guard -> skip ->
  green -> assertion -> runner-error, plus `parseExecutedTestCount()` on
  the last progress line). Suite
  `dart test test/plugins/tdd/` -> 140 passed, 0 failed.
- refactor: none — the rules are one cascade in the order research.md
  Decision 3 pins.
- commit: (this commit)

## Cycle 3: U11-U14 — SingleTestRunner service (+ T001 fixture helper)

- behaviors: U11 ({file}/{name} substitution into the executed command),
  U12 (exit code + combined stdout/stderr capture), U13
  (startedProcess=false on failed launch), U14 (executes in the provided
  working directory); plus the profile loader contract that feeds U27
  (Keys-block first, bullet fallback with <path>/<name> normalization,
  misfire-stop on missing profile / missing single template)
- test: `test/plugins/tdd/runner_test.dart` (new, 9 tests) +
  `test/plugins/tdd/helpers/tdd_fixture.dart` (T001: temp project builder
  with pubspec, profile, artifacts.json, per-kind test contents, and
  test/lib fingerprints for SC-003). U11/U12/U14 run REAL `dart test`
  subprocesses inside the fixture.
- red: `dart test test/plugins/tdd/runner_test.dart` -> `Error: Error
  when reading 'lib/src/plugins/tdd/services/runner.dart': No such file
  or directory` + `Couldn't find constructor 'SingleTestRunner'` — the
  module did not exist (compile-phase red; the test was written first,
  then the module landed in one step, so no intermediate assertion red
  was observed; noted here for the audit).
- green: `services/runner.dart` — loadSingleTemplate() resolves the Keys
  block then the bullet, _normalize() maps legacy placeholders,
  runSingle() tokenizes BEFORE substitution (spaces in test names stay
  one argument), strips template quoting, executes via Process.run with
  workingDirectory, catches ProcessException into startedProcess=false,
  and returns RunRecord with parseExecutedTestCount(). Suite
  `dart test test/plugins/tdd/` -> 149 passed, 0 failed.
- refactor: none needed; the service is one cohesion unit (load +
  substitute + execute + capture).
- commit: (this commit)

## Cycle 4: U23, U25, U27, A1-A3 — VerifyRedCommand certified path

- behaviors: U23 (certified run appends exactly one 8-field red entry),
  U25 (no write/create/delete under test/ or lib/), U27 (missing profile
  misfire-stops before any run), A1-A3 (acceptance: classify assertion +
  entry + exit 0; all 8 contract fields; checksum-verified read-only)
- test: `test/plugins/tdd/verify_red_command_test.dart` (new, 4 tests)
  + `test/plugins/tdd/scenarios/sc_001_certifies_honest_red_test.dart`
  (new, 3 tests). Both drive the real CLI surface via
  `CliRunner(exitOnCompletion: false).runCapturing` with a TddFixture
  project and REAL `dart test` subprocess runs.
- red: `dart test test/plugins/tdd/verify_red_command_test.dart` ->
  assertions failed against the misfire-stop stub:
  `Actual: '❌ Error: Bad state: zfa tdd verify-red: not yet implemented
  (Phase 7 of specs/041-tdd-setup-plugin/tasks.md, tasks T055-T061).'`
  — honest assertion red (the tests expected the summary line, the log
  entry, and exit code 0; the stub provides none).
- green: implemented `verify_red_command.dart` — registry-driven target
  resolution (explicit id / single-certified inference / ambiguity
  errors listing candidates), profile template loading with
  misfire-stop, SingleTestRunner execution, classify(), evidence append
  via CycleLog on assertion only, summary line as the final stdout line
  via print() (captured by runCapturing), and rejection signaling
  through dart:io `exitCode` (CliRunner honors it — no throw, so the
  summary stays last). Two test-side bugs found and fixed during the
  cycle (swapped expect() arguments; a misfire message emitted via
  stdout.writeln bypassed the capturing zone — switched to print()).
  Suite `dart test test/plugins/tdd/` -> 156 passed, 0 failed.
- refactor: none this cycle (the command is the single new unit).
- commit: (this commit)
