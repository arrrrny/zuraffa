# Feature Specification: Migrate zuraffa_auth to be built on zuraffa

**Feature Branch**: `058-zuraffa-auth-migration`

**Created**: 2026-09-01

**Status**: Draft

**Input**: GitHub issue #670 — [v6] Migrate zuraffa_auth to be built on zuraffa. Parent of EPIC #214 (https://github.com/arrrrny/zuraffa/issues/670).

## User Scenarios & Testing *(mandatory)*

<!--
  IMPORTANT: User stories should be PRIORITIZED as user journeys ordered by importance.
  Each user story/journey must be INDEPENDENTLY TESTABLE - meaning if you implement just ONE of them,
  you should still have a viable MVP (Minimum Viable Product) that delivers value.

  Assign priorities (P1, P2, P3, etc.) to each story, where P1 is the most critical.
  Think of each story as a standalone slice of functionality that can be:
  - Developed independently
  - Tested independently
  - Deployed independently
  - Demonstrated to users independently
-->

### User Story 1 - Scaffold zuraffa_auth GitHub repository (Priority: P1)

A developer onboarding a new zuraffa_auth package creates a clean GitHub repository with the correct structure, license, and pubspec, as a prerequisite for the full migration.

**Why this priority**: The repo does not yet exist (GitHub 404). Without a valid repository, no migration work can begin. This is a hard dependency.

**Independent Test**: Can be verified by cloning the repository and confirming it contains a valid Dart package structure with a valid pubspec.yaml.

**Acceptance Scenarios**:

1. **Given** the developer has GitHub access, **When** the scaffolding step completes, **Then** a public GitHub repository exists at `github.com/arrrrny/zuraffa_auth` containing a valid Dart package with a proper pubspec.yaml, README, and LICENSE.
2. **Given** the scaffolding step completes, **When** `dart pub get` is run on the repository, **Then** all dependencies resolve without errors.

---

### User Story 2 - Migrate zuraffa_auth to zuraffa framework (Priority: P1)

A developer replaces the standalone Flutter authentication code in `zuraffa_auth` with an implementation fully built on the zuraffa framework — using zuraffa's entity, repository, datasource, and use case layers rather than hand-rolled or third-party alternatives.

**Why this priority**: This is the core goal of the issue. The package must become a first-class zuraffa citizen before it can be published and used by applications built on the framework.

**Independent Test**: Can be verified by checking that the package's source files import only `package:zuraffa` and its generated layers, and that `dart analyze` reports no errors.

**Acceptance Scenarios**:

1. **Given** the scaffolded repository, **When** the codebase is rewritten, **Then** all public-facing authentication types (e.g., user identity, session, tokens) are expressed as zuraffa entities.
2. **Given** the rewritten codebase, **When** `dart analyze` runs on the entire package, **Then** no errors or warnings are produced.
3. **Given** the rewritten codebase, **When** `dart test` runs, **Then** all tests pass.
4. **Given** the migrated codebase, **When** the package is added as a dependency to a host zuraffa application, **Then** the application's `zfa build` completes without errors.

---

### User Story 3 - Publish migrated zuraffa_auth to pub.dev (Priority: P2)

A developer publishes the migrated package so it is discoverable and installable by the broader zuraffa community.

**Why this priority**: Publishing makes the package available for consumption. Without publication the migration has no external value.

**Independent Test**: Can be verified by visiting the package's pub.dev page and confirming it is listed and installable.

**Acceptance Scenarios**:

1. **Given** all tests pass and `dart pub publish --dry-run` succeeds, **When** `dart pub publish` is executed, **Then** the package appears on pub.dev with the correct version and description.

---

### User Story 4 - Update EPIC #214 tracking (Priority: P3)

A maintainer updates the parent EPIC issue #214 to mark `zuraffa_auth` migration as complete.

**Why this priority**: Ensures accurate project tracking and visibility into overall migration progress.

**Independent Test**: Can be verified by inspecting EPIC #214 on GitHub and confirming `zuraffa_auth` is listed under completed sub-issues.

**Acceptance Scenarios**:

1. **Given** the package is published, **When** the maintainer closes issue #670, **Then** EPIC #214 reflects the completion of this sub-issue.

---

### Edge Cases

- The GitHub repository name `zuraffa_auth` conflicts with an existing archived or private repo — a new unique name must be chosen and the migration plan updated accordingly.
- The existing `zuraffa_auth` code contains breaking changes relative to the current zuraffa version — the migration must pin compatible zuraffa and Dart SDK versions.
- The package depends on a third-party auth library that has no zuraffa-compatible equivalent — an adapter or replacement must be found before migration can proceed.

## Requirements *(mandatory)*

<!--
  ACTION REQUIRED: The content in this section represents placeholders.
  Fill them out with the right functional requirements.
-->

### Functional Requirements

- **FR-001**: The `zuraffa_auth` GitHub repository must be created at `github.com/arrrrny/zuraffa_auth` with a valid Dart package structure.
- **FR-002**: All authentication domain types (user identity, session, tokens, credentials) MUST be expressed as zuraffa entities under `lib/src/domain/entities/`.
- **FR-003**: Authentication operations (sign in, sign out, token refresh, session validation) MUST be expressed as zuraffa use cases.
- **FR-004**: Data access for authentication entities MUST be mediated by zuraffa repositories and datasources.
- **FR-005**: The migrated package MUST compile with `dart analyze` producing zero errors and zero warnings.
- **FR-006**: The migrated package MUST have test coverage for all use cases, achieving a minimum of 80% line coverage.
- **FR-007**: The package MUST be published to pub.dev under the name `zuraffa_auth`.
- **FR-008**: The package MUST declare `zuraffa` as a dependency and import only `package:zuraffa` for framework types.
- **FR-009**: The package's public API MUST be stable — all public classes and methods intended for external use MUST be annotated appropriately and documented.

### Key Entities *(include if feature involves data)*

- **AuthUser**: Represents an authenticated user identity. Contains attributes such as user identifier, email, display name, and roles.
- **AuthSession**: Represents an active user session. Contains session identifier, user reference, creation timestamp, and expiration timestamp.
- **AuthToken**: Represents credential tokens (access token, refresh token). Contains token value, type, and expiration metadata.
- **AuthCredentials**: Represents sign-in credentials (e.g., email/password, API key). Not persisted long-term; used as input to the sign-in use case.

## Success Criteria *(mandatory)*

<!--
  ACTION REQUIRED: Define measurable success criteria.
  These must be technology-agnostic and measurable.
-->

### Measurable Outcomes

- **SC-001**: A `zuraffa_auth` package is listed on pub.dev with version 1.0.0 or higher within 30 days of starting this migration.
- **SC-002**: All public-facing authentication use cases pass their unit tests with 100% pass rate.
- **SC-003**: The migrated package builds and analyzes cleanly in a clean Dart environment with zero errors and zero warnings.
- **SC-004**: The migrated package integrates into a host zuraffa application without requiring any workarounds or patched imports.
- **SC-005**: Issue #670 on GitHub is closed, linked to the published package version.

## Assumptions

<!--
  ACTION REQUIRED: The content in this section represents placeholders.
  Fill them out with the right assumptions based on reasonable defaults
  chosen when the feature description did not specify certain details.
-->

- The existing `zuraffa_auth` package source (or intent) is available at `github.com/arrrrny/zuraffa_auth` or can be inferred from the issue context; if no prior source exists, the package will be scaffolded from scratch using zuraffa conventions.
- The migration targets the current stable major version of zuraffa (v5/v6 as applicable at migration time).
- Dart SDK version compatibility will follow the zuraffa framework's stated SDK constraints.
- The pub.dev package name `zuraffa_auth` is available and will be claimed at publish time.
- Authentication method defaults to session-based authentication with token refresh; OAuth2/OIDC integration is a future enhancement outside the scope of this migration unless explicitly defined in the parent EPIC.
