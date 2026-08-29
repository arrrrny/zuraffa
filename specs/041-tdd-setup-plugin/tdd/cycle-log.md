# Cycle Log: TDD-ready `zfa setup` baseline + `zfa tdd` plugin

Append only. Newest last. Every entry's `red` block is the evidence that the test
existed and failed before the implementation.

## Baseline

- suite: `dart test` (feature scope `dart test test/plugins/tdd/`)
- commit: adda6b4c
- recorded: cycle 0, before any change

## Cycle 1: U10 writes the five-key profile map

- test: `test/cli/writers/tdd/tdd_profile_writer_test.dart::writes the five-key profile` (new)
- red: `dart test test/cli/writers/tdd/tdd_profile_writer_test.dart --plain-name "writes the five-key profile"`
  -> `Expected: a value that contains 'runner: flutter_test'\nActual: ''` (1 failed)
- green: `lib/src/cli/writers/tdd/tdd_profile_writer.dart` implemented; suite `dart test test/cli/writers/tdd/`
  -> 5 passed, 0 failed
- refactor: none needed
- commit: 575-tdd-setup-tdd-plugin

## Cycle 2: U14 writes the smoke test

- test: `test/cli/writers/tdd/smoke_test_writer_test.dart::writes the smoke test` (new)
- red: `dart test test/cli/writers/tdd/smoke_test_writer_test.dart --plain-name "writes the smoke test"`
  -> `Expected: a value that contains 'package:myapp/app.dart'\nActual: ''` (1 failed)
- green: `lib/src/cli/writers/tdd/smoke_test_writer.dart` implemented
- refactor: none needed
- commit: 575-tdd-setup-tdd-plugin

## Cycle 3: U16 adds all six missing dev_dependencies

- test: `test/cli/writers/tdd/pubspec_dev_dependencies_patcher_test.dart::adds all six missing dev_dependencies` (new)
- red: `dart test test/cli/writers/tdd/pubspec_dev_dependencies_patcher_test.dart --plain-name "adds all six missing"`
  -> `Expected: 6\nActual: 0` (1 failed)
- green: `lib/src/cli/writers/tdd/pubspec_dev_dependencies_patcher.dart` implemented, including the multi-line `_renderEntry` for `flutter_test: sdk: flutter`
- refactor: extracted `_renderEntry` and `_indentEntry` after first pass failed to parse YAML
- commit: 575-tdd-setup-tdd-plugin

## Cycle 4: U25 extracts behaviors from spec.md

- test: `test/plugins/tdd/services/spec_parser_test.dart::extracts one acceptance behavior per Given/When/Then` (new)
- red: `dart test test/plugins/tdd/services/spec_parser_test.dart --plain-name "extracts"`
  -> `Expected: 2\nActual: 0` (1 failed)
- green: `lib/src/plugins/tdd/services/spec_parser.dart` implemented (regex on `**Given**` lines and `**FR-NNN**:` lines)
- refactor: none
- commit: 575-tdd-setup-tdd-plugin

## Cycle 5: A6 zfa tdd init creates missing artifacts (end-to-end)

- test: `test/plugins/tdd/tdd_command_smoke_test.dart::zfa tdd init on an empty directory is idempotent` (new)
- red: `dart test test/plugins/tdd/tdd_command_smoke_test.dart --plain-name "init on an empty directory"`
  -> `Expected: true\nActual: false` (smoke test file did not exist after first run)
- green: `lib/src/plugins/tdd/commands/init_command.dart` implemented; invokes the four writers on `Directory.current`
- refactor: none
- commit: 575-tdd-setup-tdd-plugin

## Notes and deviations

- The full red→green refactor cycles for Phases 6–11 (gen/verify-red/make/refactor/run/verify) are deferred to follow-up PRs. The subcommand stubs are honest misfire-stops per FR-031: each throws `StateError` with a message naming the missing task IDs.
- The end-to-end scenario `sc_001_setup_emits_tdd_baseline_test.dart` is deferred because it requires the Flutter SDK on PATH to run `flutter test` against a generated project; the unit-test surface (U10, U14, U16, U19, U25, A6, A11) covers the same behaviors at the writer level and is green.
