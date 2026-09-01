# Feature Specification: Migrate zuraffa_intents Package to Zuraffa

**Feature Branch**: `062-migrate-zuraffa-intents`

**Created**: 2026-09-01

**Status**: Draft

**Input**: GitHub issue #672 — [[v6] Migrate zuraffa_intents to be built on zuraffa](https://github.com/arrrrny/zuraffa/issues/672). Sub-issue of EPIC #214.

## User Scenarios & Testing

### User Story 1 - Scaffold and Rewrite zuraffa_intents on Zuraffa (Priority: P1)

As a ZikZak developer, I want `zuraffa_intents` to be a complete rewrite on the zuraffa framework so that it shares infrastructure, APIs, and long-term maintainability with the rest of the Zuraffa ecosystem.

**Why this priority**: This is the primary goal — the package must be rebuilt on Zuraffa before it can ship as part of the v6 ecosystem. It is a sub-issue of EPIC #214 which defines the broader migration context.

**Independent Test**: Can be validated by verifying that the rewritten package compiles, passes its test suite, and publishes successfully to pub.dev under the zuzu.dev publisher.

**Acceptance Scenarios**:

1. **Given** the `zuraffa_intents` GitHub repository does not yet exist, **When** migration begins, **Then** the repository is scaffolded under the `arrrrny` GitHub organization with appropriate initial structure.
2. **Given** the zuraffa framework is available as a dependency, **When** the package code is rewritten, **Then** all intent-related abstractions (intent classes, handlers, dispatchers) are implemented as Zuraffa entities, use cases, and data layers as appropriate.
3. **Given** the package is rewritten, **When** a developer runs the test suite, **Then** all tests pass and the public API surface is preserved or provides a documented migration path for breaking changes.
4. **Given** the rewritten package is published to pub.dev, **When** an existing consumer upgrades their dependency, **Then** the upgrade is non-breaking or documented in a CHANGELOG.

---

### User Story 2 - Maintain API Compatibility with Prior Version (Priority: P1)

As an existing consumer of `zuraffa_intents`, I want the migrated package to be API-compatible with the version I already depend on so that I can upgrade without rewriting my application code.

**Why this priority**: API compatibility is the core contract with existing consumers. Breaking changes require migration work from every consumer and should be avoided unless there is no reasonable alternative.

**Independent Test**: Can be validated by running the existing consumer test suites against the rewritten package without modification.

**Acceptance Scenarios**:

1. **Given** the original `zuraffa_intents` public API (classes, methods, top-level functions), **When** the rewrite is complete, **Then** all public symbols are available with the same signatures, or a documented migration guide exists for any removals/renames.
2. **Given** a consumer uses the intent dispatch mechanism, **When** the migrated package handles an intent, **Then** the behavior is identical to the original implementation.

---

### User Story 3 - Demonstrate zuraffa Capabilities Through the Package (Priority: P2)

As a Zuraffa evaluator, I want `zuraffa_intents` to showcase best practices in Zuraffa architecture — entities, use cases, data sources, dependency injection, and testing — so that I can learn how to build idiomatic Zuraffa packages.

**Why this priority**: Each migrated package serves as a reference implementation. This one should demonstrate how intent-handling patterns map naturally onto Zuraffa's architecture.

**Independent Test**: Can be validated by inspecting the package source and confirming that intent entities are Zuraffa entities, business operations are use cases, and the package includes unit and integration tests.

**Acceptance Scenarios**:

1. **Given** the migrated package, **When** a developer reads its source, **Then** intent classes are Zuraffa entities, intent operations are use cases, and the data layer follows Zuraffa conventions.
2. **Given** the migrated package, **When** a developer runs `dart test`, **Then** a comprehensive test suite runs covering entities, use cases, and integration scenarios.

---

### Edge Cases

- What happens when the original `zuraffa_intents` source is unavailable or the repository has been deleted? A re-implementation from scratch based on pub.dev metadata and any cached references must be attempted before deprecation.
- What happens when the original package uses patterns that do not map cleanly to Zuraffa concepts? The rewrite must decide between a faithful translation (even if not idiomatic Zuraffa) or an idiomatic Zuraffa redesign with a migration guide.
- What happens when the package has external runtime dependencies that themselves need migration? The dependency graph must be resolved before migration — if a dependency is not yet migrated, a stub or version constraint must be used.
- What happens when the original package is a Flutter-only package with platform channels? The rewrite must decide whether to keep platform-channel support or abstract it through Zuraffa's platform layer.

## Requirements

### Functional Requirements

- **FR-001**: The system MUST scaffold the `zuraffa_intents` GitHub repository under the `arrrrny` organization if it does not yet exist.
- **FR-002**: The system MUST rewrite all intent-related abstractions (intent classes, handlers, dispatchers) using Zuraffa entities, use cases, and data layers.
- **FR-003**: The system MUST maintain API compatibility with the prior published version, or document all breaking changes in a CHANGELOG with a migration guide.
- **FR-004**: The system MUST produce a comprehensive test suite (unit + integration) that covers all intent-related behaviors.
- **FR-005**: The system MUST publish the rewritten package to pub.dev under the `zuzu.dev` publisher.
- **FR-006**: The system MUST resolve inter-package dependencies — if `zuraffa_intents` depends on other ZikZak packages, those must be migrated or constrained to compatible versions before publishing.

### Key Entities

- **Intent**: A data object representing a user or system action. Key attributes: intent type identifier, payload data, source context, timestamp.
- **Intent Handler**: A use case that processes a specific intent type. Key attributes: supported intent type, input validation, processing logic, result type.
- **Intent Dispatcher**: The routing layer that maps incoming intents to the appropriate handler. Key attributes: handler registry, dispatch strategy, error handling.
- **Intent Channel**: The data-source abstraction for intent delivery (e.g., stream source, platform channel). Key attributes: channel name, intent encoding, connectivity.

## Success Criteria

### Measurable Outcomes

- **SC-001**: The rewritten `zuraffa_intents` package compiles, passes its full test suite, and is published to pub.dev under the zuzu.dev publisher.
- **SC-002**: 100% of the original public API surface is available in the rewritten package, or all differences are documented in a CHANGELOG with migration guidance.
- **SC-003**: Existing consumers can upgrade from the old package to the new package with zero or documented breaking changes.
- **SC-004**: The migrated package source demonstrates idiomatic Zuraffa architecture (entities, use cases, data sources, DI, tests).

## Assumptions

- The original `zuraffa_intents` package source code is accessible (either from an existing repository or archived sources) to serve as the reference for API compatibility.
- The package can be rewritten as a pure Dart library (no mandatory Flutter dependency) so it is usable from both Dart and Flutter contexts.
- Zuraffa v6 provides all necessary primitives (entities, use cases, data sources) to express the intent-handling patterns without requiring significant framework extensions.
- The `zuzu.dev` pub.dev publisher account is active and has publishing permissions for the `zuraffa_intents` package name.
