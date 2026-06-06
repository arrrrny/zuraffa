# Implementation Plan: Mock JSON Data Method

**Branch**: `008-mock-json-method` | **Date**: 2026-06-06 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/008-mock-json-method/spec.md`

## Summary

Add a `json` method to the existing MockPlugin that generates mock entity data as JSON files with companion Dart helpers using `fromJson` for deserialization. Introduces a clean folder convention (`data/mock_json/{domain}/`) for organizing JSON mock data. Enables fast prototyping by allowing developers to swap JSON files without code regeneration.

## Technical Context

**Language/Version**: Dart 3.x (CLI tool, same as the Zuraffa codebase)

**Primary Dependencies**: code_builder (Dart code generation), dart:convert (JSON), path (file paths), args (CLI), existing components: MockValueBuilder, EntityAnalyzer, FileUtils, StringUtils, MockEntityGraphBuilder, TransactionalFileSystem

**Storage**: File system — JSON files (`.mock.json`), Dart source files (`_mock_json.dart`), metadata files (`.mock.json.meta`)

**Testing**: dart test / flutter test (existing test conventions: `test/plugins/mock/`)

**Target Platform**: Cross-platform CLI (macOS, Linux, Windows)

**Project Type**: CLI tool (code generation plugin for Zuraffa)

**Performance Goals**: Generate JSON mock data for a typical entity (5-10 fields) in under 10 seconds end-to-end (SC-001)

**Constraints**: Generated JSON must be RFC 8259 valid (SC-003), all standard field types must round-trip through `fromJson` (SC-005)

**Scale/Scope**: Extends existing MockPlugin (~5 existing builders, ~6 files); adds 2-3 new builder files, 1 new capability class, CLI subcommand, tests

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

**Status**: No gates defined — the constitution template is empty (no principles filled in). Project conventions from AGENTS.md and existing code patterns serve as guidance instead.

Key conventions followed:
- Plugin generation workflow via `zfa make` (existing MockPlugin registered in plugin system)
- Entity-first: JSON generation depends on entity via EntityAnalyzer
- File output via FileUtils + TransactionalFileSystem
- Capability pattern for plugin operations

## Project Structure

### Documentation (this feature)

```text
specs/008-mock-json-method/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
│   ├── plugin-capability.md
│   └── cli-interface.md
└── tasks.md             # Phase 2 output (NOT created yet)
```

### Source Code (repository root)

```text
lib/src/
├── plugins/mock/
│   ├── mock_plugin.dart              # EXTEND: add JsonMockCapability registration
│   ├── capabilities/
│   │   ├── create_mock_capability.dart   # Existing
│   │   └── json_mock_capability.dart    # NEW: JSON mock capability
│   └── builders/
│       ├── mock_builder.dart             # EXTEND: delegate to jsonBuilder
│       ├── mock_data_builder.dart        # Existing (Dart mock data)
│       ├── mock_value_builder.dart       # EXTEND: add JSON-compatible value methods
│       ├── mock_json_builder.dart        # NEW: generates JSON files + Dart helper
│       ├── mock_json_helper_builder.dart # NEW: generates Dart helper code
│       └── mock_entity_graph_builder.dart # EXTEND: recursive JSON generation
├── commands/
│   └── mock_command.dart           # EXTEND: add `json` subcommand, --json flag
├── models/
│   └── generator_config.dart       # EXTEND: add generateMockJson flag
└── config/
    └── zfa_config.dart             # EXTEND: add mockJsonByDefault key

test/plugins/mock/
├── mock_json_builder_test.dart     # NEW: JSON builder unit tests
└── mock_json_integration_test.dart # NEW: end-to-end JSON mock generation tests
```

**Structure Decision**: Follows existing plugin module layout. New builder classes go under `lib/src/plugins/mock/builders/`. New capability class goes under `lib/src/plugins/mock/capabilities/`. CLI integration extends existing `MockCommand`.

## Complexity Tracking

> No constitution violations exist — tracking section left empty.
