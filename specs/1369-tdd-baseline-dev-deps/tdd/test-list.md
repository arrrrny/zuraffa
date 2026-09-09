# TDD Test List — Spec 1369

Red pre-fix: B1/B2 red — the shipped pubspec lacks `test` and `coverage`.

## Behaviors

| # | Behavior | Trace | Test file |
|---|--------|--------|-----------|
| B1 | The example baseline declares the TDD dev_dependencies (test, coverage, mutation_test, flutter_test) | FR-1 / AS-1 | test/package_sdk/bug_1369_example_tdd_baseline_test.dart |
| B2 | The constraints equal the writer-canonical set (^1.0.0 / ^1.15.1 / ^1.8.0) | FR-2 / AS-2 | test/package_sdk/bug_1369_example_tdd_baseline_test.dart |

## Red protocol

```
dart test test/package_sdk/bug_1369_example_tdd_baseline_test.dart
```
