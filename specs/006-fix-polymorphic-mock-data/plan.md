# Implementation Plan: Fix Polymorphic Mock Data Generation

**Branch**: `006-fix-polymorphic-mock-gen` | **Date**: 2026-05-24 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/006-fix-polymorphic-mock-data/spec.md`

## Summary

Fix the ZFA CLI mock data generator so it correctly detects Dart `sealed class` hierarchies (in addition to `@Zorphy` annotations) as polymorphic entity types. The bug causes the generator to hang or produce invalid code when `getPolymorphicSubtypes()` returns empty for sealed classes, falling through to a path that tries to directly instantiate abstract base types. The fix extends `EntityAnalyzer.getPolymorphicSubtypes()` with sealed class detection while preserving existing Zorphy support, and adds error handling to prevent silent failures.

## Technical Context

**Language/Version**: Dart 3.11+  
**Primary Dependencies**: zuraffa (4.1.2), zorphy (1.7.1), DiscoveryEngine (glob-based file search)  
**Storage**: N/A (file generation only)  
**Testing**: dart test (test/plugins/mock/mock_builder_test.dart)  
**Target Platform**: Dart CLI (`dart run zuraffa:zfa`)  
**Project Type**: CLI tool (within multi-package repository)  
**Performance Goals**: <10 seconds for entities with up to 10 subtypes  
**Constraints**: Same-file sealed class detection only; cross-file out of scope  
**Scale/Scope**: Single utility method fix + error handling improvements in 2-3 files

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

The constitution template is unpopulated (all section values are placeholders). No enforceable constitutional rules exist for this project. All gates pass by default.

**Pre-Design**: PASS (no rules to violate)
**Post-Design**: PASS (no rules to violate)

## Project Structure

### Documentation (this feature)

```text
specs/006-fix-polymorphic-mock-data/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
│   └── mock-cli.md      # CLI interface contract
└── tasks.md             # Phase 2 output (/speckit.tasks)
```

### Source Code (repository root)

```text
lib/src/
├── utils/
│   └── entity_analyzer.dart          # PRIMARY: getPolymorphicSubtypes() fix
├── plugins/mock/builders/
│   ├── mock_builder.dart             # Uses getPolymorphicSubtypes()
│   ├── mock_entity_graph_builder.dart # Recursive entity processing + error handling
│   └── mock_value_builder.dart       # Uses getPolymorphicSubtypes() for value gen
└── commands/
    └── mock_command.dart             # CLI entry point (no changes expected)

test/plugins/mock/
└── mock_builder_test.dart            # Existing tests; add sealed class test cases
```

**Structure Decision**: Single project structure. Changes are confined to the existing `lib/src/utils/` and `lib/src/plugins/mock/` directories. No new files needed; only modifications to existing source files.

## Complexity Tracking

> No violations to justify — constitution is unpopulated.
