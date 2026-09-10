# TDD Test List — Spec 1387

Contract pin (both halves green on master; the pin exists so drift fails).

## Behaviors

| # | Behavior | Trace | Test file |
|---|--------|--------|-----------|
| B1 | Orchestrator skip → exit 0 + Done | FR-1 / AS-1 | test/plugins/tdd/commands/bug_1387_guard_exit_contract_test.dart |
| B2 | Standalone guard-skip → exit 1 + no-files note | FR-2 / AS-2 | test/plugins/tdd/commands/bug_1387_guard_exit_contract_test.dart |

## Red protocol

```
dart test test/plugins/tdd/commands/bug_1387_guard_exit_contract_test.dart
```
