# Cycle Log

Append only. Newest last. Every entry's `red` block is the evidence that the test existed and failed before the implementation.

## Cycle: J-001..J-012 (red)

- behavior: J-001..J-012
- kind: red
- classification: assertionFailure
- criterion: FR-001..FR-006
- test: test/plugins/tdd/unified_journal_commands_test.dart
- command: `dart test --preset=all test/plugins/tdd/unified_journal_commands_test.dart`
- exit: 1
- at: 2026-09-06T13:55:00.000Z
- output:
```
01:18 +0 -12: Some tests failed.

Failing tests: all 12 — the run/status groups fail because
specs/004-login-ui/tdd/journal.json is never written (File does not
exist), the prove group fails with the runner's usage error
"Could not find a subcommand named prove" (the command does not
exist), and status prints no journal verdict line. The 12
command-level tests were written FIRST and proven RED on the
pre-change tree, exactly the spec-049 discipline (+0 -12).
```

## Cycle: J-001..J-014 (green)

- behavior: J-001..J-014
- kind: green
- criterion: FR-001..FR-006
- test: test/plugins/tdd/unified_journal_commands_test.dart, test/plugins/tdd/services/journal_test.dart, test/plugins/tdd/theater/theater_journal_integration_test.dart
- command: `dart test --preset=all test/plugins/tdd/unified_journal_commands_test.dart test/plugins/tdd/services/journal_test.dart test/plugins/tdd/theater/`
- exit: 0
- at: 2026-09-06T15:30:00.000Z
- output:
```
03:02 +65: All tests passed.

12/12 command-level (unified_journal_commands_test, slow tier: the
004-login-ui fixture, real CLI runs through CliRunner.runCapturing),
17/17 service-level (journal_test: schema document, writer atomicity,
reader stream, fingerprints), 15/15 theater (12 pre-existing + 3 new
JournalReader-integration). The mid-loop fix the red phase forced: the
bug-#828 write-ahead transaction marker already owned tdd/journal.json
and clobbered unified entries on every step commit — renamed to
tdd/transaction.json (its own test updated; 4 pre-existing master-HEAD
doctor reds verified identical on a pure-master stash, untouched).
```
