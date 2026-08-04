# Feature Specification: Pure-Dart Core Split (#253)

**Feature Branch**: `feat/zuraffa-pure-dart-split`

**Created**: 2026-08-05

**Status**: Implemented

**Issue**: #253

## Summary

Split the `zuraffa` package into two:

1. **`zuraffa`** — pure Dart platform: core, DI, usecases, hooks, interceptors, signals, transactions, graphql, MCP, plugins/generators, state management, CLI, code generation.
2. **`zuraffa_flutter`** — Flutter UI package: Controller, Presenter, View, Shells, XRay, state widgets (SignalBuilder, FragmentBuilder, ControlledWidget), ZuraffaFlutterPlugin, ZuraffaAppRunner, ZuraffaRouteBuilder.

Flutter apps depend on `zuraffa_flutter` (which re-exports `zuraffa`). Pure Dart apps (CLIs, servers, MCP agents) depend on `zuraffa` only.

## Changes

### Core leak fixes (zuraffa)

| File | Before | After |
|------|--------|-------|
| `api_bridge.dart` | `kReleaseMode`/`kProfileMode` from Flutter | `bool.fromEnvironment('dart.vm.product')` / `'dart.vm.profile'` |
| `failure_handler.dart` | `PlatformException`/`MissingPluginException` from Flutter | `ZuraffaPlatformException`/`ZuraffaMissingPluginException` (Dart-native) |
| `background_usecase.dart` | `kIsWeb` from Flutter | `bool.fromEnvironment('dart.library.js_util')` |
| `locale_converter.dart` | `dart:ui` Locale | Standalone `Locale` value class |

### Files moved to zuraffa_flutter

- `lib/src/presentation/` (34 files: controller, presenter, view, adaptive_view, responsive_view, controlled_widget, platform/*, shells/*, xray/*)
- `lib/src/state/widgets/` (3 files: signal_builder, fragment_builder, controlled_widget)
- `lib/src/core/module/app_runner.dart` → `zuraffa_flutter/lib/src/module/app_runner.dart`
- `lib/src/core/module/route_builder.dart` → `zuraffa_flutter/lib/src/module/route_builder.dart`
- 7 widget test files → `zuraffa_flutter/test/`

### Files that stay in zuraffa (generators only emit Flutter strings)

All files under `lib/src/plugins/`, `lib/src/dda/`, `lib/src/commands/`, `lib/src/mcp/` — they generate Flutter code as string templates but have zero Flutter type dependencies.

### Test conversion

- 161 tests converted from `flutter_test` to `dart:test`
- 7 widget tests moved to `zuraffa_flutter/test/`

### New artifacts

- `zuraffa_flutter/` — Flutter UI package with `ZuraffaFlutterPlugin`
- `examples/pure_dart_server/` — proof-of-concept pure Dart example
- `lib/src/core/xray_config.dart` — shared xray config constants for CLI

## Acceptance Criteria

- [x] `zuraffa` compiles + `dart analyze` passes with zero errors under pure Dart SDK
- [x] Zero `package:flutter/` imports in `zuraffa/lib/` and `zuraffa/bin/`
- [x] All 161 non-widget tests use `dart:test`; no `flutter_test` in `zuraffa/test/`
- [x] `zuraffa_flutter` re-exports `zuraffa` + ships `ZuraffaFlutterPlugin`
- [x] Pure Dart example (`examples/pure_dart_server/`) runs with `dart run`
- [x] CLI commands (`zfa`, `zfa xray`) remain functional — they generate code as strings
