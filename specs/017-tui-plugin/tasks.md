# Tasks: Native TUI Plugin for Zuraffa

**Input**: Design documents from `/specs/017-tui-plugin/` (spec.md + plan.md)

**Prerequisites**: plan.md (required), spec.md (required for FR/SC tracing)

**Tests**: Test tasks are mandatory for this feature (TDD extension active; `/speckit.tdd.run` drives the red-green-refactor loop).

**Organization**: Tasks are grouped by feature phase. Within each phase, tasks are ordered by dependency: lower-numbered tasks must complete before higher-numbered ones. Tasks marked `[P]` may run in parallel with their immediate predecessor (different files, no overlap).

## Format: `[ID] [P?] [Phase/US] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **Phase label**: Setup / MVP / Widgets / Theme-Input / Binding-DI-Edge / Generator / Verify

## Path Conventions

- Pure-Dart monorepo with `zuraffa` (core) + `zuraffa_flutter` (Flutter UI).
- TUI plugin lives in `zuraffa/lib/src/plugins/tui/` and `zuraffa/test/plugins/tui/`.
- All paths below are relative to repo root unless prefixed with `zuraffa/`.

---

## Phase 0: Setup (Shared Infrastructure)

**Purpose**: Add `nocterm` dependency, scaffold directories, register the plugin.

- [x] **0.1** [Setup] Add `nocterm: ^0.9.0` to `zuraffa/pubspec.yaml` dependencies; keep the `analyzer: 14.1.0` version override (no `path:` overrides reintroduced). Run `dart pub get` and confirm no `package:flutter` transitive dep.
- [x] **0.2** [Setup] Create directory skeleton: `zuraffa/lib/src/plugins/tui/{runtime,core,widgets,theme,input,binding,di,edge,generator/capabilities,generator/builders}` and the mirror under `zuraffa/test/plugins/tui/`.
- [x] **0.3** [Setup] Add `ZuraffaTuiPlugin` (`tui_plugin.dart`) — minimal `ZuraffaPlugin` subclass that registers TUI capabilities with the generator pipeline. Wire it into the existing plugin discovery list (no functional behaviour yet — registration only).
- [x] **0.4** [Setup] Add `export 'src/plugins/tui/tui_plugin.dart';` to `zuraffa/lib/zuraffa.dart` and any public TUI types via a barrel `tui.dart`.

---

## Phase 1: MVP — Entry Point + Component Model + Stateful Screens

**Purpose**: Deliver User Story 1 + User Story 2 (P1). After this phase, a developer can scaffold a one-screen TUI that renders and responds to quit.

**Test tasks (mandatory — TDD)**:

- [x] **1.1** [MVP/FR-001/SC-001/SC-006] Write `test/plugins/tui/runtime/zuraffa_tui_test.dart`:
  - Given a minimal root `Screen`, when `ZuraffaTui.run(root)` is invoked, then the screen renders to the terminal and the input event loop is active. **RED**: assert `ZuraffaTui` type exists and exposes `run`.
  - Given a running TUI, when the user triggers the standard quit action (`q`), then the TUI releases terminal control and returns cleanly (no leftover cursor state, no orphaned listeners).
  - Given a non-TTY stdout, when `ZuraffaTui.run` is invoked, then it refuses to start with a clear message OR falls back to non-interactive mode (FR-009 edge case — proved in Phase 3 but asserted here for the boot path).
- [x] **1.2** [MVP/FR-002/SC-002] Write `test/plugins/tui/core/component_test.dart`:
  - Given a screen built from layout + primitive components, when the tree is declared, then it renders in the declared layout/order.
  - Given a composed tree, when nocterm renders it, then the output cells match the expected row/column layout.
- [x] **1.3** [MVP/FR-003/SC-002] Write `test/plugins/tui/core/stateful_screen_test.dart`:
  - Given a stateful screen, when its state mutates via `setState`, then only the affected view updates on the next frame.

**Implementation tasks**:

- [x] **1.4** [MVP/FR-001] Implement `runtime/zuraffa_tui.dart`: `ZuraffaTui.run(Screen root, {ZuraffaDIContainer? di, ZuraffaTuiTheme? theme, KeyBindings? keys})` → boots nocterm, renders the root screen, runs the input loop, and shuts down cleanly. Pure-Dart entry point — no Flutter imports.
- [x] **1.5** [MVP/FR-001] Implement `runtime/tui_session.dart`: holds the running session state + the root `CancelToken` (per FR-009 edge case "At boot the TUI lifecycle creates a root CancelToken").
- [x] **1.6** [MVP/FR-001] Implement `runtime/tui_lifecycle.dart`: orchestrates boot → render → input-loop → shutdown; ensures terminal control is released on any exit path (including engine-init failure).
- [x] **1.7** [MVP/FR-002] Implement `core/component.dart`: base `Component` class — a declarative tree node composable with `build(BuildContext)`. Wraps nocterm's `Component` to insulate Zuraffa apps from upstream API drift.
- [x] **1.8** [MVP/FR-002] Implement `core/build_context.dart`: `BuildContext` exposing theme, focus, and dispatch surface.
- [x] **1.9** [MVP/FR-003] Implement `core/stateful_screen.dart` + `core/state.dart`: `StatefulScreen<T>` with `setState(() { ... })` triggering a re-render of affected views only.

---

## Phase 2: Standard Widgets + Theming + Keyboard Defaults

**Purpose**: Deliver User Story 3 + User Story 5 (P2 + P3 widget layer).

**Test tasks (mandatory — TDD)**:

- [x] **2.1** [Widgets/FR-004/SC-002] Write `test/plugins/tui/widgets/list_view_test.dart`: list widget bound to a collection renders, scrolls, and supports keyboard selection.
- [x] **2.2** [Widgets/FR-004/SC-002] Write `test/plugins/tui/widgets/text_input_test.dart`: form field accepts input and exposes a controller value.
- [x] **2.3** [Widgets/FR-004] Write `test/plugins/tui/widgets/navigation_test.dart`: navigator push/pop with consistent back behavior.
- [x] **2.4** [Widgets/FR-004] Write `test/plugins/tui/widgets/table_test.dart` + `grid_view_test.dart` + `progress_test.dart` + `scrollable_test.dart` + `layout_primitives_test.dart` (text, container, row, column, divider, spacer).
- [x] **2.5** [Widgets/FR-004] Write `test/plugins/tui/widgets/focus_scope_test.dart`: Tab/Shift+Tab cycles focus across focusable widgets.
- [x] **2.6** [Theme/FR-005/SC-003] Write `test/plugins/tui/theme/theme_test.dart`: applied theme drives colors, emphasis, spacing, and status semantics; default theme ships with a complete vocabulary.
- [x] **2.7** [Input/FR-006/SC-003] Write `test/plugins/tui/input/key_bindings_test.dart`:
  - Default keys: `q`/`Ctrl+C` quit, `Enter` confirm, arrows navigate, `Tab`/`Shift+Tab` focus.
  - Plugin override replaces the shared default for the overridden action; app override wins any conflict with plugin override; unoverridden actions retain defaults.

**Implementation tasks**:

- [x] **2.8** [Widgets/FR-004] Implement `widgets/text.dart`, `container.dart`, `row.dart`, `column.dart`, `divider.dart`, `spacer.dart`.
- [x] **2.9** [Widgets/FR-004] Implement `widgets/list_view.dart` (scrollable + keyboard-selectable), `grid_view.dart`, `table.dart`.
- [x] **2.10** [Widgets/FR-004] Implement `widgets/text_input.dart` (with controller), `scrollable.dart`, `progress.dart`.
- [x] **2.11** [Widgets/FR-004] Implement `widgets/navigator.dart` (push/pop with consistent back behavior) and `widgets/focus_scope.dart` (focus traversal).
- [x] **2.12** [Theme/FR-005] Implement `theme/theme.dart` + `theme/default_theme.dart` + `theme/theme_data.dart`: `ZuraffaTuiTheme` with colors, emphasis, spacing, status semantic tokens.
- [x] **2.13** [Input/FR-006] Implement `input/key_bindings.dart` + `input/key_event.dart` + `input/key_action.dart`: canonical defaults + `KeyBindings.merge(plugin: ..., app: ...)` precedence (app wins conflicts; plugin replaces defaults; unoverridden actions keep defaults).

---

## Phase 3: Domain Binding + DI + Edge Cases

**Purpose**: Deliver User Story 4 (P2 — domain binding) + FR-007, FR-008, FR-009.

**Test tasks (mandatory — TDD)**:

- [x] **3.1** [Binding/FR-007/SC-004] Write `test/plugins/tui/binding/stream_usecase_binding_test.dart`:
  - Subscribes to a `StreamUseCase<Stream<Result<T, F>>>`; on each successful domain value, propagates into the screen and schedules a re-render without a developer-written listener.
  - On failure, exposes a renderable failure state while retaining the last successful value; non-terminal source remains subscribed.
  - On screen disposal, unsubscribes and cancels any in-flight refresh.
- [x] **3.2** [Binding/FR-007/SC-004] Write `test/plugins/tui/binding/usecase_result_binding_test.dart`: refreshes a `UseCase` result after a dispatched action / explicit refresh.
- [x] **3.3** [Binding/FR-007] Write `test/plugins/tui/binding/repository_binding_test.dart`: observes a repository stream / notifier.
- [x] **3.4** [DI/FR-008] Write `test/plugins/tui/di/tui_di_resolver_test.dart`: resolves dependencies through the caller-supplied `ZuraffaDIContainer`/`GetIt`; tests MAY register or override bindings through that same container; no separate container is created.
- [x] **3.5** [Edge/FR-009/SC-006] Write `test/plugins/tui/edge/tty_guard_test.dart`: non-TTY → refuse with clear message OR fall back; piped stdout not corrupted.
- [x] **3.6** [Edge/FR-009] Write `test/plugins/tui/edge/resize_handler_test.dart`: terminal resize relays new dimensions and reflows layout.
- [x] **3.7** [Edge/FR-009] Write `test/plugins/tui/edge/inflight_input_test.dart`: in-flight async action — only `Escape` (cancel) and the effective quit binding are accepted; all other input dropped (queue limit 0); on failure displays failure and restores normal input; on cancellation reports action as canceled (not failed); on quit cancels the action and proceeds with clean shutdown. Root `CancelToken` created at boot; child token per dispatched action, propagated via `UseCase.call(..., cancelToken: childToken)`; root token cancelled on quit/dispose.
- [x] **3.8** [Edge/FR-009] Write `test/plugins/tui/edge/engine_init_failure_test.dart`: engine cannot init (missing native libs / unsupported platform) → actionable message, no raw crash.
- [x] **3.9** [Edge/FR-009] Write `test/plugins/tui/edge/minimal_config_test.dart`: TUI built from hand-composed screens alone, no entity scaffolding required.

**Implementation tasks**:

- [x] **3.10** [Binding/FR-007] Implement `binding/binding.dart` (base `Binding<T>` — `mount`, `dispose`, no store), `binding/stream_usecase_binding.dart`, `binding/usecase_result_binding.dart`, `binding/repository_binding.dart`.
- [x] **3.11** [DI/FR-008] Implement `di/tui_di_resolver.dart`: resolves types via `ZuraffaDIContainer.getIt`; accepts the caller's container at `ZuraffaTui.run` time.
- [x] **3.12** [Edge/FR-009] Implement `edge/tty_guard.dart`, `edge/resize_handler.dart`, `edge/engine_init_failure.dart`. Wire the root `CancelToken` + per-action child tokens into `runtime/tui_lifecycle.dart` and `binding/usecase_result_binding.dart`.

---

## Phase 4: Generator Support + Conformance

**Purpose**: Deliver User Story 6 (P3 — generator) + SC-003, SC-005, SC-006.

**Test tasks (mandatory — TDD)**:

- [x] **4.1** [Generator/FR-011/SC-005] Write `test/plugins/tui/generator/tui_screen_generator_test.dart`: given an existing entity with use cases, generating its TUI screens produces a list screen + a detail screen wired to that entity's data layer; generated screens require zero manual wiring to run.
- [x] **4.2** [Generator/FR-011] Write `test/plugins/tui/generator/create_tui_screens_capability_test.dart`: the `zfa make --with=tui` capability is discovered and invokes the generator with the correct entity metadata.
- [x] **4.3** [Conformance/SC-003] Write `test/plugins/tui/conformance_test.dart`: a single shared test that two independently built Zuraffa TUIs each pass — verifies shared theme vocabulary (colors, emphasis, spacing, status semantics), canonical keyboard defaults from FR-006, one configured override takes precedence while unoverridden keys retain their defaults.
- [x] **4.4** [Pure-Dart/SC-006/FR-012] Write `test/plugins/tui/pure_dart_init_test.dart`: the plugin initializes correctly on a pure-Dart (non-Flutter) Zuraffa app; degrades gracefully when terminal/engine unavailable.

**Implementation tasks**:

- [x] **4.5** [Generator/FR-011] Implement `generator/tui_screen_generator.dart` + `generator/builders/tui_screen_builder.dart`: emits list + detail TUI screen Dart source via `code_builder` + `dart_style`; output is pure-Dart (no `package:flutter`).
- [x] **4.6** [Generator/FR-011] Implement `generator/capabilities/create_tui_screens_capability.dart`: hooks into the `zfa make` pipeline via the existing `ZuraffaPlugin` capability surface so `--with=tui` triggers TUI screen generation. Generated screens are wired to the entity's existing use cases (auto-resolved from the entity's `useCases` manifest).
- [x] **4.7** [Conformance] Implement the shared `conformance_test.dart` referenced above (used by both example apps + as a repo-level SC-003 gate).

---

## Phase 5: Verify + Docs

**Purpose**: Final verification + minimal docs.

- [x] **5.1** [Verify] `dart analyze` (whole repo) → 0 errors in the TUI path. Warnings acceptable if pre-existing in unrelated files; flag them in the verification report.
- [x] **5.2** [Verify] `dart test` (default fast preset) + `dart test test/plugins/tui/` → all green. Report ACTUAL pass/fail counts.
- [x] **5.3** [Verify/FR-012] Grep-gate: `rg -n "package:flutter" zuraffa/lib/src/plugins/tui/ zuraffa/test/plugins/tui/` returns zero hits.
- [x] **5.4** [Verify/SC-001…SC-006] Write `specs/017-tui-plugin/tdd/verification.md` mapping each SC to PROVED / NOT-PROVED with concrete test file references.
- [x] **5.5** [Docs] Add a `doc/TUI_PLUGIN.md` quickstart (scaffold <10 min, single screen example, list/detail example, generator example).
- [x] **5.6** [Docs] Add a stub entry to `doc/PLUGIN_DEVELOPMENT.md` pointing to the TUI quickstart.
- [x] **5.7** [Wiring] Re-export all public TUI types from `zuraffa/lib/zuraffa.dart` via a `tui.dart` barrel so `import 'package:zuraffa/zuraffa.dart';` is the only import a developer needs.

---

## Task Dependency Graph (high-level)

```
Phase 0 (Setup)
   ↓
Phase 1 (MVP — runtime + components + stateful screens)
   ↓
   ├───────────────┐
   ↓               ↓
Phase 2          Phase 3 (Binding+DI+Edge can start once MVP slice is green;
(Widgets+                Binding depends on UseCase/StreamUseCase contracts only)
 Theme+Input)
   ↓               ↓
   └───────┬───────┘
           ↓
       Phase 4 (Generator + Conformance)
           ↓
       Phase 5 (Verify + Docs)
```

## Acceptance Criteria → Task Traceability

| Spec Ref | Tasks Covering It |
|----------|-------------------|
| FR-001 (entry point) | 1.1, 1.4, 1.5, 1.6 |
| FR-002 (declarative tree) | 1.2, 1.7, 1.8 |
| FR-003 (stateful screens) | 1.3, 1.9 |
| FR-004 (widget library) | 2.1–2.5, 2.8–2.11 |
| FR-005 (theming) | 2.6, 2.12 |
| FR-006 (keyboard defaults + override precedence) | 2.7, 2.13 |
| FR-007 (Binding) | 3.1–3.3, 3.10 |
| FR-008 (DI) | 3.4, 3.11 |
| FR-009 (edge cases) | 3.5–3.9, 3.12 |
| FR-010 (built-in package) | 0.3, 0.4, 5.7 |
| FR-011 (generator) | 4.1, 4.2, 4.5, 4.6 |
| FR-012 (pure-Dart, no Flutter) | 0.1, 4.4, 5.3 (cross-cutting; every implementation task) |
| SC-001 (scaffold <10 min) | 1.1, 5.5 |
| SC-002 (≥4/5 standard surfaces) | 2.1–2.5, conformance 4.3 |
| SC-003 (conformance test) | 2.6, 2.7, 4.3, 4.7 |
| SC-004 (no TUI-local duplication) | 3.1, 3.2, 3.3 |
| SC-005 (generated screens zero wiring) | 4.1, 4.5 |
| SC-006 (pure-Dart init + graceful degradation) | 1.1, 3.5, 3.8, 4.4 |
