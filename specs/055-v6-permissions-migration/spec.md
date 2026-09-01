# Feature Specification: Migrate `zuraffa_permissions` to Zuraffa

**Feature Branch**: `055-v6-permissions-migration`

**Created**: 2026-09-01

**Status**: Draft

**Input**: GitHub issue [#668](https://github.com/arrrrny/zuraffa/issues/668) — "[v6] Migrate zuraffa_permissions to be built on zuraffa". Closes part of EPIC [#214](https://github.com/arrrrny/zuraffa/issues/214) — "[v6] Migrate all ZikZak pub.dev packages to be built on zuraffa".

## Overview

`zuraffa_permissions` is a ZikZak package that provides a permissions and role-based access control (RBAC) layer for Flutter applications. The package currently exists as standalone Flutter code. This feature migrates it to be built on the Zuraffa framework, bringing it into the unified zuraffa ecosystem so it shares infrastructure, follows consistent patterns, and can be maintained alongside other ZikZak packages.

The package repo does not yet exist on GitHub (GitHub 404). The first step is to scaffold the repository before the migration can begin.

## User Scenarios & Testing

### User Story 1 — Consume Permissions via Zuraffa (Priority: P1)

As a Flutter developer, I want to use `zuraffa_permissions` as a zuraffa-native package so that I can declare permissions and roles using Zuraffa's entity, repository, and use-case patterns, and integrate them with the rest of my Zuraffa-powered application.

**Independent Test**: Can be validated by installing the migrated package in a Zuraffa application, using its entities and use cases, and confirming that permission checks behave correctly. The migrated package must be importable and usable without any standalone-Flutter-only code paths.

**Acceptance Scenarios**:

1. **Given** the `zuraffa_permissions` package has been migrated to zuraffa, **When** a developer adds it as a dependency to a Zuraffa application, **Then** the package compiles without errors and all public exports are available.
2. **Given** a permission entity has been declared, **When** a developer creates or retrieves it through the Zuraffa repository, **Then** the operation completes without errors and the entity is persisted.
3. **Given** the package is migrated, **When** a developer runs `dart pub publish --dry-run` on the package, **Then** the publisher reports no issues and the package is ready to publish.

---

### User Story 2 — Scaffold Missing Repository (Priority: P1)

As a maintainer, I want the `zuraffa_permissions` GitHub repository to exist before I begin the migration work so that I can push code and track progress.

**Independent Test**: Can be validated by confirming that https://github.com/arrrrny/zuraffa_permissions returns HTTP 200 (not 404).

**Acceptance Scenarios**:

1. **Given** the `zuraffa_permissions` repo does not exist, **When** the scaffolding step is executed, **Then** the repo is created under the `arrrrny` GitHub organization and a minimal initial commit is present.
2. **Given** the repo has been scaffolded, **When** a developer clones it, **Then** the project is a valid Dart/Flutter package with a working `dart pub get`.

---

### User Story 3 — Migrate Core Permission Logic to Zuraffa (Priority: P1)

As a maintainer, I want the core permission and role management logic to be implemented using Zuraffa's entity, datasource, repository, and use-case layers so that the package is consistent with the Zuraffa architecture.

**Independent Test**: Can be validated by reviewing the source code and confirming that all domain logic is accessible through Zuraffa use cases rather than static utility classes or Flutter-specific widgets.

**Acceptance Scenarios**:

1. **Given** the migration is complete, **When** the package source is reviewed, **Then** permission and role entities follow the Zuraffa entity conventions (id field, JSON serialization, equality).
2. **Given** the migration is complete, **When** the package source is reviewed, **Then** all data access goes through Zuraffa repositories and datasources, not direct database or storage calls.
3. **Given** the migration is complete, **When** the package source is reviewed, **Then** all business operations are exposed as Zuraffa use cases.
4. **Given** the migration is complete, **When** the package source is reviewed, **Then** there are no direct `dart:io` or `dart:html` imports outside of a datasource layer.

---

### User Story 4 — Publish Migrated Package (Priority: P2)

As a maintainer, I want the migrated `zuraffa_permissions` package to be published on pub.dev under the `zuzu.dev` publisher so that existing consumers can upgrade.

**Independent Test**: Can be validated by checking pub.dev for the `zuraffa_permissions` package and confirming the latest version is published from the migrated repository.

**Acceptance Scenarios**:

1. **Given** the migration is complete and all tests pass, **When** the maintainer runs the publish workflow, **Then** the package is published to pub.dev under the `zuzu.dev` publisher with a version bump.
2. **Given** the migrated package is published, **When** an existing consumer upgrades their dependency, **Then** the upgrade is non-breaking or includes a migration guide in the changelog.

## Functional Requirements

- FR-001: The `zuraffa_permissions` GitHub repository is created at `arrrrny/zuraffa_permissions` with a valid Dart package structure.
- FR-002: All permission and role types are modeled as Zuraffa entities with unique identifiers.
- FR-003: All persistence operations for permissions and roles are implemented through Zuraffa datasources and repositories.
- FR-004: All business logic for permission checks, role assignment, and access control is exposed through Zuraffa use cases.
- FR-005: The package compiles without errors and its public API is fully accessible from a host Zuraffa application.
- FR-006: The migrated package is published to pub.dev under the `zuzu.dev` publisher.
- FR-007: Existing consumers can upgrade to the migrated version without breaking changes, or a migration guide is provided.

## Success Criteria

- SC-001: The `zuraffa_permissions` GitHub repo returns HTTP 200 and contains a valid Dart/Flutter package. *(Measurable: HTTP 200 vs 404)*
- SC-002: The migrated package compiles in a Zuraffa host application with zero errors. *(Measurable: `dart analyze` passes with no errors)*
- SC-003: All permission and role operations are accessible through Zuraffa use cases, not static methods or widget-level code. *(Measurable: code review verification — no direct permission logic outside usecase files)*
- SC-004: The migrated package is published on pub.dev with a version greater than any prior standalone version. *(Measurable: pub.dev version number)*
- SC-005: Existing consumer code that depends on the public API of the previous standalone package continues to work after migration. *(Measurable: consumer test suite passes)*

## Key Entities

- **Permission**: Represents a single permission (e.g., `users.read`, `orders.write`). Has an id, a name/code, and optional metadata.
- **Role**: Represents a role (e.g., `admin`, `editor`). Has an id, a name, and a set of associated permissions.
- **UserPermission**: Maps a user id to a permission id (direct permission grant).
- **UserRole**: Maps a user id to a role id (role assignment).
- **RolePermission**: Maps a role id to a permission id (role definition).

*[NEEDS CLARIFICATION: specific permission model]*: The current standalone implementation is not accessible (GitHub 404). Should the migrated package preserve the existing API surface (if known from pub.dev documentation) or redesign the permission model entirely? The recommendation is to preserve the existing API surface if there are known consumers, otherwise redesign with Zuraffa patterns. The spec assumes preservation of the existing public API.

## Assumptions

- The existing standalone `zuraffa_permissions` package had a documented public API that is known from pub.dev or prior work. If no prior API is known, the migration team will design a new API surface consistent with Zuraffa patterns.
- The package is used by other ZikZak packages or applications; breaking changes require a migration guide.
- The `zuzu.dev` publisher on pub.dev is available and the maintainer has credentials.
- The migration follows the same pattern as other packages migrated under EPIC #214.
