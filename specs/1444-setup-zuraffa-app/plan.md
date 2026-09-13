# Implementation Plan: Setup generates ZuraffaApp as root widget

**Branch**: `1444-setup-zuraffa-app` | **Date**: 2026-09-10 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/1444-setup-zuraffa-app/spec.md`

## Summary

When `zfa setup` creates a Flutter app, it currently writes bootstrap DI/routing barrels and tells the user to run `zfa app shell` as a separate step. This change makes `zfa setup` invoke the app shell generation directly (using `ZuraffaApp` as the root widget), so the generated app is runnable immediately after setup with zero manual steps. The existing `--zuraffa-app` flag behavior and backward-compatible `MaterialApp.router` default are preserved for `zfa app shell` when invoked standalone.

## Technical Context

**Language/Version**: Dart 3.11+ (stable), Flutter SDK

**Primary Dependencies**: `code_builder` (code generation), `zuraffa_ui` (ZuraffaApp widget), `zuraffa_flutter` (core barrel re-export), `go_router` (routing beneath ZuraffaApp)

**Storage**: N/A (code generation, no runtime data)

**Testing**: `package:test` (`dart test`), regression tests in `test/regression/issue_512_*`, `test/plugins/app_shell/`

**Target Platform**: macOS (development), iOS/Android/Web (generated Flutter apps)

**Project Type**: CLI tool / code generator

**Performance Goals**: N/A (generation-time only)

**Constraints**: Must preserve backward compatibility — `zfa app shell` without `--zuraffa-app` must still generate `MaterialApp.router`. `zfa setup` for pure Dart must not generate any Flutter shell. `zuraffa_ui` must be in pubspec before ZuraffaApp generation.

**Scale/Scope**: 5 files modified, ~100 lines changed. Low blast radius — only affects the setup and app-shell generation paths.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

The constitution template is unfilled — no active principles to violate. The change aligns with the existing issue #512 pattern ( generators detect project flavor and switch imports accordingly) and issue #1260 (certified ZuraffaApp shell).

## Project Structure

### Documentation (this feature)

```text
specs/1444-setup-zuraffa-app/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
└── tasks.md             # Phase 2 output (speckit-tasks)
```

### Source Code (repository root)

```text
lib/src/
├── commands/
│   ├── setup_command.dart          # Add app-shell invocation after bootstrap
│   └── app_shell_command.dart      # Pass zuraffaApp flag through
├── plugins/app_shell/
│   └── builders/
│       └── app_shell_builder.dart  # buildMyApp already supports ZuraffaApp
test/
├── commands/
│   └── app_shell_command_test.dart # Existing tests (backward compat)
└── plugins/app_shell/
    └── app_shell_builder_test.dart # Builder unit tests
```

**Structure Decision**: Single project — changes are isolated to the CLI command layer and the app-shell builder. No new directories or packages needed.

## Complexity Tracking

No constitution violations — no complexity tracking needed.
