# Feature Specification: Migrate vendure Package to Zuraffa Framework

**Feature Branch**: `065-vendure-zuraffa-migration`

**Created**: 2026-09-01

**Status**: Draft

**Input**: User description: "Migrate vendure package to zuraffa framework"

## User Scenarios & Testing *(mandatory)*

<!--
  This is a framework migration rather than a user-facing feature.
  User stories are framed from the perspective of the migration team
  and downstream consumers who depend on vendure's pub.dev package.
-->

### User Story 1 - Migrate vendure as a Zuraffa Package (Priority: P1)

A maintainer migrates the vendure package codebase to be built on the zuraffa framework, rewriting its internals so that vendure's architecture follows zuraffa's entity/data-source/repository/use-case/presenter patterns.

**Why this priority**: This is the core deliverable of the migration. Without a correct rewrite, vendure cannot be considered a proper zuraffa package.

**Independent Test**: Can be validated by running `zfa build` in the vendure repository and confirming the generated artifacts match the expected zuraffa architecture layout.

**Acceptance Scenarios**:

1. **Given** a vendure package source tree, **When** the migration is complete, **Then** the package exposes the same public API surface it had before the migration, with no breaking changes.
2. **Given** the migrated vendure package, **When** it is added as a dependency in a zuraffa application, **Then** it is recognized by `zfa` commands and integrates with zuraffa's plugin registry.
3. **Given** the migrated vendure package, **When** `zfa build` runs on a project that depends on vendure, **Then** the build completes without errors related to vendure's internals.

---

### User Story 2 - Preserve pub.dev Consumer Compatibility (Priority: P1)

A downstream application that already depends on vendure from pub.dev continues to work without modification after the migration.

**Why this priority**: Breaking the pub.dev API contract would affect all existing vendure consumers. Compatibility is a non-negotiable constraint.

**Independent Test**: Can be validated by running the existing vendure test suite against the migrated codebase; all tests that passed before migration must pass after migration.

**Acceptance Scenarios**:

1. **Given** a project that uses vendure as a pub.dev dependency, **When** vendure is updated to the migrated version, **Then** the project builds and runs without code changes.
2. **Given** vendure's public API types, **When** they are exercised with the same inputs as before migration, **Then** they produce identical outputs.

---

### User Story 3 - Platform Implementation Correctness (Priority: P2)

The migrated vendure package correctly defers to the zikzak_inappwebview package for platform-specific implementations on Android, Windows, Linux, and macOS.

**Why this priority**: Platform implementations are managed by the umbrella zikzak_inappwebview package per the parent issue #214. Vendure should not duplicate platform logic.

**Independent Test**: Can be validated by confirming the migrated vendure package does not contain android/, windows/, linux/, or macos/ implementation directories, and that platform functionality routes through zikzak_inappwebview.

**Acceptance Scenarios**:

1. **Given** the migrated vendure package, **When** platform-specific code is needed, **Then** the code delegates to zikzak_inappwebview rather than implementing it directly.
2. **Given** the migrated vendure package, **When** it is built on each target platform, **Then** platform compilation succeeds via the zikzak_inappwebview integration.

---

### Edge Cases

- What happens when a vendure API type has no direct zuraffa equivalent? The migration must map it to the nearest zuraffa entity or create a compatible shim.
- How does the migration handle vendure's internal state management that may not map to zuraffa's state patterns? A compatibility layer must be introduced.
- How does the migration handle vendure's transitive dependencies that may conflict with zuraffa's own dependencies? Dependency resolution must be validated.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The vendure package MUST be rewritten to follow zuraffa's canonical architecture: entities, data sources, repositories, use cases, and presenters.
- **FR-002**: The vendure package MUST expose the same public API surface (classes, methods, properties) that existed before the migration, producing identical behavior for all public interfaces.
- **FR-003**: The vendure package MUST register itself with zuraffa's plugin registry so that `zfa` commands recognize and operate on vendure entities.
- **FR-004**: The vendure package MUST declare the correct zuraffa dependency in its pubspec.yaml so it participates in the zuraffa build system.
- **FR-005**: The vendure package MUST NOT contain direct platform-specific implementations for Android, Windows, Linux, or macOS; it MUST delegate platform behavior to the zikzak_inappwebview package.
- **FR-006**: All existing vendure tests MUST pass against the migrated codebase with no modifications to the test suite itself.
- **FR-007**: The vendure package MUST be published to pub.dev as a valid Dart package that depends on zuraffa.

### Key Entities *(include if feature involves data)*

- **Vendure Package**: The Dart/Flutter package being migrated, distributed on pub.dev. Its public API contract is the primary constraint of this migration.
- **Zuraffa Framework**: The framework vendure is being rewritten on. Provides entity/data-source/repository/use-case/presenter patterns and the `zfa` CLI tool.
- **ZikzakInappwebview**: The umbrella platform package that handles Android/Windows/Linux/macos implementations. Vendure delegates platform logic to this package.
- **pub.dev**: The distribution channel for the vendure package. The migrated package must be a valid, publishable Dart package.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of vendure's public API surface is preserved — zero breaking changes for downstream consumers.
- **SC-002**: `zfa build` completes successfully on a project that depends on the migrated vendure package, with zero errors.
- **SC-003**: All existing vendure unit and integration tests pass against the migrated codebase.
- **SC-004**: The migrated vendure package has zero android/, windows/, linux/, or macos/ source directories; all platform implementations delegate to zikzak_inappwebview.
- **SC-005**: The migrated vendure package has a valid pubspec.yaml with a zuraffa dependency and can be published to pub.dev.

## Assumptions

- The vendure package source code is available and can be rewritten following zuraffa's patterns.
- The existing vendure public API surface is well-defined and documented (or discoverable), so the migration team can ensure no breaking changes.
- The zuraffa framework provides adequate patterns to represent vendure's internal state and logic without requiring fundamental behavior changes.
- Vendure's transitive dependencies do not conflict with zuraffa's dependency tree; any conflicts will be resolved via dependency overrides or version adjustments.
- The migration scope covers only vendure itself; the parent issue #214 coordinates the broader ZikZak package migration effort.
