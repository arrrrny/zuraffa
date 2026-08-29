# Implementation Plan: Slice Plugin

**Branch**: `042-slice-plugin` | **Date**: 2026-08-29 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/042-slice-plugin/spec.md`

## Summary

Build a Zuraffa plugin (`id: 'slice'`) that extracts runnable, self-contained subsets of a Zuraffa-structured project by tracing the dependency graph from entry point files. The plugin uses a dual-path traversal engine (import resolution + service-locator type extraction) to collect the minimum file set needed for a feature, generates a sandbox with mock DI wiring and a runnable entry point, and supports hash-based merge-back. The plugin extends `ZuraffaPlugin` (not `FileGeneratorPlugin` since it doesn't generate architecture code) and implements `CliAwarePlugin` with subcommands: `cut`, `merge`, `list`, `inspect`.

## Technical Context

**Language/Version**: Dart ^3.12.0 (same as Zuraffa itself)

**Primary Dependencies**:

- `package:analyzer` 14.1.0 — AST parsing for import extraction and `getIt<T>()` detection
- `package:args` — CLI command/subcommand framework
- `package:crypto` — SHA-256 file hashing for merge conflict detection
- `package:yaml` / `package:yaml_writer` — slice.yaml manifest serialization
- Existing Zuraffa infrastructure: `AstHelper`, `FileParser`, `DependencyGraph`, `DiscoveryEngine`

**Storage**: Filesystem — slices live at `.zuraffa/slices/<name>/` relative to project root

**Testing**: `dart test` — unit tests for graph traversal, boundary detection, merge logic

**Target Platform**: CLI tool (Zuraffa is a Dart CLI)

**Project Type**: CLI plugin within the Zuraffa code generator

**Performance Goals**: Slice extraction completes in <30 seconds for projects with up to 300 source files

**Constraints**: Syntactic-only AST parsing (no resolution context) for speed; single-package Dart/Flutter projects only in v1

**Scale/Scope**: Designed for projects with 100-500 source files, 30-150 entities, 20-60 presentation pages

## Constitution Check

_GATE: Must pass before Phase 0 research. Re-check after Phase 1 design._

Constitution is not populated (template only). No governance gates to evaluate. Proceeding.

## Project Structure

### Documentation (this feature)

```text
specs/042-slice-plugin/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
└── tasks.md             # Phase 2 output (not created by plan)
```

### Source Code (repository root)

```text
lib/src/plugins/slice/
├── slice_plugin.dart                 # Plugin class (extends ZuraffaPlugin, implements CliAwarePlugin)
├── slice_command.dart                # CLI command with subcommands (cut, merge, list, inspect)
├── capabilities/
│   ├── cut_slice_capability.dart     # Plan/execute for slice extraction
│   └── merge_slice_capability.dart   # Plan/execute for merge-back
├── engine/
│   ├── import_graph_walker.dart      # Transitive import resolution with boundary detection
│   ├── service_locator_analyzer.dart # Extract getIt<T>() calls from presenter constructors
│   ├── package_resolver.dart         # Resolve package: URIs to filesystem paths
│   ├── barrel_resolver.dart          # Selective barrel file (index.dart) expansion
│   └── companion_detector.dart       # Find .g.dart, .freezed.dart companions
├── models/
│   ├── slice_manifest.dart           # SliceManifest — the slice.yaml model
│   ├── slice_file.dart               # SliceFile — file with ownership + hash
│   ├── slice_boundary.dart           # Boundary — interface at traversal edge
│   ├── file_graph.dart               # FileGraph — nodes (files) + edges (imports/DI)
│   └── slice_depth.dart              # SliceDepth enum (view, presentation, feature, full)
├── generators/
│   ├── sandbox_bootstrapper.dart     # Generate main_slice.dart + slice_di.dart
│   ├── mock_stub_generator.dart      # Generate lightweight mocks for boundary interfaces
│   ├── agent_readme_generator.dart   # Generate SLICE.md agent instructions
│   └── manifest_writer.dart          # Serialize/deserialize slice.yaml
└── merger/
    ├── slice_merger.dart             # Hash-compare + copy-back logic
    └── conflict_detector.dart        # Detect concurrent modifications

test/plugins/slice/
├── engine/
│   ├── import_graph_walker_test.dart
│   ├── service_locator_analyzer_test.dart
│   ├── package_resolver_test.dart
│   ├── barrel_resolver_test.dart
│   └── companion_detector_test.dart
├── models/
│   ├── slice_manifest_test.dart
│   └── file_graph_test.dart
├── generators/
│   ├── sandbox_bootstrapper_test.dart
│   └── mock_stub_generator_test.dart
├── merger/
│   ├── slice_merger_test.dart
│   └── conflict_detector_test.dart
└── slice_integration_test.dart       # End-to-end: cut → modify → merge
```

**Structure Decision**: The slice plugin follows the standard Zuraffa plugin layout but with a richer internal structure due to the graph engine. The `engine/` subdirectory contains the core traversal logic (reusable by other plugins). The `models/` directory holds value objects. The `generators/` directory produces sandbox artifacts. The `merger/` directory handles the merge-back lifecycle.

## Complexity Tracking

No constitution violations to justify.
