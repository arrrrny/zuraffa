# Research: Setup generates ZuraffaApp as root widget

## Decision: `zfa setup` invokes app shell generation with `--zuraffa-app` by default

**Decision**: `zfa setup` for Flutter projects will internally invoke the app shell generation path (the same code path as `zfa app shell --zuraffa-app`) after writing the bootstrap DI/routing barrels, instead of printing a message telling the user to run it manually.

**Rationale**: This is the minimal change that satisfies FR-001. The `AppShellBuilder.buildMyApp(zuraffaApp: true)` already generates the correct `ZuraffaApp` shell. The `AppShellCommand` already handles the `--zuraffa-app` flag, preflight check for `zuraffa_ui` dependency, and routing integration. Reusing this existing code path avoids duplication and ensures the setup and standalone app-shell paths produce identical output.

**Alternatives considered**:
- *Changing the default of `zfa app shell` to ZuraffaApp*: Rejected because FR-006 requires backward compatibility — existing users who run `zfa app shell` without flags must still get `MaterialApp.router`.
- *Adding a new `--zuraffa-app` flag to `zfa setup`*: Possible but adds a CLI flag the user didn't ask for. The user's expectation is that Flutter apps always get ZuraffaApp, not that they need a flag.
- *Duplicating the builder logic in setup_command.dart*: Rejected — DRY violation, would drift from the app-shell builder.

## Decision: `zfa setup` calls `AppShellCommand.run()` programmatically

**Decision**: Rather than shelling out to `zfa app shell --zuraffa-app` as a subprocess, `zfa setup` will invoke the `AppShellCommand`'s internal generation logic directly (same-process call). This avoids process-spawning overhead and keeps error handling unified.

**Rationale**: The `AppShellCommand` is already designed for programmatic use — it accepts `FileSystem` and `AppShellBuilder` via constructor injection. The setup command can instantiate it with the same parameters and call its generation method.

**Alternatives considered**:
- *Subprocess call to `dart run zfa app shell --zuraffa-app`*: Simpler but introduces process-spawning, requires the `zfa` binary to be on PATH, and complicates error handling.
- *Extracting a shared function from AppShellCommand*: Cleaner separation but a larger refactor than needed for this change.

## Decision: Preflight check for `zuraffa_ui` is handled by the existing `AppShellCommand`

**Decision**: The `zuraffa_ui` dependency preflight (issue #1260) already runs in `AppShellCommand` when `zuraffaApp: true`. When `zfa setup` invokes the app shell generation, this check runs automatically. If `zuraffa_ui` is missing, the command throws `AppShellException` with a clear error message.

**Rationale**: No new preflight logic needed — the existing guard handles it. The setup command should surface the error clearly to the user.

## Decision: `main.dart` structure for ZuraffaApp

**Decision**: The generated `main.dart` will follow this pattern:

```dart
import 'package:flutter/material.dart';
import 'package:zuraffa_flutter/zuraffa_flutter.dart';
import 'package:zuraffa_ui/zuraffa_ui.dart';
import 'src/di/index.dart';

void main() {
  setupDependencies(GetIt.instance);
  runApp(const MyApp());
}
```

And `my_app.dart` will be replaced by the ZuraffaApp shell (no intermediate `MyApp` widget wrapping `MaterialApp.router`).

**Rationale**: The user's code snippet shows `ZuraffaApp` as the direct root widget. The existing `--zuraffa-app` path in `AppShellBuilder.buildMyApp` already generates `ZuraffaApp` with `Router.withConfig(config: appRouter)` for routing.

## Key Finding: ZuraffaApp constructor parameters

From `app_shell_builder.dart` line 367-395, the existing `--zuraffa-app` path generates:

```dart
ZuraffaApp(
  title: '<app title>',
  home: Router.withConfig(config: appRouter),
)
```

The user's code snippet additionally shows `debugShowCheckedModeBanner`, `theme`, `themeMode`, and `navigatorKey`. These are standard `MaterialApp`-compatible parameters that `ZuraffaApp` likely accepts (it wraps `MaterialApp` internally). The existing builder does NOT currently emit these — they would need to be added to match the user's expectation.

**Action**: The builder should emit `debugShowCheckedModeBanner: false` (matching the user's snippet and the existing `MaterialApp.router` behavior). Theme and navigatorKey can use reasonable defaults (no theme = ZuraffaApp's default; no explicit navigator key unless the user requests one).
