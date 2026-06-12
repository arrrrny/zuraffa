# Implementation Plan: Declarative UseCase Registration

**Branch**: `010-usecase-registration` | **Date**: 2026-06-12 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/010-usecase-registration/spec.md`

## Summary

Create CLI commands that let developers register existing use cases into Presenters, Controllers, and State classes via single-command invocations, following the same pattern as `zfa di <Name>`. The commands will parse existing source files using the Dart analyzer, append field declarations and constructor registration calls, and update imports — all reusing the existing `AppendExecutor` infrastructure.

## Technical Context

**Language/Version**: Dart 3.x (Zuraffa v5 project)

**Primary Dependencies**:

- `code_builder` — source code AST generation
- `analyzer` — Dart source file parsing (already used by AppendExecutor)
- `args` — CLI argument parsing
- `path` — filesystem path resolution

**Storage**: Filesystem (source file modification on disk)

**Testing**: `dart test`, existing Zuraffa test suite

**Target Platform**: CLI tool (Dart VM)

**Project Type**: CLI tool / code generator (part of Zuraffa framework)

**Performance Goals**: Interactive CLI responsiveness (< 1s typical)

**Constraints**:

- Must not destroy custom code in existing files (append-only, never regenerate)
- Must not modify files produced by `zfa make` in a destructive way
- Must reuse existing `AppendExecutor` strategies (FieldAppendStrategy, ConstructorAppendStrategy, ImportAppendStrategy)
- Must follow the same CLI argument conventions as `zfa di`

**Scale/Scope**:

- 4 new CLI subcommands
- 3 new plugin capabilities (PresenterRegister, ControllerRegister, StateRegister)
- 1 batch command (zfa register)
- Append-only source modification via existing strategies

## Constitution Check

_GATE: Must pass before Phase 0 research. Re-check after Phase 1 design._

**Result: PASS** — No active constitutional principles defined (constitution is template-only). No violations.

## Project Structure

### Documentation (this feature)

```text
specs/010-usecase-registration/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output: existing infrastructure analysis
├── data-model.md        # Phase 1 output: design and architecture
├── quickstart.md        # Phase 1 output: how to use the new commands
├── contracts/           # Phase 1 output: CLI command schemas
└── tasks.md             # Phase 2 output (/speckit-tasks command)
```

### Source Code (the Zuraffa tool itself)

```text
lib/src/
├── commands/
│   ├── di_command.dart              # Existing: zfa di <Name>
│   ├── presenter_command.dart       # Existing: zfa presenter create
│   ├── controller_command.dart      # Existing: zfa controller create
│   ├── state_command.dart           # Existing: zfa state create
│   └── register_command.dart        # NEW: zfa register <Name> [layers...]
│
├── plugins/
│   ├── presenter/
│   │   ├── presenter_plugin.dart    # Existing (add RegisterCapability)
│   │   └── capabilities/
│   │       ├── create_presenter_capability.dart   # Existing
│   │       └── register_presenter_capability.dart  # NEW
│   ├── controller/
│   │   ├── controller_plugin.dart   # Existing (add RegisterCapability)
│   │   └── capabilities/
│   │       ├── create_controller_capability.dart   # Existing
│   │       └── register_controller_capability.dart  # NEW
│   └── state/
│       ├── state_plugin.dart        # Existing (add RegisterCapability)
│       └── capabilities/
│           ├── create_state_capability.dart        # Existing
│           └── register_state_capability.dart       # NEW
│
├── core/
│   └── ast/
│       ├── append_executor.dart       # Existing — reuse for field/constructor appends
│       ├── strategies/
│       │   ├── field_append_strategy.dart            # Existing
│       │   ├── constructor_append_strategy.dart       # Existing
│       │   └── import_append_strategy.dart            # Existing
│       └── builders/
│           └── presenter_register_builder.dart        # NEW: builds append requests for presenters

tests/
├── ... (existing tests)
└── specs/010-usecase-registration/
    └── integration_test.dart        # NEW: integration tests for register commands
```

**Structure Decision**: The feature extends the existing Zuraffa plugin architecture. No new top-level directories are needed.

## Complexity Tracking

> _Not applicable — no constitutional violations detected._

## Phase 0: Research

_See [research.md](research.md) for detailed findings._

Key findings:

1. **AppendExecutor** with FieldAppendStrategy and ConstructorAppendStrategy already supports what we need — parsing source files and injecting fields + constructor statements.
2. **DiPlugin.RegisterCapability** provides the exact pattern to follow — auto-detection of type from suffix, domain inference via filesystem scan, and capability-based execution.
3. **No existing register capabilities** exist for Presenter, Controller, or State plugins — these must be created.
4. The entity base name extraction from use case names follows a verb-stripping pattern: `GetProductUseCase` → entity = `Product`, resolve prefix from known CRUD verbs.

## Phase 1: Design

_See [data-model.md](data-model.md) for the complete architecture design._
_See [contracts/](contracts/) for CLI command schemas._
_See [quickstart.md](quickstart.md) for usage guide._

### Design Summary

**Capability approach**: Each plugin (presenter, controller, state) gets a `RegisterCapability` that:

1. Accepts a target use case name (e.g., `GetProduct`)
2. Infers the entity name and domain from the filesystem
3. Locates the target presenter/controller/state file by convention
4. Builds append requests (field + constructor + import) using `AppendExecutor`
5. Writes modified source back to disk

**Batch approach**: A new `zfa register` command that takes a use case name and a list of layers, delegating to individual capabilities.
