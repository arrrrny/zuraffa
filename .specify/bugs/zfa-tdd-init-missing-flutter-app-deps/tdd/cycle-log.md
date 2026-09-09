# Cycle Log

## Cycle: B-U1 (+ B-A1, B-U2, B-U5, B-U6) (red)

- behavior: init on a Flutter project self-heals the app module's runtime deps under `dependencies:`
- kind: red
- classification: assertionFailure
- criterion: AC-runtime / AC-day-zero / AC-idempotent / AC-textual / AC-loud (assessment.md)
- test: test/cli/writers/tdd/bug_1349_init_flutter_app_deps_test.dart
- command: `dart test test/cli/writers/tdd/bug_1349_init_flutter_app_deps_test.dart`
- exit: 1
- at: 2026-09-09
- output:
```
00:00 +2 -5: Some tests failed.
Which: does not contain 'zuraffa_flutter: ^6.0.0'
```
(2 green: B-U3, B-U4 — preserved invariants; 5 red: the bug, see red-evidence.md)

## Cycle: fix (green)

- production change: `lib/src/plugins/tdd/commands/init_command.dart` ONLY —
  Flutter branch gains `_ensureFlutterAppDependencies` (+ textual patcher),
  wired after `AppModuleWriter` with the house catch-and-fail structure;
  constraints mirror `DependencyWirer.standardSet` (^6.0.0) and the repo's
  own `get_it: ^9.2.1`
- kind: green
- command: `dart test test/cli/writers/tdd/bug_1349_init_flutter_app_deps_test.dart`
- exit: 0
- at: 2026-09-09
- output:
```
00:00 +7: All tests passed!
```
- observed stdout on a Flutter fixture (the remediation contract):
```
   ✓ lib/app.dart (created)
   ✓ pubspec.yaml dependencies (app module: added: zuraffa_flutter: ^6.0.0, get_it: ^9.2.1)
   ✓ pubspec.yaml dev_dependencies (added: flutter_test:
  sdk: flutter, test: ^1.0.0, build_runner: ^2.4.0, json_serializable: ^6.7.0, coverage: ^1.15.1, mutation_test: ^1.8.0)
```

## Cycle: refactor / hardening

- `dart format` on the changed files (1 file reflowed: the new test);
  repo-wide dry-run check `dart format --output=none --set-exit-if-changed lib/ test/`
  → `Formatted 2443 files (0 changed)`, exit 0
- re-run after formatting: `00:00 +7: All tests passed!`

## Regression (only what the change touches)

- command: `dart test test/cli/writers/tdd/bug_1260_skin_dependency_patcher_test.dart test/cli/writers/tdd/pubspec_dev_dependencies_patcher_test.dart test/plugins/tdd/tdd_command_smoke_test.dart test/plugins/tdd/bug_969_json_verdict_envelope_test.dart`
- exit: 0
- at: 2026-09-09
- output:
```
00:01 +35: All tests passed!
```
(init-flow neighbors: the skin opt-in, the dev-deps patcher, the tdd
plugin smoke run, and the #969 verdict envelope)
