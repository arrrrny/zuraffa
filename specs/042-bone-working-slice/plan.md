# Implementation Plan: Bone Working Slice — minimal runnable Flutter app per feature with swappable DI

**Branch**: `042-bone-working-slice` | **Date**: 2026-08-29 | **Spec**: [spec.md](./spec.md)

## Summary

Upgrade the skeleton plugin's `zfa bone generate` from empty stub emission to a "Bone Working
Slice": per feature, generate real entities (fields, `fromJson`, validation), abstract repositories,
CRUD use cases, mock + firebase data sources, a data-layer repository, a swappable self-contained
DI container, real runnable tests, and — with `--flutter` — a minimal `pubspec.yaml`, runnable
`lib/main.dart`, presentation page, and widget test. Add `--di mock|firebase|auto`, `--flutter`,
`--include-deps`, and `--export` to the generate subcommand. The existing dependency graph decides
which transitive shared entities are inlined. `zfa bone export`/`validate` keep working; validate
additionally honors packages declared in the bone's own `pubspec.yaml`.

## Technical Context

**Language/Version**: Dart 3.13+ (SDK `^3.11.0` constraint in pubspec). Flutter 3.47+ is the
consumer toolchain for `--flutter` bones; zuraffa itself is pure Dart.

**Primary Dependencies**: `args`, `path`, `yaml`, `crypto`, `code_builder`, `dart_style`,
`archive` (existing tar.gz export), `get_it` (host app only — bones stay dependency-free), the
existing skeleton plugin (`SpecReader`, `DependencyResolver`, `BoneExporter`, manifest) and the
`zfa make` generator naming conventions (Get/Create/Update/Delete use cases, repository interface
+ data implementation, abstract data source).

**Storage**: Filesystem only — bones under `.zfa/bones/<slug>/`, exported tar.gz artifacts next to
the bones dir, manifest `bone.yaml` inside each bone.

**Testing**: `dart test` for zuraffa (existing suite + new tests under `test/plugins/skeleton/`).
Generated bones are verified by actually running their self-contained tests with `dart run` and
analyzing the pure-Dart core with `dart analyze` inside a scratch package (hermetic, no network).

**Project Type**: CLI tool. This feature modifies `lib/src/plugins/skeleton/` (models, generators,
builders, command) and its tests; no other plugin is touched.

## Constitution Check

PASS on all six gates:
- **Library-first**: all new logic lives in builder/generator classes under the plugin; the CLI is
  a thin parser over them.
- **CLI interface**: the new surface is the documented `zfa bone generate` flag set.
- **Test-first**: `tdd/test-list.md` drives every unit (U-series) and acceptance (A-series)
  behavior; red evidence recorded before implementation.
- **Integration testing**: scenario tests generate bones into temp dirs, run their tests with the
  real Dart SDK, analyze them, export and unpack artifacts.
- **Observability**: `bone.yaml` records `di`/`di_source`/`flutter`/`entrypoint`; errors name
  entity/field/type; generation is atomic with no partial output.
- **Simplicity/YAGNI**: no new pub dependencies, no codegen pipeline, no firebase packages —
  Firestore REST over `dart:io` keeps bones self-contained.

## Project Structure

```text
specs/042-bone-working-slice/
├── spec.md
├── plan.md
├── tasks.md
├── analysis.md
└── tdd/
    ├── test-list.md
    └── verification.md
```

```text
lib/src/plugins/skeleton/
├── bone_command.dart                (extended: --di/--flutter/--include-deps/--export)
├── models/
│   ├── bone.dart                    (extended: DiChoice, working-slice fields)
│   └── dependency_graph.dart        (unchanged)
├── generators/
│   ├── spec_reader.dart             (extended: per-entity field parsing)
│   ├── bone_generator.dart          (extended: DI resolution, dep inlining, flutter mode)
│   ├── di_choice_resolver.dart      (new: --di auto detection from pubspec/zfa.yaml)
│   └── bone_exporter.dart           (unchanged)
└── builders/
    ├── entity_stub_builder.dart     (rewritten → real entities: fields/fromJson/toJson/copyWith/validate)
    ├── manifest_builder.dart        (extended: di/di_source/flutter/entrypoint keys)
    ├── bone_scaffold_builder.dart   (rewritten → working slice: domain/data/di/tests[/presentation])
    └── slice/                       (new builder per layer)
        ├── repository_builder.dart      (interface + data impl + datasource interface)
        ├── usecase_builder.dart        (Get/Create/Update/Delete per entity)
        ├── datasource_builder.dart     (mock + firebase per entity)
        ├── injection_builder.dart      (DI container with backend enum)
        ├── presentation_builder.dart   (--flutter page + widget test)
        └── app_entry_builder.dart      (--flutter pubspec.yaml + lib/main.dart)
```

```text
test/plugins/skeleton/
├── (existing unit tests updated to the new emission shape)
├── di_choice_resolver_test.dart     (new)
├── builders/slice/*_test.dart       (new)
├── fixtures/profile-feature/spec.md (new: field-declaring spec)
└── scenarios/sc_005_working_slice_test.dart  (new: analyze + run + export + size)
```

## Complexity Tracking

No violations. The largest new unit is the DI injection builder (~200 lines); every builder is a
pure string/AST → source transformation with isolated tests.
