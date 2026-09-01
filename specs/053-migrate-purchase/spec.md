# Feature Specification: Migrate zuraffa_purchase to Zuraffa

**Feature Branch**: `658-migrate-purchase-package`

**Created**: 2026-09-01

**Status**: Draft

**Input**: GitHub issue #675 (https://github.com/arrrrny/zuraffa/issues/675)

## Overview

Migrate the `zuraffa_purchase` package to be built entirely on the Zuraffa framework, per the EPIC #214 migration plan. This is a sub-issue of the broader EPIC #214 — [v6] Migrate all ZikZak pub.dev packages to be built on zuraffa. The `zuraffa_purchase` repository does not yet exist on GitHub (GitHub 404) and has never been published to pub.dev (pub.dev 404), so the migration starts with scaffolding a new package and designing its purchase domain from scratch using Zuraffa's architecture.

## User Scenarios & Testing

### User Story 1 - Scaffold zuraffa_purchase Repository (Priority: P1)

As a ZikZak package maintainer, I want the `zuraffa_purchase` GitHub repository to exist and follow Zuraffa conventions so that I can begin the migration work and ensure the package is discoverable.

**Why this priority**: No migration can begin without a repository. Scaffolding is the prerequisite for every other goal in this spec. Without it, there is no codebase, no tests, and no package to publish.

**Independent Test**: Can be validated by verifying the repository exists at github.com/arrrrny/zuraffa_purchase, contains a valid `pubspec.yaml` with correct metadata (name, version, publisher, description), and the package can be resolved via `dart pub get`.

**Acceptance Scenarios**:

1. **Given** the package maintainer, **When** the GitHub repository is created under the arrrrny organization, **Then** it is public, has a standard Zuraffa project structure, and is initialized with a valid `pubspec.yaml` file.
2. **Given** the repository is scaffolded, **When** a developer runs `dart pub get` in the package root, **Then** all dependencies resolve without conflicts and the package is in a valid, compilable state.
3. **Given** the repository is scaffolded, **When** it is inspected, **Then** it includes a LICENSE, README.md, CHANGELOG.md, and `pubspec.yaml` with correct metadata (name: `zuraffa_purchase`, publisher: `zuzu.dev`).

---

### User Story 2 - Rewrite Package on Zuraffa Framework (Priority: P1)

As a ZikZak package maintainer, I want the `zuraffa_purchase` package codebase to be fully rewritten on the Zuraffa framework so that it inherits the framework's architecture, consistency, and maintainability guarantees.

**Why this priority**: The core value of EPIC #214 is that all packages share a common foundation. Rewriting on Zuraffa ensures `zuraffa_purchase` uses the same entity/repository/datasource/usecase layering, DI, and testing patterns as every other migrated package. This is the primary deliverable of the migration.

**Independent Test**: Can be validated by verifying the package compiles (`dart compile`), passes its full test suite (`dart test`), and its architecture follows Zuraffa's layer conventions (entities in `lib/src/domain/entities/`, datasources in `lib/src/data/`, usecases in `lib/src/domain/usecases/`, repositories in `lib/src/domain/repositories/`). Each layer can be tested independently.

**Acceptance Scenarios**:

1. **Given** the repository is scaffolded, **When** the package is rewritten on Zuraffa, **Then** all purchase-related business logic lives in Zuraffa-usecase classes, all data access lives in Zuraffa-datasource classes, and all domain models are Zuraffa entities.
2. **Given** the package uses Zuraffa's layered architecture, **When** `dart test` is run, **Then** the full test suite passes with meaningful coverage of entity, repository, datasource, and usecase layers.
3. **Given** the package follows Zuraffa conventions, **When** the codebase is reviewed, **Then** it uses Zuraffa's dependency-injection patterns, has no standalone Flutter code, and compiles as a pure Dart package (no `flutter:` dependencies except where strictly necessary).
4. **Given** other migrated packages exist (e.g., `zuraffa_cache`), **When** `zuraffa_purchase` is reviewed, **Then** it follows the same directory structure, naming conventions, and architectural patterns established by its sibling packages.

---

### User Story 3 - Publish to pub.dev and Ensure Ecosystem Compatibility (Priority: P1)

As a ZikZak package consumer, I want `zuraffa_purchase` to be published to pub.dev under the zuzu.dev publisher and be compatible with the rest of the Zuraffa ecosystem so that I can use it as a dependency in my Zuraffa-based applications.

**Why this priority**: A package that is not published provides no value to consumers. Publishing is the final step that makes the migration complete and accessible to all Zuraffa users. Ecosystem compatibility ensures consumers can combine `zuraffa_purchase` with other migrated packages without conflicts.

**Independent Test**: Can be validated by verifying the package is published and resolvable from pub.dev, an application that depends on `zuraffa_purchase` can run `dart pub get` without conflicts, and existing consumers of the package (once published) can upgrade without breaking changes or with a documented migration path.

**Acceptance Scenarios**:

1. **Given** the package is rewritten on Zuraffa, **When** `dart pub publish --dry-run` succeeds, **Then** the package is ready for publication.
2. **Given** the package is published to pub.dev under the zuzu.dev publisher, **When** a developer adds `zuraffa_purchase` as a dependency, **Then** `dart pub get` resolves it successfully and the package compiles.
3. **Given** the package is published, **When** it is used alongside other migrated Zuraffa packages in a consumer application, **Then** there are no dependency conflicts, version constraints are satisfied, and all packages compile together.
4. **Given** the migration introduces a breaking API change (if the package had a prior published version), **When** consumers upgrade, **Then** the breaking change is documented in CHANGELOG.md with a migration guide.

---

### User Story 4 - Design Purchase Domain Model (Priority: P2)

As a ZikZak package maintainer, I want the `zuraffa_purchase` domain to have a well-designed set of entities, use cases, and repository interfaces so that the package provides meaningful purchase-related functionality to consumers.

**Why this priority**: A Zuraffa package without a coherent domain model is not useful. The domain design determines what the package actually does for consumers. This is P2 because the scaffolding and rewrite (P1 stories) must come first, but the domain design shapes the package's value.

**Independent Test**: Can be validated by verifying the package exposes clear repository interfaces and use cases that cover the purchase domain, the entities are well-modeled with appropriate attributes, and the package's public API is documented.

**Acceptance Scenarios**:

1. **Given** the purchase domain is designed, **When** a consumer reads the package documentation, **Then** they can understand the available entities, use cases, and repository interfaces without reading the internal implementation.
2. **Given** the domain is modeled, **When** a consumer uses the package's use cases, **Then** the purchase functionality works correctly end-to-end with appropriate error handling.
3. **Given** the domain follows Zuraffa's entity conventions, **When** the entities are serialized to and from JSON, **Then** the serialization is consistent and handles edge cases (null values, empty lists, nested objects).

---

### Edge Cases

- What happens when the `zuraffa_purchase` package has dependencies on other ZikZak packages that are also being migrated under EPIC #214? The package must declare its dependencies flexibly (using `any` or broad version constraints) until sibling packages are published, or use pub.dev published versions as a temporary bridge.
- What happens when the purchase domain requires functionality not yet available in Zuraffa core? The migration must either wait for the required Zuraffa feature to be implemented, or implement the missing piece as part of this migration and contribute it back to the Zuraffa core.
- What happens when the scaffolded package structure diverges from other migrated packages? The `zuraffa_purchase` package must follow the same conventions (directory layout, naming, DI wiring) as other migrated packages to maintain ecosystem consistency.
- What happens when the package needs Flutter-specific functionality (e.g., platform channels for store integration)? The package must clearly separate pure-Dart business logic from platform-specific code, using Zuraffa's datasource abstraction to keep the usecase layer platform-independent.
- What happens when the package is published and then a bug is found in a core Zuraffa feature it depends on? The package must pin to a known-good Zuraffa version range and update atomically when core bugs are fixed.

## Requirements

### Functional Requirements

- **FR-001**: The system MUST create a GitHub repository at github.com/arrrrny/zuraffa_purchase with a valid `pubspec.yaml` (name: `zuraffa_purchase`, publisher: `zuzu.dev`) and standard Dart package structure.
- **FR-002**: The system MUST scaffold the package with Zuraffa's canonical directory layout: entities under `lib/src/domain/entities/`, repositories under `lib/src/domain/repositories/`, datasources under `lib/src/data/datasources/`, and use cases under `lib/src/domain/usecases/`.
- **FR-003**: The system MUST rewrite all package business logic using Zuraffa entities, Zuraffa repositories, Zuraffa datasources, and Zuraffa use cases — no standalone Flutter code at the domain or use-case layer.
- **FR-004**: The system MUST provide a coherent purchase domain model with at least one entity (e.g., `Purchase` or equivalent) and its corresponding repository interface, datasource, and use cases.
- **FR-005**: The system MUST pass the full test suite (`dart test`) with meaningful coverage of entity serialization, repository behavior, datasource I/O, and use-case outcomes.
- **FR-006**: The system MUST publish successfully to pub.dev under the zuzu.dev publisher with a valid `pubspec.yaml`, proper version number, and complete metadata.
- **FR-007**: The system MUST declare its dependencies on other ZikZak packages with version constraints that are compatible with the EPIC #214 migration plan (e.g., using `any` or broad ranges until stable versions are published).
- **FR-008**: The system MUST maintain API compatibility within a major version, or provide documented breaking changes in CHANGELOG.md with a migration path for existing consumers.
- **FR-009**: The system MUST follow the same architectural conventions, naming patterns, and DI wiring as other migrated packages in the Zuraffa ecosystem.

### Key Entities

- **Purchase**: The central domain entity representing a purchase transaction. Key attributes: purchase ID, purchaser identifier, purchased items/products, purchase amount, currency, purchase timestamp, purchase status (pending, completed, refunded, failed). Relationships: linked to a product or product list.
- **PurchaseRepository**: The repository interface defining purchase data access operations. Key operations: create purchase, get purchase by ID, list purchases for a user, update purchase status, issue refund.
- **PurchaseDatasource**: The datasource class handling purchase data persistence and retrieval. Key responsibilities: JSON serialization/deserialization, remote API calls, local caching.
- **PurchaseUseCase**: Zuraffa use-case classes encapsulating purchase business logic. Key use cases: CreatePurchase, GetPurchase, ListUserPurchases, RefundPurchase.

## Success Criteria

### Measurable Outcomes

- **SC-001**: The `zuraffa_purchase` GitHub repository exists at github.com/arrrrny/zuraffa_purchase, is public, and its `pubspec.yaml` is valid and resolvable within 1 week of this spec being approved.
- **SC-002**: The package compiles (`dart compile`) and its full test suite passes (`dart test`) with 100% pass rate on the first run after migration is complete.
- **SC-003**: The package is published to pub.dev under the zuzu.dev publisher within the planned migration timeline, and `dart pub add zuraffa_purchase` resolves successfully from a clean Dart project.
- **SC-004**: A consumer application that depends on `zuraffa_purchase` alongside other migrated Zuraffa packages (e.g., `zuraffa_cache`) builds and runs without dependency conflicts, version constraint errors, or compilation failures.
- **SC-005**: The package's API surface is documented (via README.md and dartdoc), stable across minor versions, and breaking changes are documented in CHANGELOG.md with clear migration guidance.

## Assumptions

- The Zuraffa framework v6 is stable and provides all necessary primitives (entity, repository, datasource, usecase, DI) to build a purchase package without requiring simultaneous framework changes.
- The purchase domain model (entities, use cases) can be designed from first principles based on what is needed for a ZikZak-style purchase flow, since there is no existing `zuraffa_purchase` codebase to preserve.
- Other migrated ZikZak packages under EPIC #214 will be published to pub.dev before or alongside `zuraffa_purchase`, and version constraints can be managed using pub.dev's semver ranges.
- The `zuraffa_purchase` package is intended for Flutter/Dart applications and may include platform-specific code for store integration (App Store, Play Store) where needed, but the core business logic remains in pure Dart.
- The package maintainer has the necessary permissions to create a GitHub repository under the arrrrny organization and publish to pub.dev under the zuzu.dev publisher.
- The migration follows the same structural patterns established by other migrated packages (e.g., `zuraffa_cache`, `zuraffa_network`) to ensure consistency across the ecosystem.
