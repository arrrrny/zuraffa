# TDD Cycle Log — Spec 1369

## RED (2026-09-09)
- `dart test test/package_sdk/bug_1369_example_tdd_baseline_test.dart`
- `+0 -2` — the shipped pubspec declares no `test`/`coverage` (the issue
  signature: the gen'd engine test cannot resolve package:test).
- Committed as certified red before the data fix.

## GREEN (2026-09-09)
- Baseline deps added to example/pubspec.yaml (writer-canonical
  constraints, issue-reference comment). `+2 All tests passed!`;
  package_sdk pin clean; analyze clean.
