# Feature Specification: Migrate zuraffa_browser to Zuraffa

**Feature Branch**: `056-v6-zuraffa-browser-migration`

**Created**: 2026-09-01

**Status**: Draft

**Input**: GitHub issue #669 (https://github.com/arrrrny/zuraffa/issues/669)

## User Scenarios & Testing

### User Story 1 - Rewrite zuraffa_browser Architecture on Zuraffa (Priority: P1)

As a ZikZak package consumer, I want `zuraffa_browser` to be rewritten on the Zuraffa v6 framework so that it uses the same architecture as other ZikZak packages (entities, repositories, datasources, use cases) for consistent APIs, shared tooling, and long-term maintainability.

**Why this priority**: This is the core goal of the migration. The package must be fully rewritten to adopt Zuraffa's patterns before it can share infrastructure (DI, testing, caching, code generation) with other migrated packages.

**Independent Test**: Can be validated by verifying the rewritten package compiles, passes its full test suite, and publishes to pub.dev under the zuzu.dev publisher. The package's public API surface should be API-compatible with the pre-migration version.

**Acceptance Scenarios**:

1. **Given** the zuraffa_browser source code has been migrated, **When** a developer runs `dart pub get` on the package, **Then** all dependencies resolve without conflicts and the package compiles.
2. **Given** the migrated package is published, **When** an existing consumer upgrades their dependency, **Then** the upgrade is non-breaking or provides a clear migration path documented in a CHANGELOG.
3. **Given** the migrated package's tests are run, **When** the full suite executes, **Then** all tests pass on all supported platforms (macOS, iOS).
4. **Given** the migrated package uses Zuraffa's architecture, **When** the source is inspected, **Then** it follows the Zuraffa entity/repository/usecase pattern consistently across all public-facing classes.

---

### User Story 2 - Preserve All Existing Public API Capabilities (Priority: P1)

As an existing user of zuraffa_browser, I want all of the package's existing capabilities to be preserved after the migration so that my existing code using `Browser`, `Page`, `ElementHandle`, `Keyboard`, `Selector`, `ProfileManager`, `launch`, `evaluate`, `click`, `type`, `screenshot`, `waitForSelector`, and session portability (PR #256) continues to work without changes.

**Why this priority**: API compatibility is the primary non-functional requirement. Breaking existing users' code would defeat the purpose of the migration.

**Independent Test**: Can be validated by running the package's existing test suite against the migrated code with no test modifications, and by checking that all public API symbols present in the original package are present in the migrated version.

**Acceptance Scenarios**:

1. **Given** the pre-migration test suite is run against the migrated package, **When** tests execute, **Then** all protocol-level tests (page commands, evaluate codec, selector) pass.
2. **Given** the pre-migration integration tests are run against the migrated package, **When** end-to-end flows execute on macOS, **Then** headed and headless launch, navigation, evaluation, screenshot, and session portability work correctly.
3. **Given** the pre-migration iOS tests are run against the migrated package, **When** flows execute on iOS 17+, **Then** all iOS-specific behaviors (headless WebView, persistent stores, keyboard dispatch) behave identically to the pre-migration version.
4. **Given** all public API symbols are catalogued from the pre-migration package, **When** the migrated package is analyzed, **Then** every symbol is present and has the same signatures.

---

### User Story 3 - Adopt Zuraffa Code Generation and Testing Infrastructure (Priority: P2)

As a Zuraffa maintainer, I want zuraffa_browser to integrate with Zuraffa's code generation (`zfa build`), testing utilities, and the mock/data-layer infrastructure so that it can be maintained using the same tooling as other Zuraffa packages.

**Why this priority**: The migration is not complete until the package can be maintained using Zuraffa's standard workflow. This enables consistent CI, code generation, and testing across the ecosystem.

**Independent Test**: Can be validated by running `zfa make` and `zfa build` on the migrated package and verifying generated code is correct and the package still compiles and tests pass.

**Acceptance Scenarios**:

1. **Given** the migrated package is generated using `zfa make`, **When** the generated files are produced, **Then** they follow Zuraffa's naming and structure conventions.
2. **Given** `zfa build` is run on the migrated package, **When** the code generator executes, **Then** all generated files are valid Dart code that compiles without errors.
3. **Given** the migrated package includes Zuraffa test fixtures, **When** `dart test` runs, **Then** tests use Zuraffa's mock infrastructure and produce consistent, repeatable results.
4. **Given** the migrated package follows Zuraffa's architecture, **When** it is added as a dependency in another Zuraffa package, **Then** dependency injection and mocking work without custom configuration.

---

### Edge Cases

- What happens when the existing zuraffa_browser test suite cannot be run unchanged against the migrated code due to import restructuring? The test suite may need updating, but all original test cases must remain covered — no test case deletion without replacement.
- What happens when the migration reveals that some existing code relies on internal (underscore-prefixed) implementation details? Internal APIs may be refactored, but any behavior relied on by consumers (even informally) must be preserved or documented as a breaking change.
- What happens when a circular dependency is introduced between zuraffa_browser and other Zuraffa packages during migration? The dependency graph must be resolved by keeping zuraffa_browser as a leaf dependency (depending on zuraffa_core but not depending on other migrated packages that depend on it).
- What happens when the package's platform-specific (macOS/iOS) native code requires changes to work with Zuraffa's plugin system? Native code changes must be minimal and confined to integration points; the WebView driver logic should remain platform-native.
- What happens if the GitHub repo for zuraffa_browser does not yet have the full source available at migration time? The migration plan must be created from the current state of the repo, and any gaps must be documented as pre-migration tasks.

## Requirements

### Functional Requirements

- **FR-001**: The migrated `zuraffa_browser` package MUST compile without errors using `dart pub get` and `dart compile`.
- **FR-002**: The migrated package MUST pass its complete test suite (unit, protocol, integration) on macOS and iOS 17+.
- **FR-003**: The migrated package MUST maintain API compatibility with the pre-migration public surface, preserving all public classes, methods, and properties of `Browser`, `Page`, `ElementHandle`, `Keyboard`, `Selector`, `ProfileManager`, `ProfileStore`, and `ProfileWebViewHost`.
- **FR-004**: The migrated package MUST follow Zuraffa v6 architecture conventions: entities, repositories, datasources, and use cases as appropriate for each public-facing class.
- **FR-005**: The migrated package MUST be published to pub.dev under the zuzu.dev publisher at the same or higher version than the current release, with a CHANGELOG entry documenting the v6 Zuraffa migration.
- **FR-006**: The migrated package MUST support session portability (detach/reattach cookies and localStorage to a portable session) as documented in PR #256, with behavior identical to the pre-migration implementation.
- **FR-007**: The migrated package MUST support headless and headed modes on macOS, and headed + headless on iOS 17+ per the feature spec 006 (puppeteer-webview-api).
- **FR-008**: The migrated package MUST integrate with Zuraffa's code generation pipeline so that `zfa make` and `zfa build` work correctly on the package.

### Key Entities

- **Browser**: The top-level browser instance. Key attributes: platform host detection, profile management, session management, lifecycle (launch, close). Mapped from the existing `Browser` class in `lib/src/puppeteer/browser.dart`.
- **Page**: An active web page within a browser. Key attributes: URL, title, cookies, localStorage, navigation, evaluation, screenshot. Mapped from `lib/src/puppeteer/page.dart`.
- **ElementHandle**: A reference to a DOM element on a page. Key attributes: bounding box, click, type, hover. Mapped from `lib/src/puppeteer/element_handle.dart`.
- **Selector**: A CSS or XPath selector for element lookup. Key attributes: selector string, type (CSS/XPath). Mapped from `lib/src/protocol/selector.dart`.
- **Profile**: A named browser profile with persisted data directory. Key attributes: profile ID, user data directory, enabled flag. Mapped from `lib/src/profile_manager.dart` and `lib/src/profile_store.dart`.
- **ProfileStore**: The persisted store for profile metadata. Key attributes: list of profiles, active profile. Part of `lib/src/profile_store.dart`.
- **ProfileWebViewHost**: The platform host for WebView-based browsing per platform. Key attributes: platform detection, WebView host type. Mapped from `lib/src/profile_webview_host.dart`.

## Success Criteria

### Measurable Outcomes

- **SC-001**: The migrated package compiles without errors and its full test suite passes on macOS and iOS within 30 minutes of running `dart test`.
- **SC-002**: All pre-migration public API symbols are present in the migrated package with matching signatures, verified by static analysis.
- **SC-003**: The migrated package publishes successfully to pub.dev under the zuzu.dev publisher within the planned timeline.
- **SC-004**: `zfa make` and `zfa build` run without errors on the migrated package, and the generated code compiles.
- **SC-005**: Session portability (detach/attach session) works identically on the migrated package as verified by the existing integration test for PR #256.

## Assumptions

- The source of `zuraffa_browser` at `https://github.com/arrrrny/zuraffa_browser` is accessible and the current `master` branch represents the latest pre-migration state to migrate from.
- The pub.dev package `zuraffa_browser` has not yet been published (pub.dev: 404), so the initial publish is also part of this migration.
- Zuraffa v6 is stable and the framework APIs used by the migrated package will not change during the migration.
- The WebView driver implementation (macOS `WebViewHost`, iOS `WKWebView`) is platform-native code that does not need to be rewritten; only the Dart wrapper layer needs to be refactored to Zuraffa's architecture.
- The existing test suite covers the protocol layer (pure Dart), the puppeteer layer (platform-independent Dart), and integration tests (macOS/iOS specific). All three layers must continue to pass after migration.
- The migration should not introduce new native dependencies beyond what the current package already uses.
