# Implementation Plan: Cache Adapter Command

**Branch**: `009-cache-adapter-command` | **Date**: 2026-06-12 | **Spec**: spec.md

**Input**: Feature specification from `specs/009-cache-adapter-command/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command.

## Summary

Add a `zfa cache adapter <EntityName>` CLI sub-command that automatically generates Hive type adapters for entities and all their sub-entities. The command discovers the entity's field types recursively, updates the Hive registrar file (both `HiveRegistrar` on `HiveInterface` and `IsolatedHiveRegistrar` on `IsolatedHiveInterface`) with imports and `registerAdapter()` calls, then runs `zfa build` to generate the actual adapter classes via build_runner. This eliminates the manual, error-prone process of wiring up Hive adapters whenever a new entity needs caching.

## Technical Context

**Language/Version**: Dart 3.x (with Zuraffa v5 framework)

**Primary Dependencies**:

- `hive_ce` / `hive_ce_flutter` — Hive Community Edition for local storage
- `hive_ce_generator` — Code generator for Hive type adapters
- `build_runner` — Dart build system (invoked via `zfa build`)
- `code_builder` — Programmatic Dart code generation (existing in Zuraffa)
- `args` — CLI argument parsing (existing in Zuraffa)
- `zuraffa` core — Plugin system (ZuraffaCapability, PluginCommand, FileGeneratorPlugin)

**Storage**: Hive CE (Community Edition), file-based local storage

**Testing**: `dart test` / `flutter test` with the Zuraffa project's test suite

**Target Platform**: Dart VM (CLI tool), Flutter (generated code consumer)

**Project Type**: CLI framework tool (Zuraffa v5 generator CLI) — the `zfa` command

**Performance Goals**:

- Command execution under 3 seconds for an entity with 10 sub-entities
- Zero perceptible delay for entity analysis (<500ms)
- No network calls involved

**Constraints**:

- Must follow existing Zuraffa v5 plugin architecture (capability pattern)
- Must be idempotent — running multiple times should not create duplicates
- Must preserve all existing adapter registrations
- Must support both entity classes and enum types
- The `@GenerateAdapters` annotation + `hive_generator` pattern must be maintained

**Scale/Scope**: Developer tooling for Zuraffa projects; single-project scope, no distributed or multi-user concerns

## Constitution Check

_GATE: Must pass before Phase 0 research. Re-check after Phase 1 design._

The `.specify/memory/constitution.md` is a template with no custom principles or governance rules defined. All gates pass by default — there are no constitution-level constraints to evaluate. Design decisions should follow Zuraffa v5 conventions as documented in AGENTS.md and the existing plugin architecture.

**GATE Result: PASS** (no constitution constraints to violate)

## Project Structure

### Documentation (this feature)

```text
specs/009-cache-adapter-command/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command)
│   └── cli-interface.md # CLI command contract
└── tasks.md             # Phase 2 output (/speckit-tasks command)
```

### Source Code (repository root)

```text
lib/src/
├── plugins/
│   └── cache/
│       ├── cache_plugin.dart                    # [EXISTING] CachePlugin class
│       ├── capabilities/
│       │   ├── create_cache_capability.dart      # [EXISTING] CreateCacheCapability
│       │   └── create_cache_adapter_capability.dart  # [NEW] New adapter capability
│       └── builders/
│           ├── cache_builder.dart                # [EXISTING] CacheBuilder
│           ├── cache_builder_registrar.dart      # [EXISTING] Hive registrar generation
│           └── cache_policy_builder.dart         # [EXISTING] Policy generation
├── commands/
│   ├── base_plugin_command.dart                  # [EXISTING] PluginCommand base
│   ├── capability_command.dart                   # [EXISTING] CapabilityCommand
│   └── cache_command.dart                        # [EXISTING] CacheCommand (auto-registers capabilities)
└── core/
    └── plugin_system/
        ├── capability.dart                       # [EXISTING] ZuraffaCapability interface
        └── ...
```

**Structure Decision**: The new `adapter` capability follows the existing pattern: a new `CreateCacheAdapterCapability` class in `plugins/cache/capabilities/`, registered in `CachePlugin.capabilities`, and auto-discovered by `CacheCommand` via `CapabilityCommand`. No structural changes to the plugin system are needed.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

No constitution violations. Complexity tracking section is not needed.
