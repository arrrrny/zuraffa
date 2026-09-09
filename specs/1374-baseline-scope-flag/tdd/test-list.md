# TDD Test List — Spec 1374

Red pre-fix: B1/B2 red (`Could not find an option named --baseline-scope`);
B3 guard green.

## Behaviors

| # | Behavior | Trace | Test file |
|---|--------|--------|-----------|
| B1 | run --baseline-scope prints the scoped baseline command | FR-1 / AS-1 | test/plugins/tdd/commands/bug_1374_baseline_scope_test.dart |
| B2 | make --baseline-scope prints the scoped baseline command | FR-2 / AS-2 | test/plugins/tdd/commands/bug_1374_baseline_scope_test.dart |
| B3 | Without the flag the baseline command stays unscoped | FR-3 / AS-3 | test/plugins/tdd/commands/bug_1374_baseline_scope_test.dart |

## Red protocol

```
dart test --preset=all test/plugins/tdd/commands/bug_1374_baseline_scope_test.dart
```
