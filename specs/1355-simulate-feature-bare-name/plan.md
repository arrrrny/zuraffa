# Plan — Spec 1355 simulate --feature bare-name resolves under specs/

**Branch**: `1355-simulate-feature-bare-name` | **Date**: 2026-09-09 | **Spec**: [spec.md](./spec.md)

## Technical Context

- `lib/src/commands/simulate_command.dart`, `SimulateCommand.run()` legacy
  branch: `fixturesDir = --fixtures ?? --feature`, then
  `_replay(fixturesDir)` → `SimulationWorld.boot(featureDir:/fixturesDir:)`
  with the raw value. Bare `--feature` names are read CWD-relative →
  FixtureMismatch (issue #1355).
- The scenario subcommands' `--feature` (fixed by #1354) resolves bare
  names under `specs/` via `_resolveFeature`; the legacy flag is a
  separate entry and needs its own (smaller) resolution — no `--project`
  flag here, CWD is the root by definition.
- Test harness: `test/simulation/worlds/simulate_worlds_command_test.dart`
  (CliRunner in-process). Bare-name resolution is CWD-relative, so the new
  group saves `Directory.current`, points it at the temp workspace, and
  restores in `addTearDown` — the established repo pattern
  (`datasource_capability_receipt_test.dart`).

## Approach

1. In the legacy branch, resolve ONLY the value that came from
   `--feature` (i.e. when `--fixtures` is null): bare name (no `/`) whose
   `<cwd>/specs/<name>` exists → absolute specs path; everything else is
   honored verbatim (path forms, `--fixtures`, missing specs dirs).
2. Extend the parent `--feature` help: "A bare feature name resolves
   under specs/ (the #968 fixtures the scaffold wrote)."
3. Nothing else changes: verdict protocol, exit codes, subcommand paths.

## Test strategy

New group `issue #1355: legacy --feature bare-name resolution` in
`simulate_worlds_command_test.dart`:
- AS-1: scaffold into `specs/<f>` then bare-name `--feature <f>` → GREEN
  (exit 0, `SIMULATE golden -> GREEN`).
- AS-2: path form `--feature specs/<f>` → GREEN (regression guard).
- AS-3: bare name without a specs dir → exit 1 RED naming the raw value.
- AS-4: `--fixtures <dir>` (dir outside specs/) → GREEN verbatim.
Scoped runs: the worlds command file + the two simulate command files;
`dart analyze` on touched files.

## data-model / contracts / quickstart

Not applicable — resolution logic in one command; validation scenarios
above are runnable via the scoped `dart test` commands.
