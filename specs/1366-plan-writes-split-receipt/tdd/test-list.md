# TDD Test List — Spec 1366

Red pre-fix: B1/B3 red (no receipt written without a pre-existing one);
B2 red (the lost-record refusal fires).

## Behaviors

| # | Behavior | Trace | Test file |
|---|--------|--------|-----------|
| B1 | Plan (no receipt) writes split-receipt.json: source=zfa tdd plan, spec hash, classification | FR-1 / AS-1 | test/plugins/tdd/commands/bug_1366_plan_writes_split_receipt_test.dart |
| B2 | The plan-written receipt satisfies the one-shot guard (no lost-record refusal) | FR-2 / AS-2 | test/plugins/tdd/commands/bug_1366_plan_writes_split_receipt_test.dart |
| B3 | A pre-existing receipt merges: custom fields survive, refresh fields update | FR-3 / AS-3 | test/plugins/tdd/commands/bug_1366_plan_writes_split_receipt_test.dart |

## Red protocol

```
dart test test/plugins/tdd/commands/bug_1366_plan_writes_split_receipt_test.dart
```
