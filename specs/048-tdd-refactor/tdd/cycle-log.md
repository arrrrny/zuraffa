# Cycle Log: `zfa tdd refactor`

Append only. Newest last. Every entry's `red` block is the evidence that the
test existed and failed before the implementation.

## Baseline

- suite: `dart test test/plugins/tdd/` -> 116 passed, 0 failed (fast tier)
- commit: `43841d0c`
- recorded: cycle 0, before any change

## Notes and deviations

- Command and scenario tests for this feature run in the `slow` tier
  (`@Tags(['slow'])`), mirroring 046/047.
- Coordination: the `runner.dart` suite extension is also planned by
  047-tdd-make; whichever branch merges first owns it, the other rebases.
  As of this branch, 047 has not landed on master, so 048 owns the
  `loadSuiteTemplate` / `runSuite` extension.

## Cycle 1 — Red: foundation behaviors (U6, U7, U11, U12, U8, U9, U1-U5)

- behavior: 048-foundation-red
- kind: red
- classification: assertionFailure
- criterion: FR-001..FR-010
- test: test/plugins/tdd/services/tree_snapshot_test.dart, test/plugins/tdd/services/refactor_passes_test.dart, test/plugins/tdd/models/refactor_action_test.dart, test/plugins/tdd/runner_suite_test.dart
- command: `dart test test/plugins/tdd/models/refactor_action_test.dart test/plugins/tdd/services/tree_snapshot_test.dart test/plugins/tdd/services/refactor_passes_test.dart test/plugins/tdd/runner_suite_test.dart`
- exit: 1
- at: 2026-08-30T15:10:00.000Z
- output:
```
4 test files failed to load (compile errors):
  - refactor_action_test.dart: target file 'package:zuraffa/src/plugins/tdd/models/refactor_action.dart' does not exist
  - tree_snapshot_test.dart: target file 'package:zuraffa/src/plugins/tdd/services/tree_snapshot.dart' does not exist
  - refactor_passes_test.dart: target file 'package:zuraffa/src/plugins/tdd/services/refactor_passes.dart' does not exist
  - runner_suite_test.dart: 'SingleTestRunner' has no method 'loadSuiteTemplate' / 'runSuite'
00:00 +0 -4: Some tests failed.
```

## Cycle 1 — Green: foundation behaviors (U6, U7, U11, U12, U8, U9, U1-U5)

- behavior: 048-foundation-green
- kind: green
- criterion: FR-001..FR-010
- test: test/plugins/tdd/services/tree_snapshot_test.dart, test/plugins/tdd/services/refactor_passes_test.dart, test/plugins/tdd/models/refactor_action_test.dart, test/plugins/tdd/runner_suite_test.dart, test/plugins/tdd/models/cycle_entry_test.dart
- command: `dart test test/plugins/tdd/models/refactor_action_test.dart test/plugins/tdd/services/tree_snapshot_test.dart test/plugins/tdd/services/refactor_passes_test.dart test/plugins/tdd/runner_suite_test.dart test/plugins/tdd/models/cycle_entry_test.dart`
- exit: 0
- at: 2026-08-30T15:15:00.000Z
- output:
```
00:00 +40: All tests passed!
```

## Cycle 2 — Red: command + scenario behaviors (U13-U22, A1-A11)

- behavior: 048-command-red
- kind: red
- classification: assertionFailure
- criterion: FR-001..FR-010
- test: test/plugins/tdd/refactor_command_test.dart, test/plugins/tdd/scenarios/sc_010_refuses_red_suite_test.dart, test/plugins/tdd/scenarios/sc_011_tool_only_and_test_immutable_test.dart, test/plugins/tdd/scenarios/sc_012_reproves_green_test.dart
- command: `dart test --preset=all test/plugins/tdd/refactor_command_test.dart test/plugins/tdd/scenarios/sc_010_refuses_red_suite_test.dart test/plugins/tdd/scenarios/sc_011_tool_only_and_test_immutable_test.dart test/plugins/tdd/scenarios/sc_012_reproves_green_test.dart`
- exit: 1
- at: 2026-08-30T15:25:00.000Z
- output:
```
17 tests failed. `--project` option is rejected by the RefactorCommand
stub (it throws StateError "not yet implemented"). The command-level
behaviors U13-U22 and acceptance scenarios A1-A11 are unimplemented.
```

## Cycle 2 — Green: command + scenario behaviors (U13-U22, A1-A11)

- behavior: 048-command-green
- kind: green
- criterion: FR-001..FR-010
- test: test/plugins/tdd/refactor_command_test.dart, test/plugins/tdd/scenarios/sc_010_refuses_red_suite_test.dart, test/plugins/tdd/scenarios/sc_011_tool_only_and_test_immutable_test.dart, test/plugins/tdd/scenarios/sc_012_reproves_green_test.dart
- command: `dart test --preset=all test/plugins/tdd/refactor_command_test.dart test/plugins/tdd/scenarios/sc_010_refuses_red_suite_test.dart test/plugins/tdd/scenarios/sc_011_tool_only_and_test_immutable_test.dart test/plugins/tdd/scenarios/sc_012_reproves_green_test.dart`
- exit: 0
- at: 2026-08-30T15:35:00.000Z
- output:
```
02:16 +22: All tests passed!
```

Plus the fast-tier regression check:
- command: `dart test test/plugins/tdd/`
- exit: 0
- at: 2026-08-30T15:36:00.000Z
- output:
```
00:05 +148: All tests passed!
```
(116 baseline + 32 new fast tests, no regressions.)




