# Plan — Spec 1370 Flutter consumer test baseline

**Branch**: `1370-flutter-consumer-test-baseline` | **Date**: 2026-09-09 | **Spec**: [spec.md](./spec.md)

## Approach

`PubspecDevDependenciesPatcher.flutterDevDependencies` drops plain
`test` (comment records the #716 → #1189/#1351/#1370 supersession).
Pure-Dart map unchanged. example/pubspec.yaml drops the `test: ^1.0.0`
pin (the #1369 data fix superseded), comment updated. The #1369 baseline
pin flips to assert `test` ABSENT. Contract-lane `package:test` imports
in Flutter consumers recorded as a known limitation.

## Test strategy

`test/cli/writers/tdd/bug_1370_flutter_consumer_test_baseline_test.dart`
(B1 Flutter consumer → no plain test; B2 pure-Dart guard; B3 example data
pin) + the existing patcher suite updated to the corrected contract.
Scoped pin: writers/tdd + package_sdk + analyze.
