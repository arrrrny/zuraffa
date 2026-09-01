# Cycle Log: `zfa tdd compose` — phase-2 acceptance make composition

Append only. Newest last. Every entry's `red` block is the evidence that the
test existed and failed before the implementation.

## Baseline

- suite: `dart test test/plugins/tdd/` (fast tier) -> 295 passed, 0 failed
- commit: `acdb3722`
- recorded: cycle 0, before any change

## Cycle 1: U1–U5 discovery + U6–U7 fallback planner + A9 purity pin

- test: `test/plugins/tdd/services/composition_targets_test.dart`,
  `test/plugins/tdd/services/composition_planner_test.dart` (new)
- red: `dart test test/plugins/tdd/services/composition_targets_test.dart`
  -> `Error: Couldn't resolve the file` — `CompositionTargets` /
  `CompositionPlanner` / `ComposableUnitSubject` did not exist (loading
  failure, the honest red for a new unit); the planner pin (A9) failed on
  the same load
- green: implemented `composition_targets.dart` (fail-closed discovery:
  test-list ∩ green cycle-log evidence ∩ existing subject artifacts, kind
  gate included) and `composition_planner.dart` (pure compose → build
  plan). Suite -> 5 passed (targets) + 6 passed (planner) after fixing two
  test-side fixture issues (lib/ dir creation; U5 asserted the parse
  error's line naming, which is the file-naming contract)
- refactor: none — both services are single-purpose and pure
- commit: recorded with the feature commit

## Cycle 2: A3–A8 compose command + U9–U16 unit behaviors

- test: `test/plugins/tdd/commands/compose_command_test.dart` (new, 13
  tests through the real CLI entry via `CliRunner`)
- red: `dart test test/plugins/tdd/commands/compose_command_test.dart` ->
  loading failure (`ComposeCommand` missing); after registration the U10
  ambiguity test caught a real defect — the success paths returned without
  resetting the process-global `exitCode`, so a compose following a refused
  one in the same process inherited exit 1 (`Expected: <0> Actual: <1>`)
- green: `ComposeCommand` implemented (wire's shape: resolution, stub
  signature, ownership refusals, idempotence, summary line) with explicit
  `exitCode = 0` on the composed/already-composed paths. Suite -> 13
  passed, 0 failed
- refactor: none needed; the command mirrors `wire_command.dart`'s
  structure deliberately
- commit: recorded with the feature commit

## Cycle 3: A10/A11/A13–A15 make fallback + U17–U20

- test: `test/plugins/tdd/make_command_test.dart` (extended with the
  `spec 052 — composition fallback on planner refusal` group, 6 tests)
- red: `dart test test/plugins/tdd/make_command_test.dart --preset=all` ->
  A13 failed: `target test still fails after generation (exit 1)` — the
  fixture's target test was a static `expect(1, equals(2))` that no
  generated subject could satisfy; the test-side fixture was wrong, not
  the fallback
- green: fixture switched to the subject-driven test discipline used by
  the entity-plan tests; suite -> 21 passed, 0 failed (15 pre-existing +
  6 new). The fallback executes compose → build through `PipelineRunner`,
  records both steps in the green entry, and honest-stops `unexpressible`
  on zero anchors / unit-kind / malformed list
- refactor: none
- commit: recorded with the feature commit

## Cycle 4: A1/A2 — the real-pipeline phase-2 flip (SC-021)

- test: `test/plugins/tdd/scenarios/sc_021_acceptance_composition_e2e_test.dart`
  (new, slow+integration, pure exec forwarder to the real `bin/zfa.dart`)
- red: with the implementation stashed (`git stash push` of compose/
  planner/targets/tdd_command/make_command), the SAME scenario run
  honest-stopped exactly as issue #642 describes:
  `run: feature=001-compose-demo result=stopped pending=0 red=1 green=1
  done=0 stopped_at=A1:make` — the phase-2 re-attempt deterministically
  repeated the phase-1 refusal
- green: with the implementation restored, the same run prints
  `[run] A1 make -> deferred (phase 2)` then
  `[run] A1 make -> green (phase 2)` and completes
  `result=complete pending=0 red=0 green=0 done=2`, exit 0; the composed
  `lib/tdd/a1_subject.dart` carries the GENERATED compose stamp, imports
  `package:tdd_fixture/tdd/u1_subject.dart`, and references `subject_u1`;
  A1's green entry records the `tdd compose A1` and `build` steps. Both
  tests passed (A1, A2)
- refactor: none
- commit: recorded with the feature commit

## Regression guards (post-green)

- sc_013–sc_016 (driver/deferral contracts, #625/#635): 4+5+3+4 passed,
  0 failed — the deferral outcomes and summary contracts are unchanged
- sc_017 (real pipeline, entity subject wiring): 1 passed
- sc_018 (entity-bearing acceptance all-DONE through the real pipeline —
  SC-005/A12): 1 passed
- fast tier, whole tdd scope: `dart test test/plugins/tdd/` -> 319 passed,
  0 failed (baseline 295 + 24 new)

## Notes and deviations

- The U10 exitCode finding (cycle 2) matches make/wire's explicit
  `exitCode = 0` on success; the tests pin the summary line as the final
  stdout line so the contract is observable, not assumed.
- SC-021's red was produced by stashing ONLY the implementation files
  (tests unchanged) — the recorded red/green pair is reproducible from
  the recorded stash diff in this branch's commit history.
