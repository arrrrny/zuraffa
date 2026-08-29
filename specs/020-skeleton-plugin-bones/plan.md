# Implementation Plan: Skeleton Plugin — Bare-Bones Feature Scaffold

**Branch**: `020-skeleton-plugin-bones` | **Date**: 2026-08-29 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/020-skeleton-plugin-bones/spec.md`

## Summary

Build a `skeleton` plugin that generates self-contained feature scaffolds
("bones") for delegated agent builds. A bone is a directory under
`.zfa/bones/<feature-slug>/` containing a YAML manifest, entity stubs, layer
placeholders, and dependency declarations derived from entity cross-references.
The plugin integrates into the existing Zuraffa plugin system as a
`FileGeneratorPlugin` + `CliAwarePlugin`, exposing `zfa bone generate` and
`zfa bone export` commands. Circular dependencies are detected at generation
time (Kahn topological sort) and reported as errors. Each bone records a
SHA-256 hash of its source spec for staleness detection. Export produces a
single `.tar.gz` artifact suitable for handoff to a cloud agent.

## Technical Context

**Language/Version**: Dart ^3.11.0

**Primary Dependencies**: args ^2.7.0 (CLI), yaml ^3.1.0 (manifest +
spec parsing), path ^1.9.1, glob ^2.1.2, crypto ^3.0.7 (spec hash),
code_builder ^4.11.1 + dart_style ^3.1.12 (Dart stub generation),
archive (NEW — for `zfa bone export` tar.gz output)

**Storage**: files only — bones under `.zfa/bones/<feature-slug>/`, no database

**Testing**: `test` package (^1.25.0); fast suite under `test/plugins/skeleton/`,
run via `dart test` (see `.specify/memory/tdd-profile.md`)

**Target Platform**: macOS/Linux CLI (Dart VM)

**Project Type**: CLI plugin inside the Zuraffa plugin system

**Performance Goals**: bone generation < 10s for any named feature (SC-001);
cycle detection over ≤ 20 bones < 5s (SC-003)

**Constraints**: bones must be self-contained — every import/reference inside a
bone resolves to a local stub or a declared dependency (FR-005); no network
transfer for v1 (export is a local artifact only); spec parsing is structural
(headings/entity declarations), not prose inference

**Scale/Scope**: dependency graphs up to 20 inter-bone references (SC-003);
43 existing spec directories under `specs/` as potential inputs

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

`.specify/memory/constitution.md` is the unfilled template (no principles,
gates, or governance rules are defined for this project). There are therefore
no constitution gates to violate. The plan still follows the repo's own
standing conventions (AGENTS.md): plugin-system integration instead of a
parallel command framework, `test`-package TDD, and `.zfa/` as the memory
surface for generated artifacts.

**Post-design re-check**: no violations introduced by Phase 1 design — the
plugin reuses `ZuraffaPlugin`/`CliAwarePlugin`/`PluginRegistry`, the existing
`FileUtils` write path, and the existing `test/` layout. One new dependency
(`archive`) is added; it is the standard pub package for tar.gz and replaces no
existing capability.

## Project Structure

### Documentation (this feature)

```text
specs/020-skeleton-plugin-bones/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
└── tasks.md             # Phase 2 output (/skill:speckit-tasks)
```

### Source Code (repository root)

```text
lib/src/plugins/skeleton/
├── skeleton_plugin.dart            # SkeletonPlugin (FileGeneratorPlugin + CliAwarePlugin)
├── bone_command.dart               # `zfa bone` command tree (generate / export / validate)
├── builders/
│   ├── bone_scaffold_builder.dart  # directory + placeholder file emission
│   ├── entity_stub_builder.dart    # Dart entity stub source via code_builder
│   └── manifest_builder.dart       # bone.yaml render
├── generators/
│   ├── bone_generator.dart         # orchestrates one bone build
│   ├── dependency_resolver.dart    # graph build + Kahn topological sort + cycle errors
│   └── spec_reader.dart            # reads feature spec + entity declarations
└── models/
    ├── bone.dart                   # Bone, BoneManifest, EntityStub, LayerPlaceholder
    └── dependency_graph.dart       # graph model + topological sort result

test/plugins/skeleton/
├── bone_generator_test.dart
├── dependency_resolver_test.dart
├── spec_reader_test.dart
├── manifest_builder_test.dart
└── bone_command_test.dart
```

**Structure Decision**: Option 1 (single project). The feature is a new plugin
inside the existing Zuraffa package, following the established
`lib/src/plugins/<name>/` layout (plugin class + builders/ + generators/ +
capabilities-or-models/). Tests mirror under `test/plugins/skeleton/`.
Registration is one line in `PluginLoader._plugins()`
(`lib/src/cli/plugin_loader.dart`), which auto-registers the `zfa bone` command
via `CliAwarePlugin`.

## Complexity Tracking

No constitution violations to justify. The single notable addition is the
`archive` package dependency (for FR-006 export); it is a mainstream pub.dev
package and the simplest correct way to emit `.tar.gz` from pure Dart.
