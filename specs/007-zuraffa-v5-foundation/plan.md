# Implementation Plan: Zuraffa V5 Foundation

**Branch**: `007-zuraffa-v5-foundation` | **Date**: 2026-05-31 | **Spec**: [spec.md](./spec.md)  
**Input**: Feature specification from `/specs/007-zuraffa-v5-foundation/spec.md`

## Summary

Zuraffa v5 will unify the framework around a single canonical generation contract: `zfa make`. It will remove `zfa generate`, reduce `zfa feature` to a preset wrapper, make plugin orchestration deterministic, persist project/agent memory in `.zfa/`, formalize “generated architecture vs handcrafted UI” boundaries, and add framework-level platform-aware presentation composition (layouts + shells) for mobile/tablet/desktop/macOS/web divergence. The implementation prioritizes AI-agent reliability, enterprise-grade governance, hermetic testing, and documentation coherence.

## Technical Context

**Language/Version**: Dart 3.11+, Flutter 3.41+  
**Primary Dependencies**: `args`, `path`, `responsive_builder`, plugin system under `lib/src/core/plugin_system/`  
**Storage**: `.zfa/` project-local JSON/Markdown artifacts for plans, runs, blueprints, decisions, manifests  
**Testing**: `flutter test` for hermetic/default suites, gated external-integration tests for local-infra dependencies, `dart analyze` for touched surfaces  
**Target Platform**: Dart CLI for generation; Flutter mobile/tablet/desktop/macOS/web for generated application structure  
**Project Type**: Framework + CLI + docs website  
**Performance Goals**: `zfa make` plan resolution should be near-instant; small feature generation under ~3 seconds cold / medium feature generation under ~8 seconds where practical  
**Constraints**: v5 may be breaking; architecture code must be generated only via `zfa`; only UI composition/layout/manual zones should be hand-crafted; default tests must not require local MinIO; the domain root is fixed to `lib/src/domain`; Zuraffa v5 is greenfield-first and Zorphy-only  
**Scale/Scope**: Cross-cutting v5 foundation spanning CLI, planning, plugin orchestration, config, persistence, presentation architecture, tests, docs, and migration

## Constitution Check

_GATE: Must pass before Phase 0 research. Re-check after Phase 1 design._

The constitution template is unpopulated (all section values are placeholders). No enforceable constitutional rules exist for this project. All gates pass by default.

**Pre-Design**: PASS (no rules to violate)  
**Post-Design**: PASS (no rules to violate)

## V5 Decisions Locked by This Plan

1. **Canonical command**: `zfa make`
2. **Removed command**: `zfa generate`
3. **Wrapper only**: `zfa feature`
4. **Generation policy**: entity-first for entity-aware flows
5. **Project type focus**: greenfield-first
6. **Persistence root**: `.zfa/` (not `.zuraffa/`)
7. **Domain root**: fixed to `lib/src/domain`
8. **Entity model**: Zorphy-only
9. **Architecture boundary**: generated architecture, handcrafted experience
10. **Presentation evolution**: platform-aware layouts + shells with shared presenter/controller/state
11. **Testing policy**: hermetic by default; external/local-service tests gated separately

## Project Structure

### Documentation (this feature)

```text
specs/007-zuraffa-v5-foundation/
├── spec.md               # This file's source specification
├── plan.md               # This file
└── tasks.md              # Execution-ready tasks
```

### Source Code (repository root)

```text
lib/src/
├── commands/
│   ├── make_command.dart                # PRIMARY CLI entrypoint for generation
│   ├── feature_command.dart             # Wrapper over make/presets
│   └── generate_command.dart            # REMOVE in v5
├── config/
│   └── zfa_config.dart                  # Unify `.zfa.json` defaults
├── cli/
│   └── plugin_loader.dart               # Plugin availability + disabled/default handling
├── core/
│   ├── plugin_system/
│   │   ├── plugin_manager.dart          # Deterministic plan resolution + execution
│   │   ├── plugin_registry.dart         # DAG ordering
│   │   ├── plugin_interface.dart        # Plugin config contract
│   │   └── plan_store.dart              # Migrate storage from `.zuraffa/` to `.zfa/`
│   ├── planning/                        # NEW: normalized plans, presets, alias resolution
│   └── project/                         # NEW: robust project root/context resolution
├── generator/
│   └── code_generator.dart              # Must use same plan resolution as CLI
└── presentation/
    ├── responsive_view.dart             # Existing breakpoint-only foundation
    ├── platform/                        # NEW: device/platform/layout resolution
    ├── shells/                          # NEW: platform/device app shells
    └── pages/**/layouts/                # NEW: generated layout extension points

README.md
CLI_GUIDE.md
AGENTS.md
SKILL.md
website/docs/**

.zfa/
├── plans/
├── runs/
├── blueprints/
├── decisions/
├── manifests/
└── context.json
```

## Architecture Strategy

### 1. Unified Planning Layer

Create a normalized planning subsystem responsible for:

- preset resolution
- plugin alias/group resolution (e.g. `data` => `repository,datasource`)
- defaults from `.zfa.json`
- explicit inclusions/exclusions
- validation/preconditions
- execution ordering
- machine-readable serialization

This planning layer will be used by:

- `zfa make`
- `zfa feature`
- direct plugin commands
- `CodeGenerator`
- MCP/agent-facing flows

### 2. `.zfa` Project Memory Layer

Persist project intelligence in `.zfa/`:

- **plans/** for normalized execution contracts
- **runs/** for completed executions
- **blueprints/** for reusable project/feature templates
- **decisions/** for architectural policies/manual zones
- **manifests/** for generated structure snapshots
- **context.json** for high-level project defaults and agent contract summaries

### 3. Platform-Aware Presentation Layer

Extend current breakpoint responsiveness into framework-level awareness of:

- **device class**: watch/phone/tablet/desktop
- **platform class**: iOS/Android/macOS/windows/linux/web
- **layout fallback**: platform-specific → device-specific → generic fallback
- **shells**: navigation/sidebar/split-view composition by platform/device

Generated logic stays shared:

- presenter
- controller
- state
- usecases

Manual work is focused on:

- page layout widgets
- shell composition
- visual styling/polish

## Opinionated Simplifications

### Greenfield-Only Cutoffs

V5 explicitly optimizes for clean new projects and drops accommodation for ambiguous or legacy-friendly modes that increase agent uncertainty.

Removed/unsupported directions include:

- custom domain root paths
- arbitrary domain output overrides
- non-Zorphy entity modes
- mixed architectural conventions designed to retrofit unknown legacy structures

### Fixed Domain Contract

V5 treats the domain layer as a fixed convention:

```text
lib/src/domain/
```

This is not configurable. Domain organization may still support bounded contexts by folder naming under the fixed root, but not by changing the root path itself.

### Zorphy-Only Entity Contract

V5 assumes all entities are Zorphy entities. This simplifies:

- generation logic
- prompts and docs
- patch/update conventions
- agent assumptions
- architecture validation

## Migration Strategy

### Breaking Changes

- Remove `zfa generate` entirely in v5
- Update all official docs, skills, examples, and internal guidance
- Update tests and regression fixtures to target `make`/`feature`/plugin commands

### Compatibility Boundary

No backward-compatibility requirement is retained for `generate`. Instead, the migration story is explicit documentation and updated examples.

## Validation Strategy

### Core Validation

- `flutter test` hermetic/default suites
- targeted CLI/integration/regression tests for `make`
- `dart analyze` on changed files
- doc/reference grep checks proving removal of `zfa generate`

### Platform/Layout Validation

- generate sample platform-aware features and verify file structure
- validate layout fallback logic in widget/unit tests
- use a downstream app (notably `Developer/zik_zak`) as a manual/real-world validation target once workspace access is available

### Test Isolation

MinIO/local-service tests will be moved behind an explicit opt-in mechanism, e.g. integration tags or environment variables, so default CI remains hermetic.

## Risks & Mitigations

### Risk: Removing `generate` causes disruption

**Mitigation**: provide complete migration docs and rewrite every official example before release.

### Risk: Planning logic diverges between CLI and programmatic APIs

**Mitigation**: centralize all resolution in a single planning module consumed by every entrypoint.

### Risk: Platform-aware shells/layouts become overly complex

**Mitigation**: keep shared business logic in presenter/controller/state and generate only thin layout/shell extension points with clear fallback rules.

### Risk: `.zfa` artifacts become noisy or inconsistent

**Mitigation**: version the schema, keep machine-readable JSON normalized, and treat plans/runs/decisions as first-class outputs with tests.

### Risk: Docs drift again over time

**Mitigation**: add documentation validation checks and a single canonical quickstart that all docs link back to.

## Phase 1 Baseline Findings

### Current test-suite baseline (2026-05-31)

A timed `flutter test` baseline confirmed the current suite is not hermetic by default. Key observed failures/regressions outside the requested local-MinIO exception include:

- `test/integration/toggle_method_test.dart`
- `test/integration/multi_entity_test.dart`
- `test/integration/append_mode_test.dart`
- `test/integration/performance_benchmark_test.dart`
- `test/integration/full_entity_workflow_test.dart`
- `test/integration/caching_workflow_test.dart`
- `test/regression/compare_outputs_test.dart`
- `test/regression/pattern_compliance_test.dart`
- `test/regression/file_structure_test.dart`
- `test/cli/cli_edge_cases_test.dart`
- `test/regression/cli_command_test.dart`

Additionally, the default suite currently includes a local-MinIO-dependent failure in `test/core/artifact_publisher_test.dart`, which v5 will explicitly gate out of the default path.

### Command/docs drift audit

Observed public/internal command drift includes:

- `CLI_GUIDE.md`: 33 references to `zfa generate`
- `AGENTS.md`: 47 references to `zfa generate`
- `SKILL.md`: 17 references to `zfa generate`
- `website/docs/**`: 32 references to `zfa feature`, 25 references to `zfa make`, 0 references to `zfa generate`

This confirms split-brain guidance across internal and external surfaces.

### Root-resolution audit

Current brittle `Directory.current` usage exists across multiple runtime-critical surfaces, including:

- `lib/src/commands/generate_command.dart`
- `lib/src/commands/make_command.dart`
- `lib/src/commands/config_command.dart`
- `lib/src/config/zfa_config.dart`
- `lib/src/cli/plugin_loader.dart`
- `lib/src/core/plugin_system/plan_store.dart`
- `lib/src/plugins/feature/capabilities/scaffold_feature_capability.dart`

This matches the observed subprocess/temp-dir CLI failures.

### Plugin default/config participation audit

The registry currently exposes 20 plugins, but only a small subset participates in project-default activation via `configKey`, including:

- `di`
- `gql`
- `method_append`
- `mock`
- `route`
- `test`

This confirms that `.zfa.json` default behavior is incomplete and inconsistent today.

## Complexity Tracking

> No constitutional violations to justify. Complexity is intentional and cross-cutting because v5 is a foundation release, not a single-file bug fix.
