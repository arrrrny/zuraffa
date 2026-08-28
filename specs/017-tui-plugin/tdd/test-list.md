# TDD Test List: Native TUI Plugin for Zuraffa

**Feature**: `017-tui-plugin`
**Branch**: `feat/017-tui-plugin`
**Base Commit**: `master` HEAD at clone time
**Date**: 2026-08-28
**TDD Stack**: `dart test` (Dart native), no `flutter_test`. Tests live under `zuraffa/test/plugins/tui/...` mirroring the source layout.

> Each behavior is one line, traced to the FR(s) and SC(s) it proves. The `/speckit.tdd.run` loop drives these red → green → refactor one behavior at a time and records evidence in `tdd/cycle-log.md`.

---

## Outer Acceptance Behaviors (one per FR / SC, end-to-end)

| ID | Behavior | Trace | Test File |
|----|----------|-------|-----------|
| **A1** | `ZuraffaTui.run(root)` boots the TUI: renders the root screen to the terminal and runs an active input event loop. | FR-001, SC-001, SC-006 | `test/plugins/tui/runtime/zuraffa_tui_test.dart` |
| **A2** | Triggering the standard quit action (`q`) releases terminal control and returns to the caller cleanly (no leftover cursor state, no orphaned listeners). | FR-001, FR-006 | `test/plugins/tui/runtime/zuraffa_tui_test.dart` |
| **A3** | `Ctrl+C` is also a canonical quit (second default), with the same clean shutdown semantics as `q`. | FR-006 | `test/plugins/tui/runtime/zuraffa_tui_test.dart` |
| **A4** | A screen built from layout + primitive components renders in the declared layout/order. | FR-002, SC-002 | `test/plugins/tui/core/component_test.dart` |
| **A5** | A stateful screen's `setState` triggers a re-render of only the affected view. | FR-003, SC-002 | `test/plugins/tui/core/stateful_screen_test.dart` |
| **A6** | A `ListView` bound to a collection renders items, scrolls, and supports keyboard selection. | FR-004, SC-002 | `test/plugins/tui/widgets/list_view_test.dart` |
| **A7** | A `Navigator` push/pop produces consistent back behavior across screens. | FR-004 | `test/plugins/tui/widgets/navigation_test.dart` |
| **A8** | Applying the shared `ZuraffaTuiTheme` to a screen drives colors, emphasis, spacing, and status semantics uniformly. | FR-005, SC-003 | `test/plugins/tui/theme/theme_test.dart` |
| **A9** | Default key bindings: `q`/`Ctrl+C` quit, `Enter` confirm, arrow keys navigate, `Tab`/`Shift+Tab` focus. | FR-006, SC-003 | `test/plugins/tui/input/key_bindings_test.dart` |
| **A10** | A plugin key override replaces the default for the overridden action; an app override wins any conflict with a plugin override; unoverridden actions retain their defaults. | FR-006, SC-003 | `test/plugins/tui/input/key_bindings_test.dart` |
| **A11** | A `StreamUseCaseBinding` subscribes to a `StreamUseCase`, propagates each successful domain value into the screen, and schedules a re-render — with NO developer-written listener and NO TUI-local duplicate store. | FR-007, SC-004 | `test/plugins/tui/binding/stream_usecase_binding_test.dart` |
| **A12** | On stream failure, the binding exposes a renderable failure state while retaining the last successful value; a non-terminal source remains subscribed. | FR-007 | `test/plugins/tui/binding/stream_usecase_binding_test.dart` |
| **A13** | On screen disposal, the binding unsubscribes and cancels any in-flight refresh. | FR-007, FR-009 | `test/plugins/tui/binding/stream_usecase_binding_test.dart` |
| **A14** | The TUI resolves dependencies through the caller-supplied `ZuraffaDIContainer`/`GetIt`; it does NOT create a separate container; tests MAY register/override through that same container. | FR-008 | `test/plugins/tui/di/tui_di_resolver_test.dart` |
| **A15** | Non-TTY stdout: the plugin refuses to start with a clear message (or falls back to non-interactive mode), rather than hanging or corrupting output. | FR-009, SC-006 | `test/plugins/tui/edge/tty_guard_test.dart` |
| **A16** | Terminal resize: new dimensions are relayed and the layout reflows. | FR-009 | `test/plugins/tui/edge/resize_handler_test.dart` |
| **A17** | In-flight input: only `Escape` (cancel) and the effective quit binding are accepted; all other input is dropped (queue limit 0). On failure: displays failure, restores normal input. On cancel: reports action as canceled (not failed), restores normal input. On quit: cancels the action and proceeds with clean shutdown. | FR-009, FR-007 (CancelToken), SC-006 | `test/plugins/tui/edge/inflight_input_test.dart` |
| **A18** | At boot, the TUI creates a root `CancelToken`; for each dispatched action it creates a child token, passes that child to `UseCase.call(..., cancelToken: childToken)`, and cancels the child on `Escape` or the root token on quit/disposal — so cancellation propagates to every in-flight action. | FR-009, FR-007 | `test/plugins/tui/edge/inflight_input_test.dart` |
| **A19** | Engine-init failure (missing native libs / unsupported platform): actionable message, no raw crash. | FR-009, SC-006 | `test/plugins/tui/edge/engine_init_failure_test.dart` |
| **A20** | A TUI built from hand-composed screens alone (no entity scaffolding) runs. | FR-009, FR-010 | `test/plugins/tui/edge/minimal_config_test.dart` |
| **A21** | The plugin is shipped as a built-in Zuraffa package (discoverable via `ZuraffaPlugin` registration; exported from `package:zuraffa/zuraffa.dart`). | FR-010 | `test/plugins/tui/plugin_registration_test.dart` |
| **A22** | Generating TUI screens for an existing entity produces a list screen + a detail screen, both wired to that entity's existing use cases — with zero manual wiring to run. | FR-011, SC-005 | `test/plugins/tui/generator/tui_screen_generator_test.dart` |
| **A23** | The `zfa make --with=tui` capability is discovered and emits the list+detail screen source via `code_builder`+`dart_style`. | FR-011, AGENTS.md | `test/plugins/tui/generator/create_tui_screens_capability_test.dart` |
| **A24** | Two independently built Zuraffa TUIs each pass the same shared conformance test (theme vocabulary + canonical keys + one override takes precedence + unoverridden keys retain defaults). | SC-003 | `test/plugins/tui/conformance_test.dart` |
| **A25** | The plugin initializes correctly on a pure-Dart (non-Flutter) Zuraffa app and degrades gracefully when the terminal/engine is unavailable. | SC-006, FR-012 | `test/plugins/tui/pure_dart_init_test.dart` |
| **A26** | The TUI plugin path contains NO `package:flutter` import (pure-Dart, FR-012). | FR-012 | `test/plugins/tui/no_flutter_import_test.dart` (static grep test) |

---

## Inner Unit Behaviors (per-component, derived from outer behaviors)

### Runtime + Lifecycle

| ID | Behavior | Component | Trace |
|----|----------|-----------|-------|
| **U1** | `ZuraffaTui` is a public type with a `static Future<void> run(Screen, {di, theme, keys})` entry point. | `ZuraffaTui` | FR-001 |
| **U2** | `TuiSession` holds the running session state + a root `CancelToken`. | `TuiSession` | FR-009 |
| **U3** | `TuiLifecycle.boot()` initializes nocterm; on any failure throws `TuiEngineInitException` with an actionable message. | `TuiLifecycle` | FR-009 |
| **U4** | `TuiLifecycle.shutdown()` releases terminal control on every exit path (normal quit, error, dispose). | `TuiLifecycle` | FR-001 |

### Component Model

| ID | Behavior | Component | Trace |
|----|----------|-----------|-------|
| **U5** | `Component.build(BuildContext)` returns a declarative tree of children. | `Component` | FR-002 |
| **U6** | `BuildContext.theme` exposes the active `ZuraffaTuiTheme`. | `BuildContext` | FR-005 |
| **U7** | `BuildContext.dispatch(action)` dispatches a `KeyAction` to the active handler chain. | `BuildContext` | FR-006 |
| **U8** | `StatefulScreen<T>.setState(() { ... })` schedules a re-render of the affected view; unrelated views are not invalidated. | `StatefulScreen` | FR-003 |

### Widgets

| ID | Behavior | Component | Trace |
|----|----------|-----------|-------|
| **U9** | `Text(content)` renders its content with theme-driven emphasis. | `Text` | FR-004, FR-005 |
| **U10** | `Container({padding, border})` wraps a child with padding and an optional border. | `Container` | FR-004 |
| **U11** | `Row(children)` lays out children horizontally; `Column(children)` vertically. | `Row`, `Column` | FR-004 |
| **U12** | `ListView(items)` renders a scrollable list, supports arrow-key selection, and exposes `onSelect`. | `ListView` | FR-004, SC-002 |
| **U13** | `GridView(crossAxisCount, items)` lays out items in a grid. | `GridView` | FR-004 |
| **U14** | `Table(headers, rows)` renders a fixed-header table with column-aligned cells. | `Table` | FR-004 |
| **U15** | `TextInput(controller)` accepts input, exposes the controller's current value, and supports focus. | `TextInput` | FR-004, SC-002 |
| **U16** | `Scrollable(child)` wraps a child in a scrollable region. | `Scrollable` | FR-004 |
| **U17** | `Progress(value: 0..1)` renders a progress bar with status semantic color. | `Progress` | FR-004, FR-005 |
| **U18** | `Navigator.push(screen)` / `Navigator.pop()` produce consistent back behavior. | `Navigator` | FR-004 |
| **U19** | `FocusScope` cycles focus across focusable children on `Tab` / `Shift+Tab`. | `FocusScope` | FR-004, FR-006 |

### Theme + Input

| ID | Behavior | Component | Trace |
|----|----------|-----------|-------|
| **U20** | `ZuraffaTuiTheme.defaultTheme()` returns a complete vocabulary: colors, emphasis, spacing, status semantics. | `ZuraffaTuiTheme` | FR-005, SC-003 |
| **U21** | `KeyBindings.defaults` returns `q`/`Ctrl+C` quit, `Enter` confirm, arrows navigate, `Tab`/`Shift+Tab` focus. | `KeyBindings` | FR-006 |
| **U22** | `KeyBindings.merge(defaults, plugin, app)`: plugin override replaces the default for the same action; app override wins conflicts with plugin override; unoverridden actions keep their defaults. | `KeyBindings` | FR-006, SC-003 |
| **U23** | `ZuraffaTuiKeyEvent` wraps a nocterm key event and exposes `isQuit`, `isConfirm`, `isCancel`, `direction`, etc., via the active `KeyBindings`. | `ZuraffaTuiKeyEvent` | FR-006 |

### Binding

| ID | Behavior | Component | Trace |
|----|----------|-----------|-------|
| **U24** | `Binding<T>.mount()` subscribes/attaches to its source and propagates successful values into the screen via `onValue`. | `Binding<T>` | FR-007 |
| **U25** | `Binding<T>.dispose()` unsubscribes and cancels any in-flight refresh. | `Binding<T>` | FR-007, FR-009 |
| **U26** | `StreamUseCaseBinding<T, P>` subscribes to `StreamUseCase<T, P>.call(params, cancelToken: ...)`. | `StreamUseCaseBinding` | FR-007, SC-004 |
| **U27** | `RepositoryBinding<T>` observes a repository's stream/notifier. | `RepositoryBinding` | FR-007 |
| **U28** | `UseCaseResultBinding<T, P>` refreshes a `UseCase<T, P>` result after a dispatched action or explicit refresh. | `UseCaseResultBinding` | FR-007 |

### DI + Edge Cases

| ID | Behavior | Component | Trace |
|----|----------|-----------|-------|
| **U29** | `TuiDiResolver(di: ZuraffaDIContainer).get<T>()` resolves `T` via `di.getIt`. | `TuiDiResolver` | FR-008 |
| **U30** | The resolver does NOT call `GetIt.asNewInstance()` or otherwise create a separate container. | `TuiDiResolver` | FR-008 |
| **U31** | `TtyGuard.isTty()` returns false on piped stdout; `TtyGuard.requireTty()` throws `TuiNonTtyException` with a clear message. | `TtyGuard` | FR-009, SC-006 |
| **U32** | `ResizeHandler` relays new dimensions to its listeners on terminal SIGWINCH. | `ResizeHandler` | FR-009 |
| **U33** | `EngineInitFailure` carries an actionable message; `TuiLifecycle` converts init failure to `EngineInitFailure`, never a raw crash. | `EngineInitFailure` | FR-009, SC-006 |

### Generator

| ID | Behavior | Component | Trace |
|----|----------|-----------|-------|
| **U34** | `TuiScreenGenerator.generateListScreen(entity)` emits a Dart file declaring a list screen wired to the entity's `getList` use case. | `TuiScreenGenerator` | FR-011, SC-005 |
| **U35** | `TuiScreenGenerator.generateDetailScreen(entity)` emits a Dart file declaring a detail screen wired to the entity's `get` use case. | `TuiScreenGenerator` | FR-011, SC-005 |
| **U36** | Generated screens use only `package:zuraffa/...` and `package:nocterm/...` imports — no `package:flutter`. | `TuiScreenGenerator` | FR-012 |
| **U37** | `CreateTuiScreensCapability` is discovered by `zfa make --with=tui` and invokes the generator with the correct entity metadata. | `CreateTuiScreensCapability` | FR-011, AGENTS.md |

---

## Test-First Discipline Notes

- **One behavior per test file (preferred)** — when a behavior requires multiple test cases (e.g. A9 + A10 both exercise `KeyBindings`), they live in the same file but as distinct `test('…', …)` blocks.
- **RED phase evidence**: each behavior's first commit shows the test failing for the right reason (missing symbol, wrong return value, throw), recorded in `tdd/cycle-log.md` with the failure output snippet.
- **GREEN phase evidence**: the smallest change that flips the test to green, recorded in `tdd/cycle-log.md` with the passing output.
- **REFACTOR**: while green, extract helpers / dedupe; re-run green to confirm no regression.
- **No `package:flutter` import** anywhere in `lib/src/plugins/tui/` or `test/plugins/tui/` — enforced statically by `no_flutter_import_test.dart` (A26) and by the grep-gate in CI.
- **Generator discipline** (AGENTS.md): the entity screens themselves are produced by `CreateTuiScreensCapability` via `code_builder`+`dart_style`; no entity code is hand-authored. The capability is invoked via `zfa make --with=tui` (mocked at the test level — the real CLI invocation requires a sample entity, which is out of scope for v1 verification).

---

## Acceptance Criteria Coverage Matrix

| SC | Outer Behaviors Proving It |
|----|----------------------------|
| SC-001 (scaffold <10 min) | A1, A2 (+ manual scaffold time tracking in `doc/TUI_PLUGIN.md`) |
| SC-002 (≥4/5 standard surfaces) | A4, A5, A6, A7, A15 + U9-U19 (5/5 surfaces: list, detail via generator, data-entry form, navigation, status/progress) |
| SC-003 (conformance test) | A8, A9, A10, A24 |
| SC-004 (no TUI-local duplication) | A11, A12, A13, U26 |
| SC-005 (generated screens zero wiring) | A22, A23, U34, U35 |
| SC-006 (pure-Dart init + graceful degradation) | A1, A15, A19, A25, A26 |
