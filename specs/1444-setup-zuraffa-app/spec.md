# Feature Specification: Setup generates ZuraffaApp as root widget

**Template Version**: `zuraffa-1.0`

**Feature Branch**: `1444-setup-zuraffa-app`

**Created**: 2026-09-10

**Status**: Draft

**Input**: User description: "when a flutter app is generated with zfa setup it should create the Zuraffa app as the root widget"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Flutter app uses ZuraffaApp by default (Priority: P1)

When a developer runs `zfa setup <AppName>` for a Flutter project, the generated `lib/main.dart` should use `ZuraffaApp` as the root widget with standard configuration (title, theme, debug banner disabled, navigator key), rather than the current `MaterialApp.router` pattern. The app should be runnable immediately after `zfa setup` without additional shell commands.

**Why this priority**: This is the core ask — the default scaffolding should produce a production-ready app shell using the certified ZuraffaApp, not a bare MaterialApp. It eliminates a manual step (`zfa app shell --zuraffa-app`) and aligns the default experience with the skin lane's certified shell.

**Independent Test**: Can be fully tested by running `zfa setup my_app` for a Flutter project and verifying that `lib/main.dart` imports and renders `ZuraffaApp` as the root widget. The generated app should compile and display a basic screen.

**Acceptance Scenarios**:

1. **Given** a developer runs `zfa setup my_app` for a Flutter project, **When** the setup completes, **Then** `lib/main.dart` contains `runApp(ZuraffaApp(...))` with a title, theme, `debugShowCheckedModeBanner: false`, and a `GlobalKey<NavigatorState>`
   **Type**: widget
2. **Given** a developer runs `zfa setup my_app --dart` for a pure Dart project, **When** the setup completes, **Then** no app shell is generated (pure Dart projects have no Flutter widgets)
   **Type**: acceptance
3. **Given** a developer runs `zfa setup my_app` and the generated `main.dart` uses `ZuraffaApp`, **When** they run `flutter run`, **Then** the app compiles and launches without errors
   **Type**: widget

---

### User Story 2 - Existing apps can upgrade to ZuraffaApp (Priority: P2)

When a developer runs `zfa app shell --zuraffa-app` on an existing project that has a `MaterialApp.router` shell, the generated `my_app.dart` should be upgraded to use `ZuraffaApp`. This preserves the existing `--zuraffa-app` flag behavior for projects that were scaffolded before this change.

**Why this priority**: Projects created before this change need a migration path. The `--zuraffa-app` flag already exists and works — this story ensures it remains functional and that the upgrade path is tested.

**Independent Test**: Create a project with the old `MaterialApp.router` shell, run `zfa app shell --zuraffa-app`, and verify `my_app.dart` now uses `ZuraffaApp`.

**Acceptance Scenarios**:

1. **Given** an existing Flutter project with `MaterialApp.router` in `my_app.dart`, **When** the developer runs `zfa app shell --zuraffa-app --force`, **Then** `my_app.dart` is regenerated with `ZuraffaApp` as the root widget
   **Type**: widget
2. **Given** an existing Flutter project with `MaterialApp.router`, **When** the developer runs `zfa app shell` without `--zuraffa-app`, **Then** the existing `MaterialApp.router` behavior is preserved (backward compatible)
   **Type**: acceptance

---

### User Story 3 - ZuraffaApp receives correct configuration (Priority: P1)

The generated `ZuraffaApp` must receive all required configuration: a title matching the app name, `debugShowCheckedModeBanner: false`, a `GlobalKey<NavigatorState>` for the navigator key, and a theme. The `ZuraffaApp` widget from `package:zuraffa_ui` expects these parameters.

**Why this priority**: Incorrect configuration would cause compilation errors or runtime failures. This is a correctness requirement that must ship with Story 1.

**Independent Test**: Inspect the generated `main.dart` for correct `ZuraffaApp` parameter passing and verify the file compiles.

**Acceptance Scenarios**:

1. **Given** the generated `main.dart` uses `ZuraffaApp`, **When** inspected, **Then** it passes `title` (the app name), `debugShowCheckedModeBanner: false`, a `GlobalKey<NavigatorState>` instance, and a theme parameter
   **Type**: widget
2. **Given** the generated `main.dart`, **When** analyzed with `dart analyze`, **Then** no errors are reported (the imports resolve correctly)
   **Type**: acceptance

---

### Edge Cases

- What happens when `zfa setup` is run in a directory that already has a `lib/main.dart` with a custom implementation? The `--force` flag should be required to overwrite, matching current behavior.
- What happens when `zuraffa_ui` is not in `pubspec.yaml`? The app shell generation should either auto-add it or refuse with a clear error message telling the developer to add it.
- What happens when `zfa app shell` is run on a project that already uses `ZuraffaApp`? It should be idempotent — re-generating the same `ZuraffaApp` shell without errors.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: `zfa setup` for Flutter projects MUST generate `lib/main.dart` using `ZuraffaApp` as the root widget instead of `MaterialApp.router`
- **FR-002**: The generated `main.dart` MUST import `package:zuraffa_ui/zuraffa_ui.dart` (or the appropriate barrel) to resolve the `ZuraffaApp` symbol
- **FR-003**: The generated `ZuraffaApp` MUST receive `title` (from the app name), `debugShowCheckedModeBanner: false`, a `GlobalKey<NavigatorState>`, and a theme
- **FR-004**: The generated `my_app.dart` MUST be removed or replaced — `ZuraffaApp` serves as the shell, so the intermediate `MyApp` widget wrapping `MaterialApp.router` is no longer needed when using `ZuraffaApp`
- **FR-005**: `zfa app shell --zuraffa-app` MUST continue to work for existing projects (backward compatibility)
- **FR-006**: `zfa app shell` without `--zuraffa-app` MUST preserve the current `MaterialApp.router` behavior for backward compatibility
- **FR-007**: `zfa setup` for pure Dart projects MUST NOT generate any Flutter app shell
- **FR-008**: The generated `main.dart` MUST compile cleanly with `dart analyze` (no unused imports, no missing symbols)
- **FR-009**: The `zuraffa_ui` dependency MUST be present in `pubspec.yaml` before the app shell is generated; if missing, `zfa setup` or `zfa app shell` MUST refuse with a clear error message
- **FR-010**: The `GoRouter` tree (generated routing) MUST remain functional beneath `ZuraffaApp` via `Router.withConfig` (the existing `--zuraffa-app` integration pattern)

## Layer Contracts

**Presentation**:
- `AppShellBuilder`: `buildMain(appName, coreImport, zuraffaApp) -> String`
- `AppShellBuilder`: `buildMyApp(zuraffaApp) -> String`

### Key Entities

_Note: No domain entities — this feature modifies code generation behavior only. The `AppShellConfig` is an internal builder parameter record, not a persisted entity._

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A freshly created Flutter app via `zfa setup` compiles and runs with zero manual edits after setup completes
- **SC-002**: The generated `main.dart` uses `ZuraffaApp` as the root widget (verifiable by inspecting the output)
- **SC-003**: All existing `zfa app shell` tests continue to pass (backward compatibility)
- **SC-004**: `dart analyze` reports no errors on the generated `main.dart`

## Assumptions

- `zuraffa_ui` is a published or path-available package that exports `ZuraffaApp`
- The `ZuraffaApp` widget accepts `title`, `debugShowCheckedModeBanner`, `navigatorKey`, and `theme` parameters (matching the user's code snippet)
- The existing `--zuraffa-app` flag in `zfa app shell` already handles the `ZuraffaApp` integration correctly (issue #1260)
- The `GoRouter` routing tree can be mounted beneath `ZuraffaApp` via `Router.withConfig` as the existing implementation does
- This change only affects the Flutter app shell generation path; pure Dart projects are unaffected
