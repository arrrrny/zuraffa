# Cycle Log

Append only. Newest last. Every entry's `red` block is the evidence that the test existed and failed before the implementation.

## Cycle: B1-B11 (red)

- behavior: 1334-proof-check-end-to-end-validation
- kind: red
- classification: compileError (red-protocol TODO — the module did not exist; re-run after skeleton)
- criterion: specs/1334-proof-check-end-to-end-validation/tdd/test-list.md B1-B11
- test: test/core/proof_chain_checker_test.dart
- command: `dart test test/core/proof_chain_checker_test.dart`
- exit: 255
- at: 2026-09-09T00:00:00.000Z
- output:
```
Failed to load "test/core/proof_chain_checker_test.dart":
  test/core/proof_chain_checker_test.dart:7:8: Error: Error when reading
  'lib/src/core/proof/proof_chain_checker.dart': No such file or directory
  import 'package:zuraffa/src/core/proof/proof_chain_checker.dart';
```

Direct CLI reproduction (B4, pre-implementation):

```
$ dart run bin/zuraffa.dart proof chain
❌ Could not find a subcommand named "chain" for "zfa proof".
```

Exit code 2 (usage — the subcommand was not registered).

## Cycle: B1-B11 (green)

- behavior: 1334-proof-check-end-to-end-validation
- kind: green
- criterion: specs/1334-proof-check-end-to-end-validation/tdd/test-list.md B1-B11
- test: test/core/proof_chain_checker_test.dart
- command: `dart test test/core/proof_chain_checker_test.dart`
- exit: 0
- at: 2026-09-09T00:00:00.000Z
- output:
```
00:00 +27: B11 — read-only auditor check() leaves every input file unchanged
00:00 +28: All tests passed!
```

28/28 — every behavior B1-B3, B5-B11 green for the pure checker core.

Mid-loop fix (recorded honestly): B7's unit fixtures initially omitted the
`source_criterion`/`test_ownership`/`subject_ownership`/`created_at` fields
`ArtifactRecord.fromJson` requires, so `ArtifactRegistry.loadAll` parsed zero
records and the runner was never invoked (invoked=0, items=0). Fixing the
FIXTURES (not the implementation) to mirror the real on-disk
`artifacts.json` shape turned B6/B7 green.

## Cycle: B4 (green)

- behavior: 1334-proof-check-end-to-end-validation
- kind: green
- criterion: specs/1334-proof-check-end-to-end-validation/tdd/test-list.md B4
- test: test/commands/proof_chain_command_test.dart
- command: `dart test test/commands/proof_chain_command_test.dart`
- exit: 0
- at: 2026-09-09T00:00:00.000Z
- output:
```
00:00 +7: the proof group help lists both subcommands
00:00 +8: (tearDownAll)
00:39 +8: All tests passed!
```

8/8 — clean project exit 0, `--json` parseable `proof-chain.v1`, drifted
receipt exit 1 with expected/actual digests, gap-only exit 0, infra exit 2
(receipts path occupied by a file), the #807 `proof check --format=json`
regression guard, and the group help listing.

## Cycle: B12 (green — regression guard, never red)

- behavior: 1334-proof-check-end-to-end-validation
- kind: green
- criterion: specs/1334-proof-check-end-to-end-validation/tdd/test-list.md B12
- test: test/commands/proof_command_test.dart + test/core/proof_checker_test.dart + test/core/proof/proof_check_valid_test.dart
- command: `dart test test/commands/proof_command_test.dart test/core/proof_checker_test.dart test/core/proof/proof_check_valid_test.dart`
- exit: 0
- at: 2026-09-09T00:00:00.000Z
- output:
```
00:00 +19: All tests passed!
```

19/19 across the three pre-existing proof suites — the #807 surface is
byte-for-byte unchanged in behavior (its command class, flags and engine
were never edited; only the group constructor gained the new `chain`
subcommand registration).

## Full-tree run (the honest verdict on THIS repo)

- command: `dart run bin/zuraffa.dart proof chain`
- exit: 1
- verdict: 131 drift, 1611 gap, 11 info — FAIL

The 131 `test_integrity` drifts are PRE-EXISTING registry state: committed
`artifacts.json` records carry machine-specific absolute paths (e.g.
`/workspace/zuraffa/.worktrees/...`) or comma-joined legacy multi-path
records that do not resolve on any other clone. The chain auditor reports
them honestly — that is the feature working, not a regression introduced by
this PR. The 1611 gaps are the repo's open chain links (specs without green
evidence in their cycle-logs) — reported, not failed, exactly per the
issue's severity contract.
