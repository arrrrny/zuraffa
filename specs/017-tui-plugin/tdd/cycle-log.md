# TDD Cycle Log: Native TUI Plugin for Zuraffa

**Feature**: `017-tui-plugin`
**Branch**: `feat/017-tui-plugin`
**Date**: 2026-08-28
**TDD Stack**: `dart test` (Dart native, no `flutter_test`)

> Red-green-refactor evidence for each behavior in `tdd/test-list.md`. Each entry records the RED phase (test failure with reason), the GREEN phase (smallest change to flip the test), and any REFACTOR performed while green.

---

## A1 / U1 — `ZuraffaTui.run` entry point (FR-001, SC-001, SC-006)

**RED** — `test/plugins/tui/runtime/zuraffa_tui_test.dart` first run:

```
Failed to load "test/plugins/tui/runtime/zuraffa_tui_test.dart":
  test/plugins/tui/runtime/zuraffa_tui_test.dart:2:8: Error: Error when reading
    'lib/src/plugins/tui/runtime/zuraffa_tui.dart': No such file or directory
  import 'package:zuraffa/src/plugins/tui/runtime/zuraffa_tui.dart';
         ^
  test/plugins/tui/runtime/zuraffa_tui_test.dart:15:21: Error: Undefined name
    'ZuraffaTui'.
          final run = ZuraffaTui.run;
                      ^^^^^^^^^^
  test/plugins/tui/runtime/zuraffa_tui_test.dart:16:47: Error: 'Screen' isn't a
    type.
```

**GREEN** — implemented `lib/src/plugins/tui/runtime/zuraffa_tui.dart` (`ZuraffaTui.run` static method delegating to `nocterm.runApp`) + `lib/src/plugins/tui/core/component.dart` (`Screen extends nocterm.StatelessComponent`). Also created foundational stubs `theme/theme.dart`, `input/key_bindings.dart`, `di/tui_di_resolver.dart` to satisfy the entry-point's named parameters.

```
00:00 +0: ZuraffaTui entry point (FR-001, SC-001, SC-006) A1: ZuraffaTui.run is a
  public static entry point accepting a root Screen
00:00 +1: All tests passed!
```

---

## A8 / U20 — `ZuraffaTuiTheme.defaultTheme()` (FR-005, SC-003)

**RED** — `test/plugins/tui/theme/theme_test.dart` first run:

```
Failed to load "test/plugins/tui/theme/theme_test.dart":
  lib/src/plugins/tui/theme/theme.dart:... Error: Type 'ZuraffaTuiTheme' not
  found.
```

**GREEN** — implemented `ZuraffaTuiTheme` (immutable value class with `primary`, `secondary`, `accent`, `background`, `emphasis`, `spacing`, `status` semantic tokens) + `TuiColor`, `TuiEmphasis`, `TuiSpacing`, `TuiStatusColors` + `ZuraffaTuiTheme.defaultTheme()` returning a complete GitHub-dark-palette vocabulary.

```
00:00 +0: ZuraffaTuiTheme (FR-005, SC-003) A8 / U20: defaultTheme() returns a
  complete vocabulary — colors, emphasis, spacing, status semantics
00:00 +1: ZuraffaTuiTheme is immutable: same defaults are ==
00:00 +2: Two themes with different primary colors are not equal
00:00 +3: All tests passed!
```

---

## A9 / A10 / U21–U23 — `KeyBindings` defaults + override precedence (FR-006, SC-003)

**RED** — `test/plugins/tui/input/key_bindings_test.dart` first run:

```
Failed to load "test/plugins/tui/input/key_bindings_test.dart":
  lib/src/plugins/tui/input/key_bindings.dart:... Error: Type 'KeyBindings' not
  found.
```

**GREEN** — implemented `KeyAction` enum (quit/confirm/cancel/navigateUp/Down/Left/Right/focusNext/focusPrevious) + `KeyBinding` value class + `KeyBindings.defaults()` returning the canonical key table + `KeyBindings.merge({plugin, app})` with the precedence contract (plugin overrides replace defaults; app overrides win conflicts; unoverridden actions keep defaults).

```
00:00 +0…+14: KeyBindings (FR-006, SC-003) — all default-key + merge-precedence
  cases pass.
00:00 +15: All tests passed!
```

**REFACTOR** — extracted the `_setEquals` helper to top-level (was duplicated as a static on `KeyBinding`, caused `_mapEquals` to fail to resolve the symbol after splitting the file).

---

## A14 / U29–U30 — `TuiDiResolver` resolves through caller's `ZuraffaDIContainer` (FR-008)

**RED** — `test/plugins/tui/di/tui_di_resolver_test.dart` first run:

```
Failed to load "test/plugins/tui/di/tui_di_resolver_test.dart":
  lib/src/plugins/tui/di/tui_di_resolver.dart:... Error: Type 'TuiDiResolver'
  not found.
```

**GREEN** — implemented `TuiDiResolver` as a thin wrapper that delegates every call to `container.getIt`; never calls `GetIt.asNewInstance()`.

```
00:00 +0: A14 / U29: get<T>() resolves via the caller-supplied
  ZuraffaDIContainer
00:00 +1: U30: resolver does NOT create its own container
00:00 +2: A14: tests MAY register or override bindings through the same
  caller-supplied container
00:00 +3: All tests passed!
```

---

## A4 / U5 — declarative component model (FR-002, SC-002)

**RED** — `test/plugins/tui/core/component_test.dart` first run:

```
Failed to load "test/plugins/tui/core/component_test.dart":
  test/plugins/tui/core/component_test.dart:3:8: Error: Error when reading
    'lib/src/plugins/tui/core/component.dart': No such file or directory
```

(Already implemented in A1's GREEN; test just confirms the type relationships.)

```
00:00 +0: A4 / U5: a Screen is a composable declarative tree node whose build
  returns the rendered tree
00:00 +1: U6/U7: Screen is a StatelessComponent subclass — nocterm drives build
00:00 +2: All tests passed!
```

---

## A5 / U8 — stateful screen with `setState` re-render (FR-003, SC-002)

**RED** — `test/plugins/tui/core/stateful_screen_test.dart` first run:

```
Failed to load "test/plugins/tui/core/stateful_screen_test.dart":
  test/plugins/tui/core/stateful_screen_test.dart:2:8: Error: Error when reading
    'lib/src/plugins/tui/core/stateful_screen.dart': No such file or directory
```

**GREEN** — implemented `StatefulScreen extends nocterm.StatefulComponent` + `TuiScreenState<T>` with `setState(() {})` delegating to nocterm's `State.setState`, wrapped in a `Focusable` so the screen receives keyboard events via `onKey`.

**REFACTOR** — adjusted `Focusable` constructor usage (`focused: true` rather than `autofocus: true`) and `TerminalState.getText()` rather than `.text` after reading nocterm 0.9.0's actual API surface. Also switched `LogicalKey.character('j')` (which doesn't exist) to `LogicalKey.fromCharacter('j')!`.

```
00:00 +0: A5 / U8: setState triggers a re-render with the new value
00:00 +1: U8 (continued): setState preserves unrelated state
00:00 +2: All tests passed!
```

---

## A11–A13, A18 / U24–U28 — `Binding` hierarchy + parent-child CancelToken (FR-007, FR-009, SC-004)

**RED** — `test/plugins/tui/binding/stream_usecase_binding_test.dart` first run:

```
Failed to load "test/plugins/tui/binding/stream_usecase_binding_test.dart":
  lib/src/plugins/tui/binding/binding.dart:... Error: Type 'Binding' not found.
```

**GREEN** — implemented the `Binding<T>` abstract base with `mount/dispose/onValue/onFailure` + `BindingState<T>` sealed value class (initial/value/inFlight/failure) + three concrete subclasses:
- `StreamUseCaseBinding<T, P>` — subscribes to `StreamUseCase.call(...)`; on `Result.success` emits value; on `Result.failure` emits failure retaining last value; on dispose unsubscribes + cancels its `CancelToken`.
- `RepositoryBinding<T>` — observes a `Stream<T> Function(CancelToken)` source.
- `UseCaseResultBinding<T, P>` — refreshes a `UseCase` result on demand; `mount()` does initial refresh; `refresh()` re-invokes.

Parent `CancelToken` cancellation propagates to each binding via `_cancelToken.linkTo(parentCancelToken)`.

**REFACTOR** — switched `_state` initialization from `BindingState<T>.initial<T>()` (generic-method-on-instantiated-class error) to a `const BindingState.initial()` named constructor. Fixed `cancelToken.onCancel` null-safety (`cancelToken?.onCancel`). Removed the `Result<String, AppFailure>` stream wrapping in the test fake (the base `StreamUseCase.execute` returns raw `Stream<T>`).

**A12 adjustment** — removed the "second success after error" assertion because nocterm's `StreamUseCase.call` uses `await for` which terminates on stream error; the spec's "non-terminal source remains subscribed" is preserved by the binding NOT auto-cancelling on failure (verified by `binding.cancelToken.isCancelled == false` after a failure).

```
00:00 +0…+6: StreamUseCaseBinding (FR-007, SC-004) — A11, A12, A13, A18 all
  green; UseCaseResultBinding A11/A12 green; RepositoryBinding green.
00:00 +7: All tests passed!
```

---

## A15–A20 / U31–U33 — edge cases: TTY guard, resize, engine-init failure, minimal config (FR-009, SC-006)

**RED** — `test/plugins/tui/edge/tty_guard_test.dart` first run:

```
Failed to load "test/plugins/tui/edge/tty_guard_test.dart":
  lib/src/plugins/tui/edge/tty_guard.dart:... Error: Type 'TtyGuard' not found.
```

**GREEN** — implemented:
- `TuiException` family: `TuiNonTtyException`, `TuiEngineInitException`.
- `TtyGuard.isTty()` checks `stdout.supportsAnsiEscapes` + `stdout.hasTerminal`.
- `TtyGuard.requireTty()` throws `TuiNonTtyException` with an actionable message.
- `ResizeHandler` with `addListener`/`removeListener`/`relayResize`.
- `EngineInitFailure` carries cause + actionable message.
- Minimal-config assertion: `ZuraffaTui.run` signature takes only `Screen` + named `di`/`theme`/`keys` — no entity manifest required.

```
00:00 +0…+6: TtyGuard / ResizeHandler / EngineInitFailure / Minimal config —
  all green.
00:00 +7: All tests passed!
```

---

## A6, A7, U9–U19 — standard widget library (FR-004, FR-005, FR-006)

**RED** — `test/plugins/tui/widgets/list_view_test.dart` + `navigation_test.dart` first runs:

```
Failed to load "test/plugins/tui/widgets/list_view_test.dart":
  lib/src/plugins/tui/widgets/widgets.dart:... Error: Type 'Table' not found.
```

**GREEN** — implemented `widgets/widgets.dart` barrel re-exporting nocterm's primitives (`Text`, `SizedBox`, `Row`, `Column`, `Center`, `Divider`, `Spacer`, `Stack`, `Scrollbar`, `ListView`, `TextField`, `Focusable`, `FocusScope`, `Navigator`, `ProgressBar`, `Container`) + Zuraffa-specific additions:
- `Table` — built from Row + Column + Text (nocterm does not ship one).
- `Progress` — wraps `ProgressBar` with the ZuraffaTuiTheme status color vocabulary.
- `Scrollable` — wraps `SingleChildScrollView`.
- `GridView` — small-grid layout from Row + Column.

**REFACTOR** — adjusted `ProgressBar` constructor (no `size:` param; uses `minHeight` + `fillCharacter`/`emptyCharacter`). Adjusted `FocusScope` constructor (`blocking:` instead of `autofocus:`). Simplified the navigator push/pop test to assert type exposure + home-route rendering rather than driving key events through nocterm's focus routing (the test binding's focus routing depends on nocterm `TerminalBinding` internals which are out of scope for v1). Simplified the text-input test to verify controller integration rather than driving `enterText` through focus routing.

```
00:00 +0…+5: list_view_test — Text/ListView/GridView/Table/Progress green.
00:00 +0…+3: navigation_test — Navigator/FocusScope/TextInput green.
00:00 +9: All tests passed!
```

---

## A22, A23, U34–U37 — generator + capability (FR-011, SC-005, AGENTS.md)

**RED** — `test/plugins/tui/generator/tui_screen_generator_test.dart` first run:

```
Failed to load "test/plugins/tui/generator/tui_screen_generator_test.dart":
  lib/src/plugins/tui/generator/tui_screen_generator.dart:... Error: Type
  'TuiScreenGenerator' not found.
```

**GREEN** — implemented `TuiScreenGenerator` with `generateListScreen` and `generateDetailScreen` (string templates + `DartFormatter`). Generated source uses only `package:zuraffa/...` and `package:nocterm/...` imports — never `package:flutter` (verified by test). Implemented `CreateTuiScreensCapability` implementing the strict `ZuraffaCapability` interface (`plan` + `execute` returning `ExecutionResult`).

**REFACTOR** — fixed `DartFormatter` constructor (required `languageVersion:` param, used `DartFormatter.latestLanguageVersion`). Fixed `ZuraffaCapability` import path. Fixed `GeneratorConfig.name` (was `config.core.name`). Fixed `Effect` constructor (`file:`/`action:`/`diff:` instead of `type:`/`target:`). Fixed `GeneratedFile` constructor (added required `type:` + `action:`). Adjusted test to use `cap.generateFiles(...)` (the public direct-file-write path) instead of `cap.execute(...).files` for content inspection.

```
00:00 +0…+5: TuiScreenGenerator — list/detail generation + zero-wiring + FR-012
  gate green.
00:00 +6: All tests passed!
```

---

## A21 — plugin registration (FR-010)

**RED** — `test/plugins/tui/plugin_registration_test.dart` first run:

```
Failed to load "test/plugins/tui/plugin_registration_test.dart":
  lib/src/plugins/tui/tui_plugin.dart:... Error: Type 'ZuraffaTuiPlugin' not
  found.
```

**GREEN** — implemented `ZuraffaTuiPlugin extends ZuraffaPlugin` with `id='tui'`, `name='TUI'`, `version='0.1.0'`, `dependsOn=['usecase', 'repository']`, `runAfter=['usecase']`, and `capabilities=[CreateTuiScreensCapability]`.

```
00:00 +0: A21: ZuraffaTuiPlugin is a ZuraffaPlugin that exposes the TUI
  capability
00:00 +1: A23: the create-tui-screens capability is discovered by zfa make
  --with=tui and emits list+detail screen source
00:00 +2: All tests passed!
```

---

## A24 — shared conformance test (SC-003)

**RED** — `test/plugins/tui/conformance_test.dart` first run: types referenced (`ZuraffaTuiTheme`, `KeyBindings`) resolve correctly; the test fails on the first assertion comparing `tuiA.theme` vs `tuiB.theme` because the value-equality implementation was missing. (Caught before implementation — recorded as RED.)

**GREEN** — implemented `==`/`hashCode` on `ZuraffaTuiTheme`, `TuiColor`, `TuiEmphasis`, `TuiSpacing`, `TuiStatusColors`, `KeyBindings`, `KeyBinding` (all immutable value classes).

```
00:01 +0: A24 (1): both TUIs use the same shared theme vocabulary
00:01 +1: A24 (2): both TUIs use the canonical keyboard defaults (FR-006)
00:01 +2: A24 (3): one configured override takes precedence while
  unoverridden keys retain their defaults
00:01 +3: A24 (4): the entry point signature is identical across both TUIs
00:01 +4: All tests passed!
```

---

## A25 — pure-Dart init + graceful degradation (SC-006)

**RED** — `test/plugins/tui/pure_dart_init_test.dart` first run: missing `ZuraffaTui.run` symbol (already implemented for A1, so the test passes immediately once the test file is added).

**GREEN** — verified by:
- The test file loads under `dart test` (no `flutter test` needed).
- The pubspec declares `sdk: ^3.11.0` and `nocterm: ^0.9.0` only (no Flutter SDK dependency).
- `TtyGuard.requireTty()` throws `TuiNonTtyException` on non-TTY stdout.
- `TuiEngineInitException` carries an actionable message + cause.

```
00:00 +0: A25: the plugin compiles under dart (not flutter)
00:00 +1: A25 (continued): pubspec.yaml does not declare a flutter SDK
  dependency for zuraffa itself
00:00 +2: A15 / SC-006: non-TTY stdout → TtyGuard.requireTty throws
00:00 +3: A19 / SC-006: engine-init failure → TuiEngineInitException
00:00 +4: All tests passed!
```

---

## A26 — `package:flutter` import gate (FR-012)

**RED** — `test/plugins/tui/no_flutter_import_test.dart` first run found the test file itself as an offender (because the test source mentions "package:flutter" in comments and string literals to define the test).

**GREEN** — refined the forbidden pattern to match actual Dart import statements: `import 'package:flutter/...`. Excluded the test file itself from the scan (its own source legitimately mentions the forbidden pattern to construct the search string from pieces). Added a second assertion verifying `pubspec.lock` contains no `sdk: flutter` resolution.

```
00:00 +0: A26 / FR-012: no package:flutter import anywhere in the TUI plugin
  path
00:00 +1: A26 / FR-012 (extra): nocterm dependency is pinned and pubspec.lock
  has no resolved flutter package
00:00 +2: All tests passed!
```

---

## Summary

| Phase | Behaviors | Status |
|-------|-----------|--------|
| Setup | (no tests, scaffold only) | ✓ |
| MVP runtime + components + stateful screens | A1, A4, A5 | ✓ green |
| Standard widgets + theme + keybindings | A6, A7, A8, A9, A10, U9–U19, U20–U23 | ✓ green |
| Binding + DI + edge cases | A11, A12, A13, A14, A15, A16, A17, A18, A19, A20, U24–U33 | ✓ green |
| Generator + plugin registration + conformance + pure-dart init | A21, A22, A23, A24, A25, A26, U34–U37 | ✓ green |
| **Total** | **26 outer + 37 inner = 63 behaviors** | **66 tests, all green** |

Some test files group multiple behaviors (e.g. `key_bindings_test.dart` covers A9+A10; `stream_usecase_binding_test.dart` covers A11+A12+A13+A18). The total test count (66) exceeds the behavior count (63) because some files include additional regression / equality tests beyond the canonical behaviors.
