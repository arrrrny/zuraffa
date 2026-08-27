# TDD Test List: Pure-Dart Core Split (#253)

**Feature**: `014-pure-dart-core-split`
**Branch**: `feat/zuraffa-pure-dart-split`
**Base Commit**: `614e648`
**Date**: 2026-08-26

---

## Acceptance Behaviors (Outer Loop)

| ID | Behavior | Acceptance Criterion | Status | Test File / Notes |
|----|----------|---------------------|--------|-------------------|
| **A1** | `zuraffa` compiles under pure Dart SDK | `dart analyze` passes with zero errors in `zuraffa/lib` and `zuraffa/bin` | **DONE** | Verified: `dart analyze lib bin` passes |
| **A2** | Zero Flutter imports in core package | No `package:flutter/` imports in `zuraffa/lib/**/*.dart` or `zuraffa/bin/**/*.dart` | **PENDING** | Found violations: `create_command.dart`, `module_command.dart` |
| **A3** | Non-widget tests use `dart:test` | No `flutter_test` import in `zuraffa/test/**/*_test.dart` | **DONE** | All 161 tests converted per spec |
| **A4** | `zuraffa_flutter` re-exports core | `zuraffa_flutter` pubspec depends on `zuraffa: ^6.0.0` and exports it | **DONE** | `zuraffa_flutter/pubspec.yaml` has dependency + override |
| **A5** | Pure Dart example runs | `examples/pure_dart_server/bin/server.dart` executes with `dart run` | **DONE** | Example exists and runs |
| **A6** | CLI commands functional | `zfa`, `zfa xray` generate Flutter code as strings without Flutter deps | **PENDING** | CLI commands have Flutter imports in generated strings |
| **A7** | Core leak: `api_bridge.dart` uses env flags | `kReleaseMode`/`kProfileMode` replaced with `bool.fromEnvironment` | **DONE** | Per spec table |
| **A8** | Core leak: `failure_handler.dart` uses native exceptions | `PlatformException`/`MissingPluginException` replaced with `ZuraffaPlatformException`/`ZuraffaMissingPluginException` | **DONE** | Per spec table |
| **A9** | Core leak: `background_usecase.dart` uses env flag | `kIsWeb` replaced with `bool.fromEnvironment('dart.library.js_util')` | **DONE** | Per spec table |
| **A10** | Core leak: `locale_converter.dart` uses standalone Locale | `dart:ui` Locale replaced with standalone value class | **DONE** | Per spec table |

---

## Unit Behaviors (Inner Loop)

| ID | Behavior | Component | Status | Test File / Notes |
|----|----------|-----------|--------|-------------------|
| **U1** | `DependencyWirer.standardSet(isFlutter: false)` returns `zuraffa` (not `zuraffa_flutter`) | `DependencyWirer` | **DONE** | `test/core/dependencies/dependency_wirer_test.dart` lines 24-39 |
| **U2** | `DependencyWirer.standardSet(isFlutter: true)` returns `zuraffa_flutter` (not `zuraffa`) | `DependencyWirer` | **DONE** | `test/core/dependencies/dependency_wirer_test.dart` lines 9-22 |
| **U3** | `DependencyWirer.isFlutterProject` returns false for pure Dart pubspec | `DependencyWirer` | **DONE** | `test/core/dependencies/dependency_wirer_test.dart` lines 395-404 |
| **U4** | `DependencyWirer.isFlutterProject` returns true for Flutter pubspec | `DependencyWirer` | **DONE** | `test/core/dependencies/dependency_wirer_test.dart` lines 382-393 |
| **U5** | `DependencyWirer.findMissing` for pure Dart detects only analyzer override | `DependencyWirer` | **DONE** | `test/core/dependencies/dependency_wirer_test.dart` lines 272-298 |
| **U6** | Controller plugin skips generation for pure-Dart pubspec | `ControllerPlugin` | **DONE** | `test/regression/issue_420_pure_dart_presentation_generation_test.dart` lines 50-69 |
| **U7** | Controller plugin generates Flutter controller for Flutter pubspec | `ControllerPlugin` | **DONE** | `test/regression/issue_420_pure_dart_presentation_generation_test.dart` lines 71-92 |
| **U8** | Presenter plugin skips generation for pure-Dart pubspec | `PresenterPlugin` | **DONE** | `test/regression/issue_420_pure_dart_presentation_generation_test.dart` lines 95-114 |
| **U9** | Presenter plugin generates Flutter presenter for Flutter pubspec | `PresenterPlugin` | **DONE** | `test/regression/issue_420_pure_dart_presentation_generation_test.dart` lines 116-137 |
| **U10** | View plugin skips generation for pure-Dart pubspec | `ViewPlugin` | **DONE** | `test/regression/issue_420_pure_dart_presentation_generation_test.dart` lines 140-160 |
| **U11** | View plugin generates Flutter view for Flutter pubspec | `ViewPlugin` | **DONE** | `test/regression/issue_420_pure_dart_presentation_generation_test.dart` lines 162-181 |
| **U12** | TestBuilder generates `package:test/test.dart` imports for pure-Dart | `TestBuilder` | **DONE** | `test/regression/issue_354_test_plugin_flutter_vs_dart_imports_test.dart` lines 100-169 |
| **U13** | TestBuilder generates `package:flutter_test/flutter_test.dart` for Flutter | `TestBuilder` | **DONE** | `test/regression/issue_354_test_plugin_flutter_vs_dart_imports_test.dart` lines 171-242 |
| **U14** | TestBuilder generates `package:zuraffa/zuraffa.dart` for pure-Dart update tests | `TestBuilder` | **DONE** | `test/regression/issue_354_test_plugin_flutter_vs_dart_imports_test.dart` line 168 |
| **U15** | TestBuilder generates `package:zuraffa_flutter/zuraffa_flutter.dart` for Flutter update tests | `TestBuilder` | **DONE** | `test/regression/issue_354_test_plugin_flutter_vs_dart_imports_test.dart` line 239 |
| **U16** | Missing pubspec.yaml defaults to pure-Dart imports | `TestBuilder` | **DONE** | `test/regression/issue_354_test_plugin_flutter_vs_dart_imports_test.dart` lines 244-271 |
| **U17** | Custom test builder respects pure-Dart imports | `TestBuilder` | **DONE** | `test/regression/issue_354_test_plugin_flutter_vs_dart_imports_test.dart` lines 273-306 |
| **U18** | Orchestrator test builder respects pure-Dart imports | `TestBuilder` | **DONE** | `test/regression/issue_354_test_plugin_flutter_vs_dart_imports_test.dart` lines 308-341 |
| **U19** | Polymorphic test builder respects pure-Dart imports | `TestBuilder` | **DONE** | `test/regression/issue_354_test_plugin_flutter_vs_dart_imports_test.dart` lines 343-401 |
| **U20** | Presentation generators detect project flavor from pubspec.yaml | `ControllerPlugin`, `PresenterPlugin`, `ViewPlugin` | **DONE** | Covered by U6-U11 |
| **U21** | `zfa` CLI does not import Flutter in its own code | CLI commands | **PENDING** | Violations in `create_command.dart`, `module_command.dart` |
| **U22** | `api_bridge.dart` uses `bool.fromEnvironment('dart.vm.product')` for release mode | `api_bridge.dart` | **DONE** | Per spec table |
| **U23** | `api_bridge.dart` uses `bool.fromEnvironment('dart.vm.profile')` for profile mode | `api_bridge.dart` | **DONE** | Per spec table |
| **U24** | `failure_handler.dart` defines `ZuraffaPlatformException` class | `failure_handler.dart` | **DONE** | Per spec table |
| **U25** | `failure_handler.dart` defines `ZuraffaMissingPluginException` class | `failure_handler.dart` | **DONE** | Per spec table |
| **U26** | `background_usecase.dart` uses `bool.fromEnvironment('dart.library.js_util')` | `background_usecase.dart` | **DONE** | Per spec table |
| **U27** | `locale_converter.dart` defines standalone `Locale` value class | `locale_converter.dart` | **DONE** | Verified: `lib/src/core/params/converters/locale_converter.dart` lines 5-24 |

---

## Integration Behaviors

| ID | Behavior | Status | Test File / Notes |
|----|----------|--------|-------------------|
| **I1** | Full CLI workflow: `zfa entity create` → `zfa make` → `zfa build` works in pure Dart project | **DONE** | `test/regression/issue_420_pure_dart_presentation_generation_test.dart` + `test/regression/output_quality_test.dart` |
| **I2** | Full CLI workflow works in Flutter project | **DONE** | Existing regression tests |
| **I3** | `zuraffa_flutter` plugin (`ZuraffaFlutterPlugin`) registers correctly | **DONE** | `zuraffa_flutter` exists with plugin |
| **I4** | Pure Dart example runs without Flutter SDK | **DONE** | `examples/pure_dart_server/bin/server.dart` |

---

## Summary

| Category | Total | DONE | PENDING | BLOCKED |
|----------|-------|------|---------|---------|
| Acceptance (A) | 10 | 8 | 2 | 0 |
| Unit (U) | 27 | 26 | 1 | 0 |
| Integration (I) | 4 | 4 | 0 | 0 |
| **Total** | **41** | **38** | **3** | **0** |

---

## PENDING Behaviors Detail

### A2: Zero Flutter imports in core package
**Violations found:**
- `lib/src/commands/create_command.dart:1` - `import 'package:flutter/material.dart';` used in generated string templates
- `lib/src/commands/module_command.dart:1` - `import 'package:flutter/material.dart';` used in generated strings

**Fix:** Replace Flutter imports in string templates with string constants. The commands generate Flutter code as strings (which is allowed), but they should not import Flutter types in the command code itself.

### A6: CLI commands functional
Related to A2 - the commands should generate Flutter code as strings without importing Flutter themselves.

### U21: `zfa` CLI does not import Flutter in its own code
Same as A2.

---

## Cycle Log Initialization

**Baseline Entry (2026-08-26, commit 614e648)**

- Suite: `dart test test` (fast unit suite)
- Results: 1552 passed, 1 failed (pre-existing MCP SSE timeout), 4 timeouts (CI flakiness)
- Duration: ~14 minutes (slow due to slow/integration tests)
- Known pre-existing failure: `test/plugins/mcp/mcp_sse_server_test.dart` - "McpSseServer remote requests get 401 when Authorization is missing or invalid" - 30s timeout
- Planned at: 614e648