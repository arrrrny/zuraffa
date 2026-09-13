# Traceability: 1444-setup-zuraffa-app

Coverage proof for `zfa tdd plan` (bug #846): every FR/AC requirement statement maps to a behavior row or an explicit manual declaration. Verify re-checks the hash — a spec edited after plan is drift (exit 3, re-plan required).

<!-- tdd:traceability
spec-hash: sha256:4b0bd6772d7f8943654cf6d9bc0094e5a921ca4835f77df7d1546cbd6a2f2c7d
statements: 17
automated: 17
manual: 0
open-gaps: 0
-->

| requirement | line | statement | behavior | status |
| --- | --- | --- | --- | --- |
| AC-1 | 25 | 1. **Given** a developer runs `zfa setup my_app` for a Flutter project, **When** the setup completes, **Then** `lib/main.dart` contains `runApp(ZuraffaApp(...))` with a title, theme, `debugShowCheckedModeBanner: false`, and a `GlobalKey<NavigatorState>` | A1 | automated |
| AC-2 | 27 | 2. **Given** a developer runs `zfa setup my_app --dart` for a pure Dart project, **When** the setup completes, **Then** no app shell is generated (pure Dart projects have no Flutter widgets) | A2 | automated |
| AC-3 | 29 | 3. **Given** a developer runs `zfa setup my_app` and the generated `main.dart` uses `ZuraffaApp`, **When** they run `flutter run`, **Then** the app compiles and launches without errors | A3 | automated |
| AC-4 | 44 | 1. **Given** an existing Flutter project with `MaterialApp.router` in `my_app.dart`, **When** the developer runs `zfa app shell --zuraffa-app --force`, **Then** `my_app.dart` is regenerated with `ZuraffaApp` as the root widget | A4 | automated |
| AC-5 | 46 | 2. **Given** an existing Flutter project with `MaterialApp.router`, **When** the developer runs `zfa app shell` without `--zuraffa-app`, **Then** the existing `MaterialApp.router` behavior is preserved (backward compatible) | A5 | automated |
| AC-6 | 61 | 1. **Given** the generated `main.dart` uses `ZuraffaApp`, **When** inspected, **Then** it passes `title` (the app name), `debugShowCheckedModeBanner: false`, a `GlobalKey<NavigatorState>` instance, and a theme parameter | A6 | automated |
| AC-7 | 63 | 2. **Given** the generated `main.dart`, **When** analyzed with `dart analyze`, **Then** no errors are reported (the imports resolve correctly) | A7 | automated |
| FR-001 | 78 | - **FR-001**: `zfa setup` for Flutter projects MUST generate `lib/main.dart` using `ZuraffaApp` as the root widget instead of `MaterialApp.router` | U1 | automated |
| FR-002 | 79 | - **FR-002**: The generated `main.dart` MUST import `package:zuraffa_ui/zuraffa_ui.dart` (or the appropriate barrel) to resolve the `ZuraffaApp` symbol | U2 | automated |
| FR-003 | 80 | - **FR-003**: The generated `ZuraffaApp` MUST receive `title` (from the app name), `debugShowCheckedModeBanner: false`, a `GlobalKey<NavigatorState>`, and a theme | U3 | automated |
| FR-004 | 81 | - **FR-004**: The generated `my_app.dart` MUST be removed or replaced — `ZuraffaApp` serves as the shell, so the intermediate `MyApp` widget wrapping `MaterialApp.router` is no longer needed when using `ZuraffaApp` | U4 | automated |
| FR-005 | 82 | - **FR-005**: `zfa app shell --zuraffa-app` MUST continue to work for existing projects (backward compatibility) | U5 | automated |
| FR-006 | 83 | - **FR-006**: `zfa app shell` without `--zuraffa-app` MUST preserve the current `MaterialApp.router` behavior for backward compatibility | U6 | automated |
| FR-007 | 84 | - **FR-007**: `zfa setup` for pure Dart projects MUST NOT generate any Flutter app shell | U7 | automated |
| FR-008 | 85 | - **FR-008**: The generated `main.dart` MUST compile cleanly with `dart analyze` (no unused imports, no missing symbols) | U8 | automated |
| FR-009 | 86 | - **FR-009**: The `zuraffa_ui` dependency MUST be present in `pubspec.yaml` before the app shell is generated; if missing, `zfa setup` or `zfa app shell` MUST refuse with a clear error message | U9 | automated |
| FR-010 | 87 | - **FR-010**: The `GoRouter` tree (generated routing) MUST remain functional beneath `ZuraffaApp` via `Router.withConfig` (the existing `--zuraffa-app` integration pattern) | U10 | automated |

