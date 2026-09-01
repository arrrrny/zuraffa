# Feature Specification: Migrate zuraffa_ffi to Zuraffa

**Feature Branch**: `059-zuraffa-ffi-migration`

**Created**: 2026-09-01

**Status**: Draft

**Input**: GitHub issue #678 (https://github.com/arrrrny/zuraffa/issues/678) — "[v6] Migrate zuraffa_ffi to be built on zuraffa"

## Overview

Migrate the `zuraffa_ffi` package so its codebase is completely rewritten on top of Zuraffa v6, replacing any standalone Flutter or Dart code with Zuraffa's architecture. This is a per-package sub-issue of EPIC #214. The package may not yet have a GitHub repository, in which case the first step is to scaffold it before migration begins.

## User Scenarios & Testing

### User Story 1 - Scaffold zuraffa_ffi Repository (Priority: P1)

As a Zuraffa maintainer, I need the `zuraffa_ffi` repository to exist on GitHub before I can migrate it, so that the package has a canonical home for source code and releases.

**Why this priority**: If the repository does not exist yet, no other work can proceed. This is a prerequisite for everything else.

**Independent Test**: Can be validated by verifying the GitHub repository is created at `github.com/arrrrny/zuraffa_ffi` with an initial commit and the repository is publicly accessible.

**Acceptance Scenarios**:

1. **Given** the `zuraffa_ffi` package has been approved for the Zuraffa ecosystem, **When** the repository is created, **Then** it is created under the `arrrrny` GitHub organization with an appropriate open-source license.
2. **Given** the repository is created, **When** it is listed on pub.dev, **Then** it appears under the `zuzu.dev` publisher.

---

### User Story 2 - Migrate zuraffa_ffi Codebase to Zuraffa (Priority: P1)

As a ZikZak package consumer, I want `zuraffa_ffi` to be built on Zuraffa v6 so that it benefits from consistent architecture, shared infrastructure, and long-term maintainability within the Zuraffa ecosystem.

**Why this priority**: The migration is the core deliverable. All consumers of this package benefit from a well-architected, Zuraffa-native package that integrates seamlessly with other migrated packages.

**Independent Test**: Can be validated by verifying the migrated package compiles, its test suite passes, and it is published to pub.dev under the zuzu.dev publisher.

**Acceptance Scenarios**:

1. **Given** the zuraffa_ffi repository exists, **When** the migration to Zuraffa v6 is complete, **Then** all core FFI capabilities are preserved and exposed through Zuraffa's architecture (entities, repositories, use cases).
2. **Given** the migrated package is published to pub.dev, **When** an existing consumer upgrades their dependency, **Then** the upgrade is non-breaking or provides a clear migration path documented in a CHANGELOG.
3. **Given** the migrated package is published, **When** a developer runs `dart pub get` on a project depending on `zuraffa_ffi`, **Then** the dependency resolves without errors.

---

### User Story 3 - Integrate zuraffa_ffi with the Zuraffa Ecosystem (Priority: P2)

As a Zuraffa ecosystem developer, I want `zuraffa_ffi` to integrate with other Zuraffa v6 packages so that FFI capabilities are available alongside other ZikZak tools within a unified framework.

**Why this priority**: Full ecosystem value is realized only when packages compose together. Integration ensures `zuraffa_ffi` can be used alongside other migrated packages (e.g., the showcase app) without conflicts or awkward inter-package wiring.

**Independent Test**: Can be validated by building and running a Zuraffa v6 application that depends on `zuraffa_ffi`, confirming all features work together and there are no dependency conflicts.

**Acceptance Scenarios**:

1. **Given** `zuraffa_ffi` is migrated to Zuraffa v6, **When** it is added as a dependency to another Zuraffa v6 package, **Then** there are no unresolved type conflicts or circular dependency errors.
2. **Given** the migration plan for all pub.dev packages is executed, **When** the order of migrations is applied, **Then** `zuraffa_ffi` is migrated at the appropriate point in the dependency graph (after packages it depends on, before packages that depend on it).

---

### Edge Cases

- What happens when the `zuraffa_ffi` GitHub repository has not yet been created? The first step must be to scaffold the repository before any migration code is written.
- What happens when the migrated `zuraffa_ffi` introduces breaking changes to its public API? The package versioning must follow semantic versioning, and a major version bump with migration guide is required.
- What happens when `zuraffa_ffi` has dependencies on other ZikZak packages that are themselves being migrated? The migration must respect the inter-package dependency ordering defined in EPIC #214.
- What happens when the FFI layer requires platform-specific native code (C/C++/Rust) that must be compiled? The migration must preserve the native build pipeline and ensure cross-platform builds succeed for all supported platforms.

## Requirements

### Functional Requirements

- **FR-001**: The system MUST create the `zuraffa_ffi` GitHub repository under the `arrrrny` organization if it does not already exist, with an appropriate open-source license.
- **FR-002**: The system MUST rewrite the `zuraffa_ffi` codebase on top of Zuraffa v6, replacing standalone code with Zuraffa's architecture (entities, repositories, use cases, datasources).
- **FR-003**: The migrated `zuraffa_ffi` package MUST maintain API compatibility with any previously published version, or provide a documented semver-major breaking change path with migration guide.
- **FR-004**: The system MUST publish the migrated `zuraffa_ffi` package to pub.dev under the `zuzu.dev` publisher.
- **FR-005**: The system MUST ensure the migrated package passes its full test suite and is buildable on all platforms supported by the original package.
- **FR-006**: The system MUST ensure `zuraffa_ffi` has no unresolved dependencies on packages that have not yet been migrated to Zuraffa v6, unless those packages are explicitly excluded from the migration scope.
- **FR-007**: The system MUST update the EPIC #214 migration tracker to reflect `zuraffa_ffi`'s completion status.

### Key Entities

- **zuraffa_ffi Package**: The FFI package being migrated. Key attributes: package name, current version, FFI capabilities (foreign function bindings), platform targets, dependencies.
- **Migration Plan**: The per-package plan derived from EPIC #214. Key attributes: migration status, execution order, dependency graph position, API compatibility guarantees.
- **Zuraffa v6 Architecture**: The target architecture for the migrated package. Key components: entities, repositories, use cases, datasources, and Zorphy contracts.

## Success Criteria

### Measurable Outcomes

- **SC-001**: The `zuraffa_ffi` GitHub repository exists at `github.com/arrrrny/zuraffa_ffi` within the first phase of this feature's execution.
- **SC-002**: The migrated `zuraffa_ffi` package passes its full test suite and is published to pub.dev under the `zuzu.dev` publisher with zero regressions in API surface area (or documented breaking changes at major version bumps).
- **SC-003**: An existing consumer can upgrade to the migrated version without compilation errors, or can follow a documented migration path in the CHANGELOG.
- **SC-004**: `zuraffa_ffi` integrates with the broader Zuraffa v6 ecosystem without dependency conflicts, verified by a dependent package building and running successfully.

## Assumptions

- The original `zuraffa_ffi` package's FFI capabilities and public API are well-understood and documented, or can be recovered from any existing references.
- Zuraffa v6 is stable enough to serve as the foundation for rewriting the package without requiring simultaneous changes to Zuraffa core.
- The FFI layer's platform-specific native code (if any) will be preserved and integrated into the migrated package's build pipeline.
- The migration follows the execution order defined in EPIC #214 and does not need to resolve circular dependencies beyond those already addressed in the EPIC plan.
