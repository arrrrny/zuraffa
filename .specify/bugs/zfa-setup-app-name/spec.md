**Template Version**: `zuraffa-1.0`

# Feature Specification: zfa setup/app shell emit name-derived shell file and class (not my_app.dart/MyApp)

**Feature Branch**: `fix/zfa-setup-app-name`

**Created**: 2026-09-10

**Status**: Draft

**Input**: Bug report (issue #1465): "Generated flutter app via zfa setup xyx should have xyx.dart not my_app.dart. also should not be MyApp it should be whatever the dart convention is so zfa setup zik_zak should create ZikZak or ZikZakApp not MyApp"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - `zfa setup <name>` derives the shell file and class from the app name (Priority: P1)

A developer bootstraps a new app with `zfa setup zik_zak`. Today the app shell lands at `lib/src/app/my_app.dart` with a hardcoded `class MyApp` no matter what name was passed. After this fix the shell file is named after the app (`zik_zak.dart`) and the widget class follows the Dart convention derived from that name (`ZikZakApp`), with `lib/main.dart` importing and constructing the derived symbol.

**Why this priority**: This is the exact defect reported; without it every generated app carries the wrong file/class names.

**Independent Test**: Run `zfa setup zik_zak` in a temp workspace and assert the emitted file names, class declaration, and `main.dart` wiring.

**Acceptance Scenarios**:

1. **Given** a fresh workspace, **When** `zfa setup zik_zak` runs, **Then** the shell is emitted at `lib/src/app/zik_zak.dart` declaring `class ZikZakApp extends StatelessWidget`, and the command exits 0.
   **Type**: acceptance
2. **Given** the same generated project, **When** `lib/main.dart` is inspected, **Then** it imports `package:zik_zak/src/app/zik_zak.dart` and calls `runApp(const ZikZakApp());`.
   **Type**: acceptance
3. **Given** a fresh workspace, **When** `zfa setup xyx` runs, **Then** the shell is emitted at `lib/src/app/xyx.dart` declaring `class XyxApp`, and `main.dart` imports `package:xyx/src/app/xyx.dart` and calls `runApp(const XyxApp());`.
   **Type**: acceptance

### User Story 2 - Back-compat: the name `my_app` keeps the current output (Priority: P1)

A developer (or automation) whose app is literally named `my_app`, and every existing consumer of the previous output shape, must get byte-identical behavior after the fix. The derivation is additive, not a rename of the contract.

**Why this priority**: Guards against silently breaking existing projects and the many tests/fixtures that pin the current shape.

**Independent Test**: Run the shell generation with app name `my_app` and assert the output matches today's `my_app.dart` / `MyApp` exactly.

**Acceptance Scenarios**:

1. **Given** an app named `my_app`, **When** the shell is generated, **Then** the file is `lib/src/app/my_app.dart` and the class is `MyApp` (the derivation collapses to the legacy literals).
   **Type**: acceptance

### User Story 3 - `zfa app shell` derives the same names from the target package (Priority: P2)

A developer runs `zfa app shell` inside an existing project whose pubspec `name:` is `zik_zak` (or any other name). The shell must use the same derivation as `zfa setup`: `app/zik_zak.dart` / `ZikZakApp`. Projects that still carry a legacy `app/my_app.dart` from an earlier zfa version must not get it silently deleted or corrupted — regeneration writes the new derived file and prints an informational notice about the legacy file instead.

**Why this priority**: `zfa app shell` shares the builder with `zfa setup`; fixing only one command leaves the other emitting the wrong names.

**Independent Test**: Run `zfa app shell` in a temp project named `zik_zak` (with the DI/routing barrels it preflights) and assert the derived file, class, and `main.dart` wiring; repeat with a stale legacy `my_app.dart` present and assert it survives untouched plus the notice.

**Acceptance Scenarios**:

1. **Given** a project whose pubspec name is `zik_zak`, **When** `zfa app shell` runs, **Then** the shell is emitted at `<outputDir>/app/zik_zak.dart` declaring `class ZikZakApp`, and `main.dart` imports `package:zik_zak/src/app/zik_zak.dart` and calls `runApp(const ZikZakApp());`.
   **Type**: acceptance
2. **Given** the same project also containing a legacy `app/my_app.dart`, **When** `zfa app shell` runs again, **Then** the legacy file is left untouched (never deleted) and an informational notice names it.
   **Type**: acceptance

### User Story 4 - Existing shell variants keep compiling (Priority: P2)

The shell has flag-driven variants (`--xray`, `--skin-audit`, the certified `ZuraffaApp` shell) and downstream wiring (X-Ray deck registration, import scanners). None may regress: every variant that compiled before the fix must still compile after it, with the widget name parameterized instead of hardcoded.

**Why this priority**: The builder is shared glue; a rename regression here breaks generated apps at compile time.

**Independent Test**: Generate the shell with `--xray` (and run the existing app-shell/xray regression tests) and assert the derived widget name appears in the `runApp` call and the X-Ray wiring still references the same class.

**Acceptance Scenarios**:

1. **Given** `zfa app shell --xray` in a project named `zik_zak`, **When** the shell is generated, **Then** `main.dart` calls `runApp(const ZikZakApp());` and the X-Ray wiring/compilation contract is unchanged.
   **Type**: acceptance
2. **Given** the full fast test suite, **When** it runs after the fix, **Then** the app-shell, setup, and related regression tests pass (with their pinned expectations updated to the new derived names where the fix changes them).
   **Type**: acceptance

### Edge Cases

- App names with underscores and digits (`zik_zak`) must convert to a valid PascalCase class (`ZikZakApp`) — underscores never leak into the class name.
- A single-word name (`xyx`) yields `XyxApp` / `xyx.dart` — no special-casing, the same derivation.
- The derivation must never emit a class name that is not a valid Dart identifier for any pubspec name that passes the existing `^[a-z][a-z0-9_]*$` validation.
