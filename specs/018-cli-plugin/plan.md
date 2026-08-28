# Implementation Plan: Native CLI Plugin for Zuraffa (018-cli-plugin)

**Branch**: `feat/018-cli-plugin` | **Date**: 2026-08-28 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/018-cli-plugin/spec.md`

## Summary

Build a native, built-in, pure-Dart Zuraffa package that standardizes the CLI
surface across all Zuraffa apps and lets apps cross-reference, invoke, and
share commands through a shared registry. The plugin extends Zuraffa's existing
`args`-based CLI conventions (the `CliRunner` + per-command `Command<void>`
pattern at `lib/src/cli/cli_runner.dart`) rather than introducing a parallel
competing parser. The deliverable is a runtime library plus a generator plugin
that can emit contract-compliant commands for any existing entity/use case.

The core technical approach: define a `CliContract` value type that captures
the standardized exit-code vocabulary, global flags, error shape, and output
schema; build a `StandardCommand` declarative model on top of `package:args`
`Command<void>`; back it with a `CommandRegistry` keyed by `(ownerApp,
commandName)` so two apps can register the same command name without silent
override; expose a `CliApp` entry point that parses args, dispatches through
the registry, and emits the contract's exit code; and ship a `CliPlugin`
generator (under `lib/src/plugins/cli/`) so `zfa make <Entity>` can produce a
contract-compliant command bound to that entity's existing use cases.

## Technical Context

**Language/Version**: Dart 3.13.2 (stable, 2026-08-25). Pubspec constraint
`sdk: ^3.11.0`; 3.13.2 satisfies it. Pure-Dart root package; **no Flutter SDK
required** and **no `package:flutter` import** anywhere in the CLI plugin path
(see FR-012).

**Primary Dependencies**:
- `args: ^2.7.0` — existing CLI parser. `StandardCommand` extends
  `Command<void>`; `CliApp` wraps `CommandRunner<void>`. We do NOT introduce
  `clawd`, `cli_completion`, or any competing parser.
- `get_it: ^9.2.1` — existing DI container. `DiBinding` adapters commands to
  the host app's `GetIt` instance.
- `meta: ^1.17.0` — `@sealed`, `@immutable` annotations.
- `code_builder: ^4.11.1` + `dart_style: ^3.1.12` — for the `CliPlugin`
  generator (FR-011), mirroring how every other generator plugin under
  `lib/src/plugins/<name>/` produces code.
- `test: ^1.25.0` — for unit, scenario, and acceptance tests.

**Storage**: none. The `CommandRegistry` is an in-process, in-memory structure
populated at app startup. Cross-app invocation (FR-005) happens within the
same Dart process via direct method calls on the registry; transport is
deferred per spec assumption ("v1 scope boundaries: RPC transports and
distributed execution are out of scope for v1"). Persisting the registry to
disk for cross-process discovery is explicitly out of scope.

**Testing**: `dart test`. Test layout mirrors source layout under `test/`:
`lib/src/cli/standard/foo.dart` ↔ `test/cli/standard/foo_test.dart`.
Scenario-style acceptance tests for SC-001…SC-006 live under
`test/cli/standard/scenarios/sc_<NNN>_<slug>_test.dart`.

**Target Platform**: Linux / macOS / Windows desktop for development;
anywhere Dart can run for production (CI runners, dev machines, build
servers). No platform-specific code, no `dart:io` system calls beyond
`exit()` and `stdout`/`stderr` (both already used by the existing
`CliRunner`).

**Project Type**: Library + generator plugin inside an existing CLI
package. The runtime library is at `lib/src/cli/standard/`; the generator
plugin is at `lib/src/plugins/cli/`. Both are exported through the root
`lib/zuraffa.dart` barrel.

**Performance Goals**: CLI parse → dispatch → handler invocation under 5 ms
for a single command in release mode (excluding the handler's own work).
Registry lookup is O(1) by `(ownerApp, name)`. Cold-start (loading the
plugin loader, registering all built-in plugins) is bounded by the existing
`CliRunner._ensureInitialized()` path, which this plugin does not change.

**Constraints**:
- Pure-Dart only — no `package:flutter` import anywhere in
  `lib/src/cli/standard/` or `lib/src/plugins/cli/` (FR-012).
- No new top-level dependency on a third-party CLI framework; `args` is the
  parser.
- No breaking changes to the existing `CliRunner`, `PluginLoader`, or
  `bin/zfa.dart` entry point. The new code is additive.
- No `dependency_overrides` reintroduced in `pubspec.yaml` (per task brief).
- Branch name `feat/018-cli-plugin` (per task brief; AGENTS.md prefers
  `018-cli-plugin` — see spec.md Branch Note).

**Scale/Scope**: ~12 source files, ~10 test files, 6 scenario-style
acceptance tests (one per SC). Estimated 1,500–2,000 lines of Dart total.
Single-developer scope; no parallelism needed within the feature.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Zuraffa's constitution is implicit (no `.specify/constitution.md` shipped in
this repo at spec-kit init time). The hard rules in `AGENTS.md` apply:

| Rule | Status | Notes |
|---|---|---|
| Use `zfa entity create` → `zfa make` → `zfa build` for arch code | N/A | The 018 feature is a *library* (runtime + generator plugin), not an entity scaffold. The `zfa entity create` flow does not apply. |
| Do NOT call `build_runner` directly; use `zfa build` | OK | If any codegen is needed for the generator plugin itself, it goes through `zfa build`. |
| Do NOT hand-create entities | N/A | No entities introduced. |
| Do NOT invent alternate folder structures | OK | New code follows the existing `lib/src/cli/<sub>/` and `lib/src/plugins/<name>/` patterns. |
| STOP-ON-ROADBLOCK on any `zfa` command error | N/A | No `zfa` commands are invoked for this feature. |
| Spec-kit branch matches feature dir exactly | VIOLATION | Task brief overrides: branch is `feat/018-cli-plugin`, not `018-cli-plugin`. Documented in spec.md Branch Note. |

The single violation is the branch-naming deviation, which is task-brief-
mandated and documented. No other constitution issues.

## Project Structure

### Documentation (this feature)

```text
specs/018-cli-plugin/
├── spec.md              # /speckit.specify — refined, with measurable SCs
├── plan.md              # this file
├── tasks.md             # /speckit.tasks — MVP-first dependency order
└── tdd/
    ├── test-list.md     # /speckit.tdd.plan — behaviors, traces, states
    ├── cycle-log.md     # /speckit.tdd.run — append-only red/green evidence
    └── verification.md  # /speckit.tdd.verify — audit verdict
```

### Source Code (repository root)

```text
lib/src/cli/
├── cli_runner.dart              # existing — UNCHANGED
├── plugin_loader.dart           # existing — UNCHANGED
├── progress_reporter.dart       # existing — UNCHANGED
└── standard/                    # NEW — the 018 plugin runtime library
    ├── standard.dart            # public barrel (re-exports the public API)
    ├── cli_app.dart             # FR-001 standardized entry point
    ├── cli_contract.dart        # FR-002 CLI contract (exit codes, flags, help, error, output)
    ├── command_model.dart       # FR-003 declarative command model
    ├── command_registry.dart    # FR-004 shared command registry
    ├── cross_app_invoker.dart   # FR-005 cross-app invocation (no hard dep)
    ├── shared_command.dart      # FR-006 share/reuse command definitions
    ├── di_binding.dart          # FR-007 DI/domain binding
    ├── output_format.dart       # FR-008 machine-readable output
    ├── edge_cases.dart          # FR-009 edge-case handling (unknown, ambiguous, conflict, circular, version, non-interactive)
    └── cli_plugin.dart          # FR-010 native built-in package registration

lib/src/plugins/
└── cli/                         # NEW — generator plugin for FR-011
    └── cli_plugin.dart          # produces standardized CLI commands + entry point for an entity

test/cli/standard/
├── helpers/
│   ├── fake_invocation_sink.dart   # captures handler invocations
│   └── fake_di_container.dart      # minimal DI surface for binding tests
├── scenarios/
│   ├── sc_001_scaffold_test.dart   # SC-001
│   ├── sc_002_consistency_test.dart # SC-002
│   ├── sc_003_cross_app_test.dart  # SC-003
│   ├── sc_004_share_test.dart      # SC-004
│   └── sc_006_machine_readable_test.dart # SC-006 (SC-005 covered in cli_plugin_generator_test.dart)
├── cli_app_test.dart
├── cli_contract_test.dart
├── command_model_test.dart
├── command_registry_test.dart
├── cross_app_invoker_test.dart
├── shared_command_test.dart
├── di_binding_test.dart
├── output_format_test.dart
├── edge_cases_test.dart
└── cli_plugin_generator_test.dart  # SC-005
```

**Structure Decision**: Follows the existing repo pattern — runtime library
under `lib/src/cli/<sub>/` (mirroring `lib/src/cli/cli_runner.dart`), generator
plugin under `lib/src/plugins/<name>/` (mirroring every other generator
plugin), tests mirror source layout under `test/`. The `standard/` subdirectory
namespaces the new code so it does not collide with the existing
`cli_runner.dart` / `plugin_loader.dart` / `progress_reporter.dart` files.

## Complexity Tracking

> Fill ONLY if Constitution Check has violations that must be justified

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Branch name `feat/018-cli-plugin` instead of `018-cli-plugin` | Task brief mandates `feat/018-cli-plugin` and uses that name in the `git push` and `gh pr create` commands. Following the task brief verbatim is the operative contract. | Using `018-cli-plugin` strictly per AGENTS.md would break the task's own push and PR commands. The maintainer can re-branch if strict AGENTS.md compliance is required; both names target the same feature directory. |

No other violations.
