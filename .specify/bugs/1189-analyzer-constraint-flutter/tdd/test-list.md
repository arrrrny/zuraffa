# Test list — Issue #1189

The "unit under test" is the dependency graph itself; tests are
resolution/compile gates rather than dart test files (there is no Dart
API surface change to unit-test). Each test is executable and was run.

| ID | Test | Proves | Command |
|----|------|--------|---------|
| T1 | example/ Flutter consumer resolves | BR-1, BR-2 | `flutter pub get` in `example/` (exit 0) |
| T2 | Tiny core+flutter_test app resolves with zero overrides | BR-1 | `tools/flutter_smoke_gate.sh` stage 2 (exit 0) |
| T3 | Public surface compiles + runs under flutter_test | BR-3 | `tools/flutter_smoke_gate.sh` stage 3 (`flutter test`, all passed) |
| T4 | Gate is non-vacuous (RED on pre-fix pubspec) | BR-5 | `git stash && tools/flutter_smoke_gate.sh` → exit 1, then `git stash pop` |
| T5 | Package analyzes clean at widened lower bound (analyzer 14.0.0) | BR-4 | temp `dependency_overrides: analyzer: 14.0.0` + `dart pub get` + `dart analyze lib test` → exit 0 |
| T6 | Analyzer info parity with pre-fix baseline | BR-4 | `dart analyze lib test` issue count == 103 (baseline) |
| T7 | No regression in the fast suite | BR-4 (backstop) | `tools/run_tests_chunked.sh` → all chunks pass |
