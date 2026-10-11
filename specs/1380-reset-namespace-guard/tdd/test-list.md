# TDD Test List — Spec 1380

Red pre-fix: B1 red (foreign files deleted); B2 guard green.

## Behaviors

| # | Behavior | Trace | Test file |
|---|--------|--------|-----------|
| B1 | Foreign same-id generated files survive a reset | FR-1 / AS-1 | test/plugins/tdd/commands/bug_1380_reset_namespace_guard_test.dart |
| B2 | Own-namespace drift recovery unchanged (#1331) | FR-2 / AS-2 | test/plugins/tdd/commands/bug_1380_reset_namespace_guard_test.dart |

## Red protocol

```
dart test --preset=all test/plugins/tdd/commands/bug_1380_reset_namespace_guard_test.dart
```
