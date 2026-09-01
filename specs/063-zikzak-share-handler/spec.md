# Feature Specification: Migrate zikzak_share_handler to zuraffa

**Feature Branch**: `063-zikzak-share-handler`

**Created**: 2026-09-01

**Status**: Draft

**Input**: GitHub issue #686 (https://github.com/arrrrny/zuraffa/issues/686) — "[v6] Migrate zikzak_share_handler to be built on zuraffa"

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

### User Story 1 - Share content from app via system share sheet (Priority: P1)

An app developer integrates `zikzak_share_handler` to let users share text, URLs, images, or files from within the app using the native operating system share sheet.

**Why this priority**: This is the core capability of the package — the primary reason any app developer depends on it.

**Independent Test**: Fully testable by calling the share API with a content payload and asserting the system share sheet opens with the correct content on the target platform.

**Acceptance Scenarios**:

1. **Given** a mobile app with `zikzak_share_handler` integrated, **When** a user triggers a share action with text content, **Then** the native OS share sheet opens displaying the text and any available share targets
2. **Given** a mobile app with `zikzak_share_handler` integrated, **When** a user triggers a share action with a URL, **Then** the native OS share sheet opens displaying the URL and any available share targets
3. **Given** a mobile app with `zikzak_share_handler` integrated, **When** a user triggers a share action with a file path, **Then** the native OS share sheet opens with the file attachment and any available share targets
4. **Given** a mobile app with `zikzak_share_handler` integrated, **When** a user triggers a share action but no shareable content is provided, **Then** an appropriate error is returned without crashing

---

### User Story 2 - Migrated package has no breaking API changes (Priority: P1)

An app developer currently using `zikzak_share_handler` can upgrade to the zuraffa-based version without modifying their existing code.

**Why this priority**: A breaking migration would defeat the purpose — the entire goal is to modernize the package without disrupting existing consumers.

**Independent Test**: Fully testable by running the existing consumer app's test suite against the migrated package and confirming all tests pass.

**Acceptance Scenarios**:

1. **Given** an existing app that calls `ShareHandler.share(...)` with a text payload, **When** the app is upgraded to use the zuraffa-based `zikzak_share_handler`, **Then** the share behavior remains identical and no code changes are required
2. **Given** an existing app that uses `ShareContent` and `ShareResult` types from `zikzak_share_handler`, **When** the app is upgraded to the zuraffa-based version, **Then** all type signatures and method signatures are unchanged

---

### User Story 3 - Package conforms to zuraffa framework architecture (Priority: P2)

The `zikzak_share_handler` package is rebuilt using zuraffa's entity, repository, and datasource patterns, so it participates in the framework's dependency injection, caching, and test infrastructure.

**Why this priority**: This is the architectural goal of the migration — alignment with the framework enables future enhancements (DI, caching, mocking) without further rewrites.

**Independent Test**: Fully testable by verifying the package exports zuraffa-compatible abstractions (entities, repositories) and can be instantiated through the framework's DI container.

**Acceptance Scenarios**:

1. **Given** a zuraffa-based application, **When** `zikzak_share_handler` is added as a dependency, **Then** the share handler can be resolved through the zuraffa DI container
2. **Given** a zuraffa-based application, **When** the share handler's repository is registered, **Then** it is discoverable via the standard zuraffa repository registry

---

### User Story 4 - Platform implementations covered by umbrella (Priority: P3)

The `zikzak_share_handler` package delegates platform-specific implementations (Android, iOS, web, macOS, Windows, Linux) to the existing `zikzak_inappwebview` package, avoiding duplicate platform channel code.

**Why this priority**: Platform channels are already handled by the umbrella package; this story ensures the migration reuses that infrastructure rather than duplicating it.

**Independent Test**: Fully testable by verifying that the migrated package has no new platform channel code and that the umbrella package's platform bindings are invoked for native share operations.

**Acceptance Scenarios**:

1. **Given** a native platform (Android/iOS/macOS/Windows/Linux), **When** a share action is triggered, **Then** the share operation is routed through `zikzak_inappwebview` platform bindings with no duplicate channel declarations
2. **Given** the web platform, **When** a share action is triggered, **Then** the web share API is invoked via the appropriate platform abstraction without duplicating web-specific code

---

### Edge Cases

- When the target platform does not support sharing (e.g., certain headless server environments), the system must return a clear error rather than crashing
- When sharing a file that does not exist or is inaccessible, the system must surface a user-facing error
- When the share sheet is dismissed without selecting a target, the system must indicate cancellation cleanly
- When sharing very large files, the system must handle the payload without memory issues on constrained devices

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The migrated package MUST provide a `ShareHandler` interface with a `share(ShareContent)` method that triggers the platform's native share sheet
- **FR-002**: The migrated package MUST support sharing text content (plain strings)
- **FR-003**: The migrated package MUST support sharing URL content with optional title
- **FR-004**: The migrated package MUST support sharing files via file path, exposing the file to the share sheet
- **FR-005**: The migrated package MUST return a `ShareResult` indicating success, cancellation, or failure with an error description
- **FR-006**: The migrated package MUST expose `ShareContent` as the primary data entity for all shareable content types
- **FR-007**: The migrated package MUST maintain full API backward compatibility with the pre-migration version — all public types and method signatures MUST remain unchanged
- **FR-008**: The migrated package's architecture MUST align with zuraffa's entity/repository/datasource pattern
- **FR-009**: The migrated package MUST have no duplicate platform channel declarations; platform implementations MUST delegate to `zikzak_inappwebview`
- **FR-010**: The migrated package's public API MUST be fully documented with dartdoc

### Key Entities *(include if feature involves data)*

- **ShareContent**: Represents the data to be shared. Attributes include content type (text, url, file), the payload (string or file path), and optional metadata (title, subject, mime type).
- **ShareResult**: Represents the outcome of a share operation. Attributes include status (success, cancelled, error) and an optional error message.
- **ShareHandler**: The primary interface exposed to consumers. Provides the `share(ShareContent)` method and can optionally support `canShare()` availability checking.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: All public APIs from the pre-migration version are present and have identical signatures — verified by running the existing consumer test suite without modification
- **SC-002**: The package publishes to pub.dev without errors (`dart pub publish --dry-run`)
- **SC-003**: The package compiles without errors on all supported platforms (Android, iOS, macOS, Windows, Linux, web)
- **SC-004**: The package integrates with zuraffa's dependency injection system — the share handler can be resolved from the container
- **SC-005**: Zero new platform channel code is introduced in the migrated package beyond what is already in `zikzak_inappwebview`

## Assumptions

- App developers have a stable internet connection during development
- The existing `zikzak_inappwebview` package provides the necessary platform bindings for native share operations on all target platforms
- No new share content types (beyond text, URL, and file) are required in scope for this migration
- The `pub.dev` package name `zikzak_share_handler` remains unchanged; this is a rewrite, not a new package
- Testing is done against the existing test suite for the package; no new feature tests are required beyond validating the migration
