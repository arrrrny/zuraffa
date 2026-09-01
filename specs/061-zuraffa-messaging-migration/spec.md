# Feature Specification: Migrate zuraffa_messaging to Zuraffa v6

**Feature Branch**: `061-zuraffa-messaging-migration`

**Created**: 2026-09-01

**Status**: Draft

**Input**: GitHub issue #671 (https://github.com/arrrrny/zuraffa/issues/671) — sub-issue of EPIC #214 (https://github.com/arrrrny/zuraffa/issues/214): migrate the `zuraffa_messaging` package to be built on Zuraffa v6.

## User Scenarios & Testing

### User Story 1 - Scaffold and Migrate zuraffa_messaging Package (Priority: P1)

As a ZikZak package consumer, I want the `zuraffa_messaging` package rebuilt on Zuraffa v6 so that messaging functionality is available as part of a modern, well-architected toolkit with consistent APIs and shared infrastructure.

**Why this priority**: Messaging is a foundational package in the ZikZak ecosystem. Migrating it to Zuraffa v6 establishes the correct pattern for subsequent package migrations and ensures the messaging package benefits from Zuraffa's architecture.

**Independent Test**: Can be validated by verifying that the migrated package compiles, passes its test suite, and publishes successfully to pub.dev under the zuzu.dev publisher.

**Acceptance Scenarios**:

1. **Given** the `zuraffa_messaging` GitHub repository does not yet exist, **When** the migration begins, **Then** the repository is scaffolded using the Zuraffa project structure and naming conventions.
2. **Given** the `zuraffa_messaging` codebase has been rewritten on Zuraffa v6, **When** a developer runs the package tests, **Then** all tests pass.
3. **Given** the migrated package passes its full test suite, **When** it is published to pub.dev under the zuzu.dev publisher, **Then** the package is available for consumption and is API-compatible with any previously documented interface.
4. **Given** the migrated package is published, **When** an existing consumer upgrades their dependency, **Then** the upgrade is non-breaking or provides a clear migration path documented in a CHANGELOG.

---

### User Story 2 - Align zuraffa_messaging with Zuraffa v6 Architecture (Priority: P1)

As a Zuraffa framework user, I want `zuraffa_messaging` to follow Zuraffa v6 conventions (entity-first design, use-case architecture, VPC stack) so that the package integrates consistently with other Zuraffa-built packages and the showcase application.

**Why this priority**: Consistency across the package ecosystem is critical for developer experience. Messaging must follow the same architectural patterns as other migrated packages to ensure the framework feels unified.

**Independent Test**: Can be validated by reviewing that the package source uses Zuraffa entity definitions, use cases, repositories, and datasources in the expected directory layout.

**Acceptance Scenarios**:

1. **Given** the migrated `zuraffa_messaging` package, **When** its source structure is reviewed, **Then** it follows the Zuraffa v6 fixed layout: entities, repositories, datasources, and use cases are organized under the domain root.
2. **Given** the migrated package uses the VPC stack, **When** a developer examines the package, **Then** they can use Zuraffa commands (`zfa make`, `zfa build`) to extend or modify it without manual code generation.
3. **Given** the migrated package is part of a showcase application, **When** it is imported as a dependency, **Then** there are no version conflicts with other Zuraffa v6 packages.

---

### Edge Cases

- What happens when the `zuraffa_messaging` repository has not been created on GitHub yet? The first step must scaffold the repository and configure pub.dev publishing before migration begins.
- What happens when the existing messaging API surface is large and has many consumers? A compatibility layer or documented migration path must be provided to avoid breaking existing consumers.
- What happens when the migrated package depends on other ZikZak packages that are not yet migrated? The migration order must be resolved so that `zuraffa_messaging` depends only on packages already on Zuraffa v6.

## Requirements

### Functional Requirements

- **FR-001**: The system MUST scaffold the `zuraffa_messaging` GitHub repository using the Zuraffa project structure if it does not already exist.
- **FR-002**: The system MUST rewrite the `zuraffa_messaging` codebase on Zuraffa v6, using entity-first design, use-case architecture, and the VPC stack.
- **FR-003**: The system MUST ensure the migrated package compiles without errors and passes its full test suite.
- **FR-004**: The system MUST publish the migrated package to pub.dev under the zuzu.dev publisher.
- **FR-005**: The system MUST maintain API compatibility with any previously published version of `zuraffa_messaging`, or provide a semver-major breaking change path with a documented migration guide.
- **FR-006**: The system MUST ensure the migrated package has no hard-coded dependencies on non-Zuraffa v6 packages that would block publication or consumer adoption.

### Key Entities

- **zuraffa_messaging Package**: A Dart/Flutter package providing messaging functionality, rebuilt on Zuraffa v6. Key attributes: package name, version, messaging entities, use cases, repository interfaces.
- **Migration Plan**: The parent EPIC #214 defines the migration order and strategy for all packages. `zuraffa_messaging` is one package in that sequence.

## Success Criteria

### Measurable Outcomes

- **SC-001**: The `zuraffa_messaging` repository exists on GitHub and the package is published to pub.dev under the zuzu.dev publisher.
- **SC-002**: The migrated `zuraffa_messaging` package passes its full test suite with zero failures.
- **SC-003**: The migrated package is API-compatible with its previously documented interface, or a CHANGELOG documents breaking changes and migration steps.
- **SC-004**: The migrated package uses Zuraffa v6 architecture (entities, use cases, VPC stack) and can be extended using `zfa` commands without manual code generation.

## Assumptions

- The `zuraffa_messaging` repository does not yet exist on GitHub; scaffolding is required as the first step.
- The parent EPIC #214 defines the migration order; `zuraffa_messaging` is processed according to that order.
- Any existing `zuraffa_messaging` API surface is documented or discoverable from the original published package.
- The migration team has access to the zuzu.dev pub.dev publisher account for publishing.
- Zuraffa v6 is stable and can serve as the foundation for rewriting the package without simultaneous changes to Zuraffa core.
