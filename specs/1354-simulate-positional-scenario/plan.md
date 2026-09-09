# Plan — Spec 1354 simulate scenario subcommands honor the pinned feature

**Branch**: `1354-simulate-positional-scenario` | **Date**: 2026-09-09 | **Spec**: [spec.md](./spec.md)

## Technical Context

- Surface: `lib/src/commands/simulate_command.dart` — the four spec-968
  scenario subcommands (`init`, `run`, `certify`, `verify-world`) dispatch
  manually through `SimulateCommand.run()` (parser-only registration, bug
  #856) and share one resolver: `_resolveFeature(featureFlag, projectFlag)`
  (returns `featureDir`/`featureName`/`projectRoot`).
- Today's resolution: explicit `--feature` ONLY (subcommand level, else the
  parent-level flag carried in as `parentFeature`). Empty → `_UsageError`
  ("no --feature given"), exit `ExitProtocol.usage`.
- Established pin pattern elsewhere in the CLI:
  - `certify_mock_capability.dart` `_pinnedFeature(projectRoot)` — regex
    read of `.specify/feature.json` → `feature_directory` (returns the raw
    value, which may be `specs/<slug>` or `<slug>`).
  - `bone_command.dart` `_resolveActiveFeature()` — JSON decode, strips
    trailing `/` and the `specs/` prefix, null-safe on missing/malformed.
- `_resolveFeature` already accepts both forms: a bare name is joined under
  `<projectRoot>/specs/`, a path (contains `/`) is joined against
  `<projectRoot>` — so the raw pinned value can flow straight through the
  existing branch logic.
- `--project` (when given) is the root the pin must be read from; default
  is `Directory.current`.
- The scenario/positional side needs no change: `rest.first` is already the
  scenario. Only feature resolution is broken (issue #1354).
- Test harness: `test/simulation/worlds/simulate_worlds_command_test.dart`
  drives `zfa simulate ...` end-to-end via `CliRunner.runCapturing` in a
  temp workspace seeded with a declared dependency table
  (`_writeDependencyTable`). The pin scenarios extend this harness with a
  `.specify/feature.json` writer.

## Approach

1. **Pin fallback in `_resolveFeature`** (the single-point fix):
   - When `featureFlag` (after `?? parentFeature`) is null/empty, read
     `<projectRoot>/.specify/feature.json` and take `feature_directory`
     (regex read like `_pinnedFeature` — no hard JSON dependency; malformed
     file = no pin).
   - The pinned value then flows through the existing name-vs-path branches
     unchanged (bare slug → `specs/<slug>`; `specs/...` → joined path).
   - New failure honesty: when the resolved feature directory does not
     exist on disk, throw `_UsageError` NAMING the missing pinned path —
     never a silent fallback, never a scan of `specs/`.
   - Updated unresolvable error: names both steps tried (no `--feature`
     given; no usable `.specify/feature.json` `feature_directory`) and the
     fix (`pass --feature <name-or-dir>` or pin via `zfa tdd plan
     <feature>`). The old text must stop claiming the positional scenario
     was ignored.
2. **Docs**: the subcommands' `--feature` help lines say
   "Feature name or directory under specs/ (defaults to the pinned
   `.specify/feature.json` feature)". The parent invocation string and the
   `SimulateCommand` library docs mention the pin. No parser change
   whatsoever (the bug #856 guard holds — flags stay reachable).
3. **Unchanged**: world scaffold/certification/run/receipt/differential
   machinery, cycle-log evidence (already records the RESOLVED
   `featureName` in `commandLine`, so bare and explicit invocations emit
   replayable evidence), exit-code semantics, and the legacy flag surface.

## Test strategy

- Extend `test/simulation/worlds/simulate_worlds_command_test.dart` with a
  "pinned feature resolution (issue #1354)" group, reusing the temp
  workspace + dependency-table harness:
  - AS-1 bare `init <scenario>` with a live pin → GREEN manifest under the
    pinned feature, same outcome as the explicit twin.
  - AS-2 explicit `--feature B` beats pin A → manifest under B only.
  - AS-3 no flag + no pin → usage exit code, honest message, nothing
    written under `specs/`.
  - AS-4 pin to a non-existent directory → usage exit code naming the path.
  - AS-5 bare `run` / `certify` / `verify-world` resolve the pin and match
    their explicit twins' verdicts.
  - AS-6 parent-level `zfa simulate --feature <f> init <scenario>` still
    works (regression guard).
- Scoped verification commands (never the full suite):
  `dart test test/simulation/worlds/simulate_worlds_command_test.dart
  test/simulation/simulate_command_test.dart
  test/commands/simulate_skin_command_test.dart` and
  `dart analyze lib/src/commands/simulate_command.dart`.

## data-model / contracts / quickstart

Not applicable: no data entities, no external interface contracts, and the
validation scenarios ARE the acceptance scenarios above (runnable via the
scoped `dart test` commands). The feature is resolution logic inside one
command file.

## Risks

- Reading the pin with a regex mirrors `_pinnedFeature`; a malformed JSON
  file must degrade to "no pin" (honest usage error), never throw.
- `--project` must be honored for the pin lookup (tests pin the temp
  workspace root, not the repo root).
