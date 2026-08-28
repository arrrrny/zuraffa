# Feature Specification: Native TUI Plugin for Zuraffa

**Feature Branch**: `017-tui-plugin`

**Created**: 2026-08-28

**Status**: Draft

**Input**: User description: "TUI plugin a native built-in TUI plugin that allows developers to build TUI for Zuraffa applications, a standardized implementation across all Zuraffa apps"

## User Scenarios & Testing *(mandatory)*

<!--
  User stories are PRIORITIZED (P1 = most critical). Each is independently
  testable: shipping just one still delivers a viable slice of value.
  The "user" here is a Zuraffa application developer building a TUI for their app.
-->

### User Story 1 - Launch a TUI app with minimal boilerplate (Priority: P1)

A Zuraffa app developer wants to add an interactive terminal UI to their Zuraffa
app without assembling a render loop, input handling, or frame buffer by hand.
They declare a root screen and start the TUI with a single standardized entry
point. The plugin owns the application lifecycle (boot, draw, input event loop,
graceful shutdown).

**Why this priority**: Without a trivial entry point, no other capability is
usable. This is the floor of the MVP and the first thing a developer evaluates.

**Independent Test**: A developer can scaffold a one-screen TUI and run it in a
terminal; the screen renders and responds to quit — with no raw terminal/event
code written by the developer.

**Acceptance Scenarios**:

1. **Given** a Zuraffa app with a declared root screen, **When** the developer
   starts the TUI via the standardized entry point, **Then** the screen renders
   to the terminal and an input event loop is active.
2. **Given** a running TUI, **When** the user triggers the standard quit action,
   **Then** the TUI releases terminal control and the process returns to its
   caller cleanly (no leftover cursor state, no orphaned listeners).

---

### User Story 2 - Compose screens from a standard, declarative component tree (Priority: P1)

A developer builds a screen by composing layout and primitive components
(containers, rows, columns, text, dividers, spacing) in a declarative tree,
mirroring Zuraffa's existing declarative style. Stateful screens re-render when
their state changes.

**Why this priority**: Declarative composition is the core mental model; it is
what makes the plugin feel "native" to Zuraffa and what unlocks everything else.

**Independent Test**: A developer can write a stateful screen that updates its
display when an internal value changes, and visually confirm the change, without
touching the render loop.

**Acceptance Scenarios**:

1. **Given** a screen built from layout and primitive components, **When** the
   component tree is declared, **Then** it renders in the declared layout/order.
2. **Given** a stateful screen, **When** its state mutates, **Then** only the
   affected view updates on the next frame.

---

### User Story 3 - Use standard, reusable widgets consistently across apps (Priority: P2)

A developer reaches for a library of standard widgets — list/grid views, tables,
text input fields, scrollable regions, progress indicators, navigation between
screens, and focus/selection — so every Zuraffa TUI looks and behaves the same
way. They do not re-implement these per app.

**Why this priority**: Reusable widgets are what deliver the "standardized
implementation across all Zuraffa apps" promise and prevent every team from
reinventing lists, tables, and forms.

**Independent Test**: A developer can drop a standard list widget bound to a data
collection into a screen and confirm scrolling/selection works without custom
code.

**Acceptance Scenarios**:

1. **Given** the standard widget library, **When** a developer places a list
   widget bound to a collection, **Then** items render, scroll, and support
   keyboard selection.
2. **Given** a multi-screen app, **When** the developer uses the standard
   navigation widget, **Then** screens push/pop with consistent back behavior.

---

### User Story 4 - Bind screens to Zuraffa domain architecture (Priority: P2)

A developer wires a screen directly to Zuraffa's domain layer: it displays data
from entities/repositories/use cases and dispatches actions back through existing
use cases. UI state reflects domain state; there is no parallel data layer.

**Why this priority**: This is what makes the TUI "native" rather than a foreign
shell — it reuses the app's existing architecture instead of duplicating it.

**Independent Test**: A developer can render a screen backed by a use case output
and perform an action whose result flows through the existing use case, with the
UI updating from the same source of truth.

**Acceptance Scenarios**:

1. **Given** a screen bound to a use case, **When** the underlying domain state
   changes, **Then** the screen reflects the new state without manual plumbing.
2. **Given** an interactive control, **When** the user activates it, **Then** the
   action is dispatched through the existing use case, not a TUI-local handler.

---

### User Story 5 - Consistent theming and keyboard conventions (Priority: P3)

A developer applies a shared theme (colors, emphasis, spacing, status semantics)
and a shared set of keyboard conventions so every Zuraffa TUI is visually and
behaviorally consistent. Branding/status colors are defined once.

**Why this priority**: Consistency is an explicit goal of the feature; theming is
how it is achieved without per-app duplication, but it builds on the widgets.

**Independent Test**: A developer can apply the shared theme to two different
screens and confirm they render with the same color/style vocabulary and the same
quit/confirm key bindings.

**Acceptance Scenarios**:

1. **Given** the shared theme, **When** it is applied to a screen, **Then** colors
   and emphasis follow the defined vocabulary.
2. **Given** standard keyboard conventions and no overrides, **When** a developer
   builds a screen, **Then** quit uses `q` or `Ctrl+C`, confirm uses `Enter`,
   directional navigation uses the arrow keys, and focus navigation uses
   `Tab`/`Shift+Tab`.
3. **Given** plugin- or application-specific key overrides, **When** the overridden
   action is invoked, **Then** the override replaces its shared default, an
   application override wins any conflict with a plugin override, and defaults for
   all other actions remain unchanged.

---

### User Story 6 - Scaffold entity TUI screens via the generator (Priority: P3)

A developer asks the Zuraffa generator to produce TUI list/detail screens for an
existing entity; the generated screens are auto-wired to that entity's
repository/use cases and follow the standard widget + theme conventions.

**Why this priority**: Generation makes the standardized TUI the default for CRUD
apps and removes the most repetitive work, but it depends on the earlier stories.

**Independent Test**: A developer runs the generation command for one entity and
gets a runnable list/detail TUI screen wired to that entity's existing use cases.

**Acceptance Scenarios**:

1. **Given** an existing entity with use cases, **When** the developer generates
   its TUI screens, **Then** a list screen and a detail screen are produced and
   wired to the entity's data layer.
2. **Given** generated screens, **When** they are run, **Then** they use the
   standard widgets and shared theme (no bespoke styling).

---

### Edge Cases

- **Non-interactive output (no TTY / piped stdout)**: The plugin MUST detect a
  non-interactive terminal and either refuse to start with a clear message or fall
  back to a non-interactive mode, rather than hanging or corrupting output.
- **Terminal too small / resize**: The plugin MUST handle a resized or very small
  terminal by relaying the new dimensions and reflowing the layout.
- **Input during an in-flight async action**: The default policy MUST surface the
  in-flight state and accept only `Escape` to cancel and the effective quit binding
  (`q`/`Ctrl+C` unless overridden). All other input is dropped rather than queued;
  the queue limit is therefore zero and no ordering applies. On failure, the plugin
  displays the failure and restores normal input; on cancellation, it reports the
  action as canceled (not failed) and restores normal input; on quit, it cancels the
  action and proceeds with clean shutdown. At boot the TUI lifecycle creates a root
  `CancelToken`; for each dispatched action it creates a child token, passes that
  child to `UseCase.call(..., cancelToken: childToken)`, and cancels the child on
  `Escape` or the root token on quit/disposal so cancellation propagates to every
  in-flight action.
- **Rendering engine unavailable (native deps missing)**: If the underlying TUI
  engine cannot initialize the terminal (missing native libraries, unsupported
  platform), the plugin MUST fail with an actionable message, not a raw crash.
- **App with no entities / minimal config**: The plugin MUST support a TUI built
  from hand-composed screens alone, with no entity scaffolding required.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The plugin MUST provide a single standardized entry point that boots
  a Zuraffa TUI application (initialize, render the root screen, run the input
  event loop, and shut down cleanly).
- **FR-002**: The plugin MUST provide a declarative component model (a composable
  UI tree of layout and primitive components) consistent with Zuraffa's existing
  declarative style.
- **FR-003**: The plugin MUST provide a stateful screen mechanism that re-renders
  affected views when state changes.
- **FR-004**: The plugin MUST ship a library of standard, reusable widgets
  (at minimum: text, layout containers, list/grid view, table, text input,
  scrollable region, progress indicator, navigation, focus/selection).
- **FR-005**: The plugin MUST provide a shared theming system (colors, emphasis,
  spacing, and status semantics) applied uniformly across screens.
- **FR-006**: The plugin MUST define canonical default keys across all Zuraffa TUIs:
  `q` and `Ctrl+C` for quit, `Enter` for confirm, arrow keys for directional
  navigation, and `Tab`/`Shift+Tab` for focus navigation. Plugin-specific overrides
  replace these defaults, application-specific overrides replace both defaults and
  conflicting plugin overrides, and unoverridden actions retain their defaults.
- **FR-007**: The plugin MUST provide a `Binding` that observes one existing domain
  source: a repository/`StreamUseCase` stream, a notifier, or the result of a use
  case refreshed after a dispatched action or explicit refresh. When mounted, the
  `Binding` MUST subscribe or attach the appropriate listener, propagate each
  successful domain value into the screen, and schedule a re-render without a
  developer-written listener, controller, or duplicate data store. On failure it
  MUST expose a renderable failure state while retaining the last successful value;
  a non-terminal source remains subscribed. On screen disposal it MUST unsubscribe
  or remove its listener and cancel any in-flight refresh.
- **FR-008**: The TUI entry point and generated screens MUST resolve dependencies
  through the caller's existing `ZuraffaDIContainer` and its underlying `GetIt`
  instance; they MUST NOT create a separate container. Tests MAY register or
  override bindings through that same caller-supplied container.
- **FR-009**: The plugin MUST handle the edge cases above (non-interactive
  terminal, resize, in-flight input, engine init failure, minimal config).
- **FR-010**: The plugin MUST be distributed as a native, built-in Zuraffa
  package (discoverable and adoptable by any Zuraffa app) rather than a separate
  third-party bolt-on.
- **FR-011**: The plugin MUST support generation of standardized entity TUI
  screens (list/detail) wired to that entity's existing use cases, via the
  Zuraffa generator.
- **FR-012**: The plugin MUST remain pure-Dart compatible so it is usable by
  non-Flutter Zuraffa apps; any engine or rendering path that requires Flutter
  MUST be isolated to the Flutter layer and never forced on pure-Dart consumers.

### Key Entities *(include if feature involves data)*

- **TUI Application**: The running terminal UI instance — owns lifecycle
  (boot/render/input/shutdown) and the root screen.
- **Screen / Component Tree**: The declarative UI definition for a view, composed
  of layout and primitive components plus optional state.
- **Widget**: A reusable, standardized UI building block (list, table, input,
  navigation, etc.) with consistent behavior across apps.
- **Theme**: The shared visual vocabulary (colors, emphasis, spacing, status
  semantics) applied uniformly.
- **Binding**: The link between a screen and Zuraffa domain state/use cases that
  keeps the UI in sync with the source of truth.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A developer can scaffold and run a first TUI screen in under 10
  minutes from an empty Zuraffa app, using only the standardized entry point and
  standard widgets.
- **SC-002**: The fixed common-surface set is list, detail, data-entry form,
  navigation, and status/progress. At least four of these five surfaces (80%) MUST
  be buildable from the standard widget library without raw terminal or
  event-handling code, as recorded by the conformance test or checklist.
- **SC-003**: Two independently built Zuraffa TUIs MUST each pass the same documented
  conformance test or checklist. It independently verifies each TUI uses the shared
  theme vocabulary (colors, emphasis, spacing, and status semantics) and the
  canonical keyboard defaults from FR-006, and verifies one configured override
  takes precedence while unoverridden keys retain their defaults.
- **SC-004**: Screens bound to a use case reflect domain changes without any
  TUI-local data duplication, measured by a test that mutates domain state and
  observes the UI update from the same source.
- **SC-005**: Generated entity TUI screens require zero manual wiring to the
  entity's existing use cases to run.
- **SC-006**: The plugin initializes correctly on a pure-Dart (non-Flutter) Zuraffa
  app and degrades gracefully (clear message, no crash) when the terminal or
  engine is unavailable.

## Assumptions

- **Adaptation target is a proven pure-Dart TUI engine.** We adapt an existing
  Flutter-like terminal UI framework (`nocterm`, a pure-Dart package — confirmed
  no `package:flutter` dependency) as the rendering foundation, rather than
  building a terminal renderer from scratch. This satisfies the "beautiful,
  standardized" goal and the user's intent to reuse an existing package.
- **Pure-Dart placement rule.** Because the engine is pure Dart, the TUI plugin
  lives in the core (non-Flutter) Zuraffa package and is usable by pure-Dart
  apps. Per the user's constraint: if a rendering path ever requires Flutter, that
  path is isolated to `zuraffa_flutter` only and is never forced on pure-Dart
  consumers.
- **Developer audience.** The "user" of this plugin is a Zuraffa application
  developer; success is measured by developer effort and cross-app consistency,
  not end-user metrics.
- **Reuses existing architecture.** Screens bind to the already-generated
  entities/repositories/use cases and existing DI; the plugin adds a presentation
  layer, not a new data layer.
- **Defaults over configuration.** Theme and keyboard conventions ship with
  sensible defaults; per-app overrides are allowed but not required.
- **v1 scope boundaries.** Web/embedded rendering targets, graphical output, and
  multi-window TUIs are out of scope for v1; the focus is interactive terminal
  TUIs for Zuraffa apps.
