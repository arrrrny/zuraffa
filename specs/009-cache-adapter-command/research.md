# Research: Cache Adapter Command

**Feature**: Cache Adapter Command
**Date**: 2026-06-12

## Overview

Analysis of the existing Zuraffa cache plugin architecture and design decisions for adding a `zfa cache adapter` sub-command.

## Design Decisions

### Decision 1: Use existing capability pattern

- **Decision**: Implement the adapter command as a new `ZuraffaCapability` (`CreateCacheAdapterCapability`) registered in `CachePlugin.capabilities`
- **Rationale**: The existing `CapabilityCommand` framework auto-registers capabilities as CLI sub-commands with dynamic argument parsing from JSON schemas. This requires zero changes to `CacheCommand` or the CLI runner. The pattern is proven and consistent with how `CreateCacheCapability` works for `zfa cache create`.
- **Alternatives considered**:
  - Custom CLI sub-command registered manually in `CacheCommand`: Rejected — would require duplicating argument parsing logic that `CapabilityCommand` already provides
  - Standalone command at the `zfa` root level: Rejected — the adapter feature belongs to the cache plugin, not a top-level concept

### Decision 2: Entity sub-discovery via existing EntityAnalyzer

- **Decision**: Reuse the `EntityAnalyzer.analyzeEntity()` and `_collectSubtypeAdapters()` methods from `CacheBuilderRegistrar`
- **Rationale**: The `cache_builder_registrar.dart` already has `_collectNestedEntitiesForHive()` and `_collectSubtypeAdapters()` methods that scan entity files, extract field types, and recursively discover sub-entities. Reusing this avoids duplicating entity analysis logic.
- **Alternatives considered**:
  - Custom field-scanning using the filesystem directly: Rejected — would duplicate existing logic
  - Relying on Dart's reflection/mirrors: Rejected — not suitable for ahead-of-time compilation in CLI tools

### Decision 3: Registrar modification via code_builder (same pattern as existing)

- **Decision**: Update the Hive registrar using the same `code_builder` library approach as `_regenerateHiveRegistrar()`
- **Rationale**: The existing registrar generation already uses `SpecLibrary` / `code_builder` to emit the complete registrar file from scratch. The adapter command should similarly regenerate the full registrar, scanning both auto-discovered entities from cache files AND the new entity's sub-entities.
- **Alternatives considered**:
  - Line-based patching of the registrar file: Rejected — fragile, error-prone, and harder to maintain than full regeneration
  - Appending to an intermediate file (like `hive_manual_additions.txt`): Already exists as a manual fallback; programmatic adapter command should use full regeneration

### Decision 4: Support entity names and enums via the same command

- **Decision**: The `zfa cache adapter EntityName` command accepts both entity classes and enum types. The command uses `EntityAnalyzer` for entity detection and falls back to enum detection for the given name.
- **Rationale**: The user explicitly requested this. The existing registrar file in the example shows both `AdapterSpec<EntityName>()` and `AdapterSpec<EnumType>()` in the same list.
- **Alternatives considered**:
  - Separate `entity` and `enum` sub-commands: Rejected — unnecessary complexity, both are identical operations from the registrar's perspective

### Decision 5: Run `zfa build` automatically after adapter registration

- **Decision**: The command will optionally trigger `zfa build` (build_runner) after updating the registrar, but only if the user passes a flag like `--build` or `--run-build`
- **Rationale**: The user may want to chain multiple adapter additions before running the build. Auto-running build may be disruptive. However, the user's description says "then run zfa build", so it should be a convenience option.
- **Alternatives considered**:
  - Always run build: Rejected — slow and disruptive
  - Run build by default with `--no-build` flag: Rejected — less intuitive
  - Print instructions to run `zfa build` and exit: Accepted as default behavior; `--build` flag triggers automatic build

### Decision 6: Idempotency via deduplication in registrar generation

- **Decision**: The registrar file is fully regenerated each time, with deduplication by entity name. Existing adapters are preserved because the scanner reads all existing cache files and the manual additions file.
- **Rationale**: Full regeneration is simpler and safer than patching. The `_regenerateHiveRegistrar` method already handles this by scanning all `*_cache.dart` files in the cache directory plus the manual additions file.
- **Alternatives considered**:
  - Check-and-append: Rejected — harder to detect removals and ensure consistency

## Technology Choices

### Hive Community Edition (hive_ce) vs hive

- **Decision**: Use `hive_ce` (already in use by the project)
- **Rationale**: The existing cache plugin and registrar files use `hive_ce_flutter` and `hive_ce` imports. This is consistent.
- **Alternatives considered**: Not applicable — must follow existing project choice.

### code_builder for code generation

- **Decision**: Use `code_builder` package (already in use)
- **Rationale**: The entire Zuraffa generator uses `code_builder` + `SpecLibrary` for emitting Dart source code. The registrar file is already generated with this approach.
- **Alternatives considered**:
  - String concatenation: Rejected — hard to maintain, no syntax safety

### build_runner / hive_generator for adapter class generation

- **Decision**: Keep the existing `@GenerateAdapters` annotation + `hive_ce_generator` + `build_runner` workflow. The adapter command only modifies the registrar; `zfa build` generates the actual adapter class files.
- **Rationale**: The `@GenerateAdapters` annotation automatically generates `*Adapter` classes at build time. This is the standard `hive_ce` workflow and already integrated into the project.
- **Alternatives considered**:
  - Generate adapter .dart files directly with code_builder: Rejected — would bypass the hive_generator and risk incompatibility with hive_ce internals
