# Implementation Plan: Native TUI Plugin for Zuraffa

**Branch**: `feat/017-tui-plugin` | **Date**: 2026-08-28 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/017-tui-plugin/spec.md`

## Summary

A native, built-in, pure-Dart Zuraffa package that lets app developers build interactive terminal UIs with a single standardized entry point and a declarative component tree — consistent across all Zuraffa apps. The plugin adapts `nocterm` (a proven pure-Dart TUI engine, no `package:flutter`) as its rendering foundation, exposes a declarative component model that mirrors Zuraffa's existing declarative style, ships a standard widget library + shared theming + canonical keyboard defaults with plugin/app override precedence, and wires screens to the existing Zuraffa domain layer (`UseCase` / `StreamUseCase` / repository) via a `Binding` abstraction without introducing a TUI-local data store. Dependencies are resolved through the caller's existing `ZuraffaDIContainer` / `GetIt`. Edge cases (non-TTY, resize, in-flight input with `CancelToken`, engine-init failure, minimal config) are handled with clear messages and graceful degradation. The Zuraffa generator can produce entity list/detail TUI screens wired to that entity's existing use cases.

## Technical Context

**Language/Version**: Dart 3.11+ (SDK `^3.11.0`); the clone builds on Dart 3.13.2 (stable). Pure-Dart package — no Flutter SDK required.

**Primary Dependencies**:
- `nocterm: ^0.9.0` — pure-Dart TUI engine (verified: no `package:flutter` in its pubspec; sdk `>=3.5.0 <4.0.0`). Provides the terminal render loop, raw input, layout primitives, and a Flutter-like component tree.
- Existing `zuraffa` deps reused: `get_it: ^9.2.1` (DI), `meta: ^1.17.0`, `analyzer: 14.1.0` (codegen), `code_builder: ^4.11.1`, `dart_style: ^3.1.12`.

**Storage**: N/A — the TUI plugin has no storage surface of its own. All persistence flows through the existing domain layer (`Repository` / `Datasource`).

**Testing**: `package:test` (Dart native test runner). Tests live under `test/plugins/tui/...` mirroring the source layout. The TDD extension (`specify extension add tdd`) drives the red-green-refactor loop. No `flutter_test` is permitted in the TUI path.

**Target Platform**: Linux / macOS / Windows terminal (any TTY). The plugin detects non-TTY stdout and refuses to start with an actionable message rather than corrupting piped output.

**Project Type**: Built-in plugin for the `zuraffa` library. Discovers via the existing `ZuraffaPlugin` extension point; the same package works for pure-Dart CLIs and `zuraffa_flutter` apps (the engine layer is shared; only the Flutter side ever touches Flutter, and only via `zuraffa_flutter`).

**Performance Goals**: 60 fps render loop, sub-50 ms input-to-frame latency under typical interactive load, zero-copy terminal writes via `nocterm`'s frame buffer. Not a hard gate for v1 — tracked informally.

**Constraints**:
- FR-012: NO `package:flutter` import anywhere in the TUI plugin path (`lib/src/plugins/tui/**`, generated screens, and any test files exercising the TUI).
- FR-008: NO separate DI container — the TUI resolves dependencies through the caller's existing `ZuraffaDIContainer` and its underlying `GetIt` instance.
- FR-007: NO TUI-local data duplication — `Binding` reads/writes through the existing domain source, never caches a parallel copy.
- Generator contract (AGENTS.md): generated entity TUI screens (FR-011) are produced via the existing `zfa` generation pipeline (`zfa entity create` → `zfa make` → `zfa build`), not hand-written. The TUI plugin contributes a `CreateTuiScreensCapability` consumed by `zfa make`.
- Pure-Dart placement rule: the TUI plugin lives in `lib/src/plugins/tui/` of the core `zuraffa` package, not under `zuraffa_flutter`.

**Scale/Scope**: v1 targets interactive single-window TUIs. Web/embedded rendering, graphical output, and multi-window TUIs are explicitly out of scope (per spec Assumptions).

## Constitution Check

The project's `.specify/memory/constitution.md` is still in template form (placeholders), so no project-specific constitution gates apply. The relevant constraints come from:

- `AGENTS.md` → "Generation contract: use the canonical v5 workflow (`zfa entity create` → `zfa make` → `zfa build`); do NOT call `build_runner` directly."
- `AGENTS.md` → "Prefer `zfa make` over `zfa feature`."
- `AGENTS.md` → "Do not hand-create entities. Use `zfa entity create`."
- Spec FR-012 → pure-Dart, no Flutter in TUI path.
- Spec Assumptions → reuse, don't duplicate, the existing architecture (entities / repositories / use cases / DI).

All v1 work below respects these constraints. Code that the `zfa` generator emits for entity TUI screens is produced by adding a capability to the `make` pipeline; no entity files are hand-authored.

## Project Structure

### Documentation (this feature)

```text
specs/017-tui-plugin/
├── spec.md                          # Authoritative input (FR-001…FR-012, SC-001…SC-006)
├── plan.md                          # This file
├── tasks.md                         # Dependency-ordered task list
├── checklists/requirements.md       # Spec quality checklist
└── tdd/
    ├── test-list.md                # Behaviors traced to FRs + SCs
    ├── cycle-log.md                # Red → green → refactor evidence per behavior
    └── verification.md             # Final TDD discipline + mutation evidence audit
```

### Source Code (repository root)

```text
zuraffa/                                       # pure-Dart core package
├── pubspec.yaml                                # + nocterm: ^0.9.0
└── lib/
    ├── zuraffa.dart                            # + export src/plugins/tui/tui_plugin.dart
    └── src/
        └── plugins/tui/
            ├── tui_plugin.dart                 # ZuraffaTuiPlugin (ZuraffaPlugin registration)
            ├── runtime/
            │   ├── zuraffa_tui.dart            # Standardized entry point: ZuraffaTui.run(...)
            │   ├── tui_session.dart            # Running session state + root CancelToken
            │   └── tui_lifecycle.dart          # Boot/render-loop/input/shutdown orchestration
            ├── core/
            │   ├── component.dart              # Base Component (declarative tree node)
            │   ├── build_context.dart          # BuildContext (theme + focus + dispatch)
            │   ├── stateful_screen.dart        # StatefulScreen + setState → re-render
            │   └── state.dart                  # State<T> base
            ├── widgets/
            │   ├── text.dart                   # Text
            │   ├── container.dart              # Container (padding/border)
            │   ├── row.dart                    # Row (horizontal layout)
            │   ├── column.dart                 # Column (vertical layout)
            │   ├── list_view.dart              # ListView (scrollable + selectable)
            │   ├── grid_view.dart              # GridView
            │   ├── table.dart                  # Table
            │   ├── text_input.dart             # TextInput (form field)
            │   ├── scrollable.dart             # Scrollable region
            │   ├── progress.dart              # ProgressIndicator
            │   ├── navigator.dart              # Navigator (push/pop with back behavior)
            │   └── focus_scope.dart            # FocusScope + FocusNode (Tab/Shift+Tab)
            ├── theme/
            │   ├── theme.dart                  # ZuraffaTuiTheme (colors/emphasis/spacing/status)
            │   ├── default_theme.dart          # Default light theme
            │   └── theme_data.dart            # Color/emphasis/status semantic tokens
            ├── input/
            │   ├── key_bindings.dart           # Canonical defaults + plugin/app override precedence
            │   ├── key_event.dart              # ZuraffaTuiKeyEvent (wraps nocterm input)
            │   └── key_action.dart             # Sealed action enum (quit/confirm/navigate/...)
            ├── binding/
            │   ├── binding.dart                # Base Binding<T> (mount/dispose, no store)
            │   ├── stream_usecase_binding.dart # Observes StreamUseCase<Stream<Result<T,F>>
            │   ├── repository_binding.dart     # Observes repository Stream/notifier
            │   └── usecase_result_binding.dart  # Refreshes a UseCase result after dispatch
            ├── di/
            │   └── tui_di_resolver.dart        # Resolves deps via ZuraffaDIContainer.getIt
            ├── edge/
            │   ├── tty_guard.dart              # TTY detection + non-TTY fallback
            │   ├── resize_handler.dart         # Resize relay → reflow
            │   └── engine_init_failure.dart    # Engine-init failure → actionable message
            └── generator/
                ├── tui_screen_generator.dart          # Emits list/detail TUI screen Dart source
                ├── capabilities/
                │   └── create_tui_screens_capability.dart  # zfa make --with=tui hook
                └── builders/
                    └── tui_screen_builder.dart      # code_builder + dart_style pipeline

zuraffa/test/plugins/tui/                      # mirrors lib/src/plugins/tui/ layout
├── runtime/...
├── core/...
├── widgets/...
├── theme/...
├── input/...
├── binding/...
├── di/...
├── edge/...
├── generator/...
└── conformance_test.dart                      # SC-003: shared conformance test (theme + keys + override)
```

### Build/Run Commands

```bash
dart pub get
dart analyze                       # MUST pass: 0 errors in TUI path
dart test                          # Fast unit suite by default
dart test --preset=all             # Full suite (regression + integration + property + benchmark)
dart test test/plugins/tui/        # TUI subset (used by /speckit.tdd.run)
# Codegen (only if entity screens are regenerated):
#   zfa entity create -n Product --field id:String --field name:String --field price:double
#   zfa make Product --preset=crud --with=tui --methods=get,getList,create,update,delete --state --di --test
#   zfa build
```

## Phases

### Phase 0 — Setup
1. Add `nocterm: ^0.9.0` to `pubspec.yaml` dependencies; keep `analyzer: 14.1.0` override (required for codegen compatibility — no `path:` overrides).
2. Run `dart pub get`; confirm resolution succeeds and nocterm brings no `package:flutter` transitively.
3. Create directory skeleton under `lib/src/plugins/tui/` and `test/plugins/tui/`.

### Phase 1 — Runtime + Component Model (MVP slice)
4. Implement `ZuraffaTui.run(rootScreen)` (FR-001): boot, render root, input loop, clean shutdown.
5. Implement `Component` + `BuildContext` + `StatefulScreen` + `setState` (FR-002, FR-003).
6. Tests: lifecycle, declarative tree render, stateful re-render.

### Phase 2 — Standard Widgets + Theming + Keyboard
7. Implement widget library: text, container, row, column, list_view, grid_view, table, text_input, scrollable, progress, navigator, focus_scope (FR-004).
8. Implement `ZuraffaTuiTheme` + `DefaultTheme` (FR-005).
9. Implement `KeyBindings` with canonical defaults + plugin/app override precedence (FR-006).
10. Tests: per-widget behavior + theme application + key-binding precedence.

### Phase 3 — Domain Binding + DI + Edge Cases
11. Implement `Binding<T>` hierarchy: stream / repository / use-case-result (FR-007).
12. Implement `TuiDiResolver` (FR-008): resolve through `ZuraffaDIContainer.getIt`.
13. Implement edge-case handlers: TTY guard, resize, in-flight input with `CancelToken` (child token per dispatched action, root token on quit/dispose), engine-init failure, minimal config (FR-009).

### Phase 4 — Generator Support + Conformance
14. Implement `CreateTuiScreensCapability` + `TuiScreenGenerator` (FR-011): emit list/detail TUI screens wired to the entity's existing use cases.
15. Implement the shared conformance test (SC-003): theme vocabulary + canonical keys + one override + unoverridden defaults retained.
16. Implement pure-Dart init test (SC-006).

### Phase 5 — Verify + Docs
17. `dart analyze` (whole repo) + `dart test` (full TUI subset + smoke of regression).
18. Grep-gate: `rg -n "package:flutter" lib/src/plugins/tui/ test/plugins/tui/` returns nothing.
19. Write `tdd/verification.md` (TDD discipline audit + mutation evidence).
20. Update repo docs: add TUI section to `doc/PLUGIN_DEVELOPMENT.md` and `website/docs/features/` (out of scope for v1 site rebuild — just a stub note in `doc/`).

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| `nocterm` 0.9.0 is pre-1.0 — API may shift | Pin to `^0.9.0` (semver: patches + minors allowed). Wrap all nocterm types behind our own (e.g., `ZuraffaTuiKeyEvent` wraps nocterm's `KeyEvent`), so an upstream break is a one-file fix. |
| `nocterm` depends on `ffi` for raw terminal mode — may fail on environments without a TTY | `TtyGuard` detects non-TTY before booting and either refuses with a clear message or falls back to non-interactive mode (FR-009). |
| TUI tests typically require a real terminal | `nocterm` ships a headless test mode; we drive it via fake key event sequences. All TUI tests run under `dart test` with no PTY allocation. |
| Generator contract from `AGENTS.md` forbids hand-written entities | We only hand-write the TUI *plugin* code; entity screens themselves are produced by adding a `CreateTuiScreensCapability` to the `zfa make` pipeline. The capability emits the screen source via `code_builder`; no entity code is hand-authored. |
| `dart analyze` may flag unused elements during incremental work | Run `dart analyze` after each phase, fix warnings before moving on. |
| Existing repo has ~600 tests — running the full preset is slow | The TDD loop uses `dart test test/plugins/tui/` for tight feedback; final verification runs `dart analyze` (whole repo) + `dart test` (default preset) + the TUI subset. |

## Out of Scope (v1)

- Web/embedded rendering targets, graphical output, multi-window TUIs (per spec Assumptions).
- A visual screen designer / TUI builder GUI.
- Per-app theming marketplace or runtime theme hot-swap (theming is shared; apps may provide a custom `ZuraffaTuiTheme` instance but the vocabulary is fixed).
- Backwards-compat with any pre-existing third-party TUI plugin (this is the canonical built-in).
