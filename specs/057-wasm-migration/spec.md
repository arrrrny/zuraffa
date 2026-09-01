# Feature Specification: Migrate zuraffa_wasm to zuraffa

**Feature Branch**: `057-wasm-migration`

**Created**: 2026-09-01

**Status**: Draft

**Input**: GitHub issue #677 — https://github.com/arrrrny/zuraffa/issues/677

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Scaffold new zuraffa_wasm repository (Priority: P1)

A maintainer needs a fresh `zuraffa_wasm` GitHub repository with the correct package structure so that the migration can begin.

**Why this priority**: The package repo does not yet exist (GitHub 404). No further work is possible until the scaffolding is in place.

**Independent Test**: Can be verified by cloning the newly created repo and confirming it contains a minimal valid Dart/WASM package with the correct metadata.

**Acceptance Scenarios**:

1. **Given** the maintainer has GitHub access, **When** the scaffolding step is executed, **Then** a new public GitHub repository `arrrrny/zuraffa_wasm` exists with a valid `pubspec.yaml`, `README.md`, and Dart project structure.
2. **Given** the new repository exists, **When** `dart pub get` is run locally, **Then** all dependencies resolve without errors.

---

### User Story 2 - Rewrite package on zuraffa framework (Priority: P1)

The `zuraffa_wasm` package is rewritten to use the zuraffa framework (entities, datasources, repositories, use cases) rather than standalone Flutter code, making it a first-class zuraffa extension.

**Why this priority**: This is the core goal of the migration — bringing the package into the zuraffa ecosystem with proper layered architecture.

**Independent Test**: Can be verified by running the generated code through `dart analyze` and confirming all generated files compile cleanly against the zuraffa core library.

**Acceptance Scenarios**:

1. **Given** the repository is scaffolded, **When** the zuraffa migration generation is applied, **Then** the package contains entities, datasources, repositories, and use cases built on top of the zuraffa framework.
2. **Given** the rewrite is complete, **When** the WASM target is built, **Then** the resulting WASM artifact compiles and exports the expected public API surface.
3. **Given** the rewrite is complete, **When** `dart analyze` is run on the package, **Then** zero analysis errors are reported.

---

### User Story 3 - Publish migrated package (Priority: P2)

The migrated `zuraffa_wasm` package is published to pub.dev so it is consumable by downstream projects.

**Why this priority**: A migrated package that is not published does not serve the broader ecosystem.

**Independent Test**: Can be verified by checking the pub.dev page for `zuraffa_wasm` and confirming the latest version is listed and installable.

**Acceptance Scenarios**:

1. **Given** the rewrite is complete and all tests pass, **When** the maintainer publishes to pub.dev, **Then** the package appears on pub.dev with correct metadata and version number.
2. **Given** the package is published, **When** a downstream project adds `zuraffa_wasm` as a dependency, **Then** the dependency resolves and the package compiles in the downstream context.

---

### User Story 4 - Integration with EPIC #214 tracking (Priority: P3)

Issue #677 is closed and linked back to the parent EPIC #214, providing visibility into the migration's completion status.

**Why this priority**: Closure and linkage are housekeeping items that ensure accurate project tracking.

**Independent Test**: Can be verified by visiting issue #677 on GitHub and confirming it is closed and references EPIC #214.

**Acceptance Scenarios**:

1. **Given** the migration is complete and published, **When** the maintainer closes issue #677, **Then** the issue is marked closed with a link to the relevant commit or PR.

---

### Edge Cases

- What happens if the zuraffa framework version used for migration conflicts with a dependency of the WASM target? The migration must pin a compatible zuraffa version.
- How does the system handle the absence of a WASM SDK in the local environment during scaffolding? The scaffolding should produce a package that is valid without requiring a local WASM SDK, deferring WASM-specific build steps to CI.
- What if a subsequent zuraffa core version changes the generated API surface? The migration should pin the zuraffa version used and document the expected compatibility window.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The `zuraffa_wasm` GitHub repository MUST be created with a valid Dart package structure (pubspec.yaml, lib/, test/).
- **FR-002**: The package MUST depend on the zuraffa core library as its foundation.
- **FR-003**: The package MUST expose a public API surface that was previously provided by the standalone WASM utility code.
- **FR-004**: The WASM target MUST compile to a valid WASM binary when built in CI.
- **FR-005**: The package MUST pass `dart analyze` with zero errors and zero warnings.
- **FR-006**: The package MUST be publishable to pub.dev and consumable as a dependency by downstream projects.
- **FR-007**: Issue #677 MUST be closed with a reference to the migration commit or PR.
- **FR-008**: The migration MUST be performed entirely through zuraffa commands (`zfa entity create`, `zfa make`, `zfa build`) per the v5 canonical workflow.

### Key Entities

- **WasmModule**: Represents a compilable WASM module artifact, including its target architecture and export surface.
- **ZuraffaWasmPackage**: The package itself as a Zuraffa-native package, with entities and use cases defining its public contract.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The `zuraffa_wasm` repo is created and public on GitHub within the first sprint of this migration.
- **SC-002**: `dart analyze` runs with zero errors and zero warnings in CI.
- **SC-003**: The WASM binary is successfully produced by CI on every merge to the default branch.
- **SC-004**: The package is published on pub.dev and reachable via `dart pub add zuraffa_wasm`.
- **SC-005**: Issue #677 is closed within 7 days of the first successful pub.dev release.
- **SC-006**: The migration is executed entirely through zuraffa commands, with no hand-written architecture code.

## Assumptions

- **Users have a WASM-capable CI environment**: The project assumes GitHub Actions or equivalent CI can produce WASM binaries; local WASM SDK availability is not required for development.
- **zuraffa core v6 is stable**: The migration uses a pinned version of zuraffa core to avoid unexpected API surface changes during the migration window.
- **Downstream consumers use Dart 3 or later**: WASM support in Dart requires Dart 3.x; the package targets Dart 3 minimum.
- **No legacy data migration is required**: This is a greenfield rewrite on the zuraffa framework, not a data migration; no legacy data schemas need to be preserved.
