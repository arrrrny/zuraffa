# Implementation Plan: Fix Zuraffa Code Generation Import and Type Emission

**Branch**: `004-fix-zuraffa-gen` | **Date**: 2026-04-17 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/004-fix-zuraffa-gen/spec.md`

## Summary

Fix four code generation issues in the Zuraffa CLI/MCP server: (1) Replace `package:app/` package imports with relative path computation, (2) Make `useZorphy` flag consistent across all update-method generators, (3) Audit and verify method name generation, (4) Ensure DI import paths remain correct with regression tests. The technical approach replaces `PackageUtils.getBaseImport()` with `path.relative()` computation in `CommonPatterns.entityImports()` and adds the missing `useZorphy` conditional to 5 generators.

## Technical Context

**Language/Version**: Dart 3.x (Flutter SDK)
**Primary Dependencies**: code_builder, dart_style, path, args
**Storage**: N/A (code generation tool, no persistent storage)
**Testing**: dart test (package:test)
**Target Platform**: Developer machines (CLI tool and MCP server)
**Project Type**: Library/CLI tool (Dart package with code generation)
**Performance Goals**: Code generation under 5 seconds for typical features
**Constraints**: Generated code must compile without warnings or manual fixes
**Scale/Scope**: Affects ~15 generator files, ~30+ import construction sites, 5 `useZorphy` inconsistency sites

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. AI-First Architecture | ✅ PASS | Fixing the CLI code generator improves AI agent experience |
| II. Clean Architecture by Design | ✅ PASS | No layer violations; fixing import paths maintains layer separation |
| III. Type-Safe Result Handling | ✅ PASS | No changes to Result types; fixing generic emission improves type safety |
| IV. Test-Driven Development | ✅ PASS | Will add regression tests for import paths and generic types before/during implementation |
| V. Zero-Boilerplate CLI Usage | ✅ PASS | Fixing the CLI is itself improving CLI usage; no manual code creation |

**Gate Result**: PASS — All principles satisfied. No violations to justify.

## Project Structure

### Documentation (this feature)

```text
specs/004-fix-zuraffa-gen/
├── plan.md              # This file
├── research.md          # Phase 0 output — research on import pipeline, generic types, DI paths
├── data-model.md        # Phase 1 output — entities, validation rules
├── quickstart.md        # Phase 1 output — solution overview and verification
├── contracts/
│   └── generated-import-paths.md  # Phase 1 output — import path format contract
└── tasks.md             # Phase 2 output (NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
lib/src/
├── utils/
│   └── package_utils.dart                    # MODIFY: Replace package-import approach with relative path computation
├── core/
│   └── builder/
│       └── patterns/
│           └── common_patterns.dart          # MODIFY: Replace baseImport with relative path computation
├── plugins/
│   ├── usecase/generators/
│   │   ├── entity_usecase_generator.dart     # VERIFY: imports (uses CommonPatterns)
│   │   └── stream_usecase_generator.dart     # VERIFY: imports (uses CommonPatterns)
│   ├── repository/generators/
│   │   ├── interface_generator.dart          # MODIFY: useZorphy check (line 342) + imports
│   │   └── implementation_generator_append.dart  # VERIFY: imports
│   ├── presenter/
│   │   └── presenter_plugin.dart             # MODIFY: useZorphy check (line 610) + imports
│   ├── service/builders/
│   │   └── service_interface_builder.dart    # MODIFY: useZorphy check (line 165)
│   ├── provider/builders/
│   │   └── provider_builder.dart             # MODIFY: useZorphy check (lines 376, 491)
│   ├── mock/builders/
│   │   └── mock_provider_builder.dart        # MODIFY: useZorphy check (line 740)
│   ├── state/builders/
│   │   └── state_builder.dart                # VERIFY: imports (uses CommonPatterns for custom)
│   ├── controller/
│   │   └── controller_plugin_utils.dart      # VERIFY: imports (uses CommonPatterns)
│   ├── di/
│   │   └── di_plugin.dart                    # VERIFY: already uses relative paths
│   └── view/
│       └── view_plugin.dart                  # VERIFY: already uses relative paths

test/
├── plugins/
│   ├── usecase/
│   │   └── entity_usecase_generator_test.dart  # ADD: import path tests
│   ├── repository/
│   │   └── interface_generator_test.dart        # ADD: useZorphy + import tests
│   ├── presenter/
│   │   └── presenter_plugin_test.dart           # ADD: useZorphy tests
│   └── provider/
│       └── provider_plugin_test.dart            # MODIFY: update expected imports from package: to relative
```

**Structure Decision**: Single project structure — Zuraffa is a Dart package with code generation CLI and MCP server. All changes are within the existing `lib/src/` structure.

## Complexity Tracking

> No violations detected. Constitution Check passes all gates.
