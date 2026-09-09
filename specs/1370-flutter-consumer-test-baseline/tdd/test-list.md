# TDD Test List — Spec 1370

Red pre-fix: B1/B3 red (the patcher prescribes test to Flutter consumers;
the example declares it); B2 guard green.

## Behaviors

| # | Behavior | Trace | Test file |
|---|--------|--------|-----------|
| B1 | Flutter consumer: patcher prescribes NO plain test; coverage/mutation_test added | FR-1 / AS-1 | test/cli/writers/tdd/bug_1370_flutter_consumer_test_baseline_test.dart |
| B2 | Pure-Dart project: test ^1.25.0 preserved (guard) | FR-2 / AS-2 | test/cli/writers/tdd/bug_1370_flutter_consumer_test_baseline_test.dart |
| B3 | The shipped example declares no plain test | FR-3 / AS-3 | test/cli/writers/tdd/bug_1370_flutter_consumer_test_baseline_test.dart |

## Red protocol

```
dart test test/cli/writers/tdd/bug_1370_flutter_consumer_test_baseline_test.dart
```
