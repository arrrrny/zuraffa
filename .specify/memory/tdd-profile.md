# TDD Profile — Zuraffa

This profile is read by the `tdd` spec-kit extension. It captures the test
commands, layout, and conventions the auditor needs to grade tests cold.

## Stack

- **Language**: Dart 3.13 (stable). The repo's pubspec pins `sdk: ^3.11.0`,
  which 3.13.2 satisfies. Pure-Dart root package; no Flutter SDK required.
- **Test runner**: `package:test` (`^1.25.0`). Invoked as `dart test`.
- **Static analysis**: `dart analyze`. Configured via `analysis_options.yaml`
  at repo root (uses `flutter_lints`).
- **Mutation tool**: none wired in CI. `/speckit.tdd.verify` Phase 4 falls back
  to deliberate-mutant sampling per the rubric.
- **Coverage**: `dart test --coverage=<dir>` then
  `dart run coverage:format_coverage`. Opt-in, not a gate.

## Commands

- Single test: `dart test test/<path>.dart -P "<name>"` (the `-P` filter
  matches test names containing the string).
- Full suite (feature scope): `dart test test/cli/standard/`
- Full suite (repo): `dart test` — slow; do not run for feature work, run the
  scoped subset instead.
- Static analysis (feature scope): `dart analyze lib/src/cli/standard/ lib/src/plugins/cli/ test/cli/standard/`
- Static analysis (full repo): `dart analyze`

## Test layout

Tests mirror the source layout under `test/`. A source file at
`lib/src/cli/standard/foo.dart` is tested at `test/cli/standard/foo_test.dart`.

Scenario-style acceptance tests live under
`test/cli/standard/scenarios/sc_<NNN>_<slug>_test.dart` so they are visually
distinct from unit tests and trace 1:1 to the spec's success criteria.

## Conventions

- One test file per source file under test.
- Test names are sentences phrased as observable results ("rejects an unknown
  command with exit code 64"), not calls ("test parse").
- Shared fixtures live in `test/cli/standard/helpers/`. A test that needs a
  fixture imports it; tests do not reach across each other.
- A red test is committed alongside the implementation that turns it green, in
  the same commit. The cycle log records the red command and its output.

## Exemplars

- `test/cli/standard/command_registry_test.dart` is the canonical example of a
  unit test in this feature: pure behavior, no I/O, deterministic.
- `test/cli/standard/scenarios/sc_001_scaffold_test.dart` is the canonical
  acceptance test: drives `CliApp` end-to-end through `run(args)` and asserts
  on observable effects (handler invocation count, exit code, stdout shape).

## Helpers

- `test/cli/standard/helpers/fake_invocation_sink.dart` — captures handler
  invocations for assertion.
- `test/cli/standard/helpers/fake_di_container.dart` — minimal DI surface for
  command binding tests; no real `GetIt` registration.
