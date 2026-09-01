# Feature Specification: zuraffa_file_picker Migration to zuraffa

**Feature Branch**: `060-file-picker-migration`

**Created**: 2026-09-01

**Status**: Draft

**Input**: Migrate the `zuraffa_file_picker` Flutter package to be built on the zuraffa framework, per EPIC #214 migration plan (https://github.com/arrrrny/zuraffa/issues/674).

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

### User Story 1 - Pick a single file (Priority: P1)

A Flutter app developer integrates `zuraffa_file_picker` to let their end users select one file from the device filesystem and receive it as structured data within the app.

**Why this priority**: Single-file selection is the most fundamental and universally needed capability — all other workflows build on top of it.

**Independent Test**: Can be fully tested by invoking the single-file picker and verifying the returned file data contains path, name, size, and MIME type.

**Acceptance Scenarios**:

1. **Given** a mobile or web app using the zuraffa-based `zuraffa_file_picker`, **When** a user initiates single-file selection, **Then** the system-native file picker opens and returns a structured file entity with path, name, size, and MIME type.
2. **Given** a user cancels the file picker, **When** the user dismisses the native dialog, **Then** the picker returns null or an empty result without error.
3. **Given** a user selects a file, **When** the selection completes, **Then** the result conforms to the `FileEntity` contract defined by zuraffa (readable, testable, and persistable through the standard zuraffa data layer).

---

### User Story 2 - Pick multiple files (Priority: P2)

A Flutter app developer integrates `zuraffa_file_picker` to let their end users select multiple files at once and receive them as a list of structured file entities.

**Why this priority**: Multi-file selection is a common requirement for batch uploads, document management, and media gallery selection.

**Independent Test**: Can be fully tested by invoking the multi-file picker with a known file count and verifying the returned list contains the correct number of file entities.

**Acceptance Scenarios**:

1. **Given** a user has multi-file selection enabled, **When** the user selects N files and confirms, **Then** the system returns exactly N file entities matching the selected files.
2. **Given** a user has multi-file selection enabled and selects zero files before confirming, **Then** the system returns an empty list without error.

---

### User Story 3 - Filter files by type (Priority: P2)

A Flutter app developer can restrict the file types presented in the picker by specifying allowed MIME types or file extensions, improving the user experience by showing only relevant options.

**Why this priority**: Type filtering is essential for domain-specific use cases (e.g., image-only galleries, PDF document uploads) and prevents user errors.

**Independent Test**: Can be fully tested by invoking the picker with a type restriction (e.g., images only) and verifying that non-matching file types cannot be selected.

**Acceptance Scenarios**:

1. **Given** a developer configures the picker to accept only images, **When** a user opens the picker, **Then** non-image files are not selectable.
2. **Given** a developer provides a custom list of allowed extensions, **When** the picker opens, **Then** files outside that extension list are excluded from selection.

---

### User Story 4 - Platform permission handling (Priority: P2)

The file picker correctly handles platform-level permissions (e.g., storage access on Android, document picker access on iOS) and surfaces permission-related failures to the developer in a structured way.

**Why this priority**: Permission failures are common across platforms and must be communicated clearly so the app can handle them gracefully (e.g., request permission again, show a user-facing message).

**Independent Test**: Can be fully tested by simulating a permission-denied scenario and verifying the system returns a structured permission error entity rather than an unhandled exception.

**Acceptance Scenarios**:

1. **Given** a user has denied storage/file access permission, **When** the user attempts to open the file picker, **Then** the system returns a structured error entity with a permission-denied code rather than crashing or returning an opaque exception.
2. **Given** a permission is granted mid-session, **When** the user re-opens the picker, **Then** the picker functions normally.

---

### User Story 5 - Repository-backed data layer (Priority: P1)

The file picker integrates with zuraffa's repository pattern, allowing file selection results to be persisted, cached, and managed through the standard zuraffa data layer (datasources, repositories, use cases).

**Why this priority**: This is the core purpose of the migration — to bring the package under zuraffa's architecture so it participates in caching, offline-first, and DI capabilities.

**Independent Test**: Can be fully tested by injecting a mock datasource, selecting a file, and verifying the result flows through the repository to the caller.

**Acceptance Scenarios**:

1. **Given** the repository is registered in the zuraffa DI container, **When** a file is selected, **Then** the result is accessible via the repository interface rather than a standalone function call.
2. **Given** a cached result exists, **When** the repository is queried for a previously selected file, **Then** the cached entity is returned without re-opening the native picker.

---

### Edge Cases

- The device has no apps capable of handling the requested file type — picker returns empty or an appropriate "no handler" result.
- The selected file is deleted or inaccessible by the time the entity is processed — the data layer surfaces a not-found or inaccessible error.
- The user selects a file that is extremely large (exceeds a reasonable limit) — the picker or data layer reports a size-limit error.
- The picker is invoked while another picker dialog is already open — system handles gracefully without crash or race condition.
- Network-based file sources (e.g., cloud storage) are unavailable — offline error is returned through the repository.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The package MUST provide a `FileEntity` that conforms to zuraffa's entity conventions (id, fields, JSON serialization, copyWith).
- **FR-002**: The package MUST expose file selection through a `FilePickerRepository` interface registered in the zuraffa DI container.
- **FR-003**: The repository MUST support single-file and multi-file selection methods, both returning structured file entities.
- **FR-004**: The repository MUST support type filtering via MIME type or file extension allowlists.
- **FR-005**: The repository MUST return structured error entities for permission-denied, no-handler, size-exceeded, and file-not-found conditions.
- **FR-006**: The package MUST provide platform-specific datasources (mobile, web) that implement the native file-picking behavior.
- **FR-007**: The package MUST integrate with zuraffa's caching layer, allowing selected file metadata to be cached and retrieved offline.
- **FR-008**: The package MUST include a complete test suite using zuraffa's mock patterns, covering all acceptance scenarios.
- **FR-009**: The package MUST expose a `PickFileUseCase` and `PickFilesUseCase` (one per selection mode) as the primary use-case entry points.
- **FR-010**: The package MUST be structured as a standalone zuraffa plugin package, following the same conventions as other migrated packages under EPIC #214.

### Key Entities

- **FileEntity**: Represents a selected file with attributes: id (UUID), name, path (platform URI), size (bytes), mimeType, createdAt, modifiedAt.
- **FilePickerError**: Represents an error condition from the file picking process with codes: `permissionDenied`, `noHandler`, `sizeExceeded`, `fileNotFound`, `unknown`.
- **FileTypeFilter**: Value object encapsulating allowed MIME types and/or file extensions.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A Flutter developer can integrate `zuraffa_file_picker` and perform a single-file pick in under 10 lines of code using the provided use case.
- **SC-002**: All five acceptance scenario groups (single pick, multi pick, type filter, permission handling, repository integration) are covered by automated tests with 100% scenario coverage.
- **SC-003**: The `FilePickerRepository` is discoverable and injectable via the zuraffa DI container without custom registration.
- **SC-004**: File selection results survive app restart when caching is enabled (verified by unit test).
- **SC-005**: The package follows the same folder structure, naming conventions, and generation workflow as other packages migrated under EPIC #214.

## Assumptions

- The original `zuraffa_file_picker` codebase will be sourced from a `zuraffa_file_picker` directory within the monorepo or from a standalone GitHub repo at `https://github.com/arrrrny/zuraffa_file_picker` once it is scaffolded.
- The target platforms are Flutter mobile (iOS and Android) and web; desktop support is out of scope for this migration unless explicitly required.
- The package will use `file_picker` as the underlying native file-picking implementation.
- Zuraffa's entity generation (`zfa entity create`) and architecture generation (`zfa make`) are the primary tools for producing the new package structure, consistent with the v5 workflow.
- Permission handling will use platform plugins already present in the zuraffa ecosystem rather than new permission libraries.
