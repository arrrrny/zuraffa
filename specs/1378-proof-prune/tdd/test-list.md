# TDD Test List — Spec 1378 proof prune

Red pre-fix: B1-B4 red — `Could not find a subcommand named "prune"`.

## Behaviors

| # | Behavior | Trace | Test file |
|---|--------|--------|-----------|
| B1 | Dry run lists the dead sandbox receipt, deletes nothing | FR-1 / AS-1 | test/commands/bug_1378_proof_prune_test.dart |
| B2 | --apply deletes the dead receipt, keeps the live one | FR-2 / AS-2 | test/commands/bug_1378_proof_prune_test.dart |
| B3 | Partial receipt kept even under --apply | FR-3 / AS-3 | test/commands/bug_1378_proof_prune_test.dart |
| B4 | Empty receipts store → `no receipts` (exit 0) | FR-4 / AS-4 | test/commands/bug_1378_proof_prune_test.dart |

## Red protocol

```
dart test test/commands/bug_1378_proof_prune_test.dart
```
