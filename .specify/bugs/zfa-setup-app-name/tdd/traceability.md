# Traceability: zfa-setup-app-name

Coverage proof for `zfa tdd plan` (bug #846): every FR/AC requirement statement maps to a behavior row or an explicit manual declaration. Verify re-checks the hash — a spec edited after plan is drift (exit 3, re-plan required).

<!-- tdd:traceability
spec-hash: sha256:ad0fd03985fb878917c8ea23fa5cc39d0ffae2151d150a5e92b47d60ea9c3e55
statements: 8
automated: 8
manual: 0
open-gaps: 0
-->

| requirement | line | statement | behavior | status |
| --- | --- | --- | --- | --- |
| AC-1 | 25 | 1. **Given** a fresh workspace, **When** `zfa setup zik_zak` runs, **Then** the shell is emitted at `lib/src/app/zik_zak.dart` declaring `class ZikZakApp extends StatelessWidget`, and the command exits 0. | A1 | automated |
| AC-2 | 26 | 2. **Given** the same generated project, **When** `lib/main.dart` is inspected, **Then** it imports `package:zik_zak/src/app/zik_zak.dart` and calls `runApp(const ZikZakApp());`. | A2 | automated |
| AC-3 | 27 | 3. **Given** a fresh workspace, **When** `zfa setup xyx` runs, **Then** the shell is emitted at `lib/src/app/xyx.dart` declaring `class XyxApp`, and `main.dart` imports `package:xyx/src/app/xyx.dart` and calls `runApp(const XyxApp());`. | A3 | automated |
| AC-4 | 39 | 1. **Given** an app named `my_app`, **When** the shell is generated, **Then** the file is `lib/src/app/my_app.dart` and the class is `MyApp` (the derivation collapses to the legacy literals). | A4 | automated |
| AC-5 | 51 | 1. **Given** a project whose pubspec name is `zik_zak`, **When** `zfa app shell` runs, **Then** the shell is emitted at `<outputDir>/app/zik_zak.dart` declaring `class ZikZakApp`, and `main.dart` imports `package:zik_zak/src/app/zik_zak.dart` and calls `runApp(const ZikZakApp());`. | A5 | automated |
| AC-6 | 52 | 2. **Given** the same project also containing a legacy `app/my_app.dart`, **When** `zfa app shell` runs again, **Then** the legacy file is left untouched (never deleted) and an informational notice names it. | A6 | automated |
| AC-7 | 64 | 1. **Given** `zfa app shell --xray` in a project named `zik_zak`, **When** the shell is generated, **Then** `main.dart` calls `runApp(const ZikZakApp());` and the X-Ray wiring/compilation contract is unchanged. | A7 | automated |
| AC-8 | 65 | 2. **Given** the full fast test suite, **When** it runs after the fix, **Then** the app-shell, setup, and related regression tests pass (with their pinned expectations updated to the new derived names where the fix changes them). | A8 | automated |

