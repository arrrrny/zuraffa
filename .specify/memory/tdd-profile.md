# TDD Profile — Zuraffa

This profile is read by the `tdd` spec-kit extension. It captures the test
commands, layout, and conventions the auditor needs to grade tests cold.

## Stack

- **Language**: Dart 3.13 (stable). The repo's pubspec pins `sdk: ^3.11.0`,
  which 3.13.2 satisfies. Pure-Dart root package; no Flutter SDK required.
- **Test runner**: `package:test` (`^1.25.0`). Invoked as `dart test`.
- **Static analysis**: `dart analyze`. Configured via `analysis_options.yaml`
  at repo root (uses `package:lints/recommended.yaml`).
- **Mutation tool**: none wired in CI. `/speckit.tdd.verify` Phase 4 falls back
  to deliberate-mutant sampling per the rubric.
- **Coverage**: `dart test --coverage=<dir>` then
  `dart run coverage:format_coverage`. Opt-in, not a gate.

## Commands

- Single test: `dart test test/<path>.dart -P "<name>"` (the `-P` filter
  matches test names containing the string).
- Full suite (feature scope): `dart test test/plugins/benchmark/`
- Full suite (repo): `dart test` — slow; do not run for feature work, run the
  scoped subset instead.
- Static analysis (feature scope): `dart analyze lib/src/core/benchmark/ lib/src/plugins/benchmark/ test/plugins/benchmark/`
- Static analysis (full repo): `dart analyze`

## Test layout

Tests mirror the source layout under `test/`. A source file at
`lib/src/core/benchmark/foo.dart` is tested at
`test/plugins/benchmark/foo_test.dart` (the core contract library lives under
`lib/src/core/benchmark/` but its tests sit beside the plugin's tests in
`test/plugins/benchmark/`, mirroring how the repo colocates core-library tests
for plugin features).

Scenario-style acceptance tests live under
`test/plugins/benchmark/scenarios/sc_<NNN>_<slug>_test.dart` so they are visually
distinct from unit tests and trace 1:1 to the spec's acceptance criteria and
success criteria.

## Conventions

- One test file per source file under test.
- Test names are sentences phrased as observable results ("rejects a duplicate
  scenario id with a conflict error"), not calls ("test register").
- Shared fixtures live in `test/plugins/benchmark/helpers/`. A test that needs a
  fixture imports it; tests do not reach across each other.
- A red test is committed alongside the implementation that turns it green, in
  the same commit. The cycle log records the red command and its output.

## Exemplars

- `test/cli/standard/command_registry_test.dart` (feature 018) is the canonical
  example of a unit test in this repo: pure behavior, no I/O, deterministic.
- `test/cli/standard/scenarios/sc_001_scaffold_test.dart` (feature 018) is the
  canonical acceptance test: drives the real entry point end-to-end and asserts
  on observable effects.

## Helpers

- `test/plugins/benchmark/helpers/fake_scenarios.dart` — deterministic fake
  `BenchmarkContract` implementations (fast, slow, throwing, threshold-exceeding).
- `test/plugins/benchmark/helpers/fake_collectors.dart` — fake `MetricCollector`s
  (recording, throwing).
- `test/cli/standard/helpers/fake_invocation_sink.dart` (feature 018) — captures
  handler invocations for CLI-command assertion.
