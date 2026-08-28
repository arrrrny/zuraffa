# Feature Specification: ControlledWidget with FragmentBuilder for Granular Rebuilds

**Feature Branch**: `038-controlled-widget-fragment`

**Created**: 2026-08-28

**Status**: Draft

**Input**: User description: "ControlledWidget with FragmentBuilder for Granular Rebuilds: This feature originates from GitHub issue #173 (https://github.com/arrrrny/zuraffa/issues/173). Add ControlledWidget with FragmentBuilder for granular rebuilds in v6."

## User Scenarios & Testing *(mandatory)*

<!--
  User stories are PRIORITIZED (P1 = most critical). Each is independently
  testable. The "users" here are Zuraffa v6 application developers building
  presentation-layer views that consume state.
-->

### User Story 1 - Build a view with a typed controller and automatic lifecycle (Priority: P1)

A Zuraffa developer creates a view that extends a base widget class providing
typed access to a controller, plus automatic `onInit` and `onDispose` lifecycle
hooks — so the controller is always available, always set up, and always torn down
correctly, without the developer hand-wiring the lifecycle every time.

**Why this priority**: Without a controlled base class, every view must
re-implement controller acquisition and lifecycle management. This is the
foundation all other granularity features build on.

**Independent Test**: A developer subclasses the base widget, provides a
controller type, implements `onInit` and `onDispose`, and runs the view —
confirming the controller is typed, `onInit` fires once on mount, and
`onDispose` fires once on teardown, with no manual wiring.

**Acceptance Scenarios**:

1. **Given** a developer subclasses the base widget with a typed controller,
   **When** the widget mounts, **Then** `onInit` is called exactly once and the
   typed controller is accessible.
2. **Given** a mounted view, **When** the widget is disposed, **Then**
   `onDispose` is called exactly once and the controller is released.
3. **Given** a developer subclass, **When** they access the controller before
   `onInit`, **Then** the framework guarantees the controller is already
   available (no null risk).

---

### User Story 2 - Rebuild only when a specific signal slice changes (Priority: P1)

A Zuraffa developer wraps a portion of a view in a builder widget that
subscribes to a single signal slice and rebuilds only that portion when the
slice's value changes — not when unrelated slices or the full state object
updates.

**Why this priority**: Granular rebuilds are the headline v6 performance win.
Without a slice-scoped builder, views rebuild the entire subtree on any state
change, causing unnecessary frame work. This story delivers the core value of
the feature.

**Independent Test**: A view contains two builder widgets subscribed to two
different signal slices. Changing slice A rebuilds only builder A's subtree.
Changing slice B rebuilds only builder B's subtree. A rebuild counter on each
confirms isolation.

**Acceptance Scenarios**:

1. **Given** a builder widget subscribed to signal slice S1, **When** S1's value
   changes, **Then** only the subtree rendered by that builder is rebuilt.
2. **Given** a builder widget subscribed to signal slice S1, **When** a different
   slice S2 changes, **Then** the builder for S1 is NOT rebuilt.
3. **Given** multiple builder widgets in a view, **When** their respective slices
   all change in the same frame, **Then** each builder rebuilds independently
   and exactly once.

---

### User Story 3 - Present loading, error, and empty states out of the box (Priority: P1)

A Zuraffa developer uses the slice builder widget and provides optional builders
for loading, error, and empty states. The framework automatically renders the
appropriate state builder based on the signal's current status, without the
developer writing manual conditional logic.

**Why this priority**: Loading/error/empty are universal presentation concerns.
Building them into the slice builder eliminates boilerplate and ensures
consistency across all Zuraffa views. This completes the "drop-in" usability of
the builder.

**Independent Test**: A signal slice transitions through idle → loading →
error → empty → data states. At each transition, the correct builder is
rendered and the others are not. Each state is verified in isolation.

**Acceptance Scenarios**:

1. **Given** a signal slice in a loading state, **When** the slice builder
   renders, **Then** the `onLoading` builder is displayed.
2. **Given** a signal slice in an error state, **When** the slice builder
   renders, **Then** the `onError` builder is displayed with access to the
   error information.
3. **Given** a signal slice in an empty/no-data state, **When** the slice builder
   renders, **Then** the `onEmpty` builder is displayed.
4. **Given** a signal slice in a data-available state, **When** the slice builder
   renders, **Then** the data builder is displayed with the slice value.

---

### User Story 4 - Bind pure UI signals (non-domain state) to the view (Priority: P2)

A Zuraffa developer has UI-only state (e.g., "is edit mode on", "search text",
"selected tab") modeled as individual signals. They use a lightweight builder
widget that subscribes to one such signal and rebuilds only on its changes,
separate from the domain-state slice builder.

**Why this priority**: UI-only signals are common but secondary to domain-state
slices. This story keeps the presentation layer clean by distinguishing domain
state builders from UI signal builders.

**Independent Test**: A signal for "is edit mode" toggles; only the signal
builder bound to it rebuilds. A nearby domain-state slice builder is unaffected.

**Acceptance Scenarios**:

1. **Given** a UI signal for a boolean flag (e.g., edit mode), **When** the
   signal's value changes, **Then** only the builder bound to that signal is
   rebuilt.
2. **Given** multiple UI signal builders in a view, **When** one signal changes,
   **Then** only that signal's builder rebuilds; others remain untouched.
3. **Given** a UI signal builder, **When** the underlying signal is disposed, **Then**
   the builder renders nothing or a defined fallback without errors.

---

### User Story 5 - Generate views with the new builder pattern via code generation (Priority: P2)

A Zuraffa developer runs the code generator for an entity and receives a view
that uses the base widget class with a typed controller, fragment builders for
use-case results (domain signal slices), and signal builders for UI state —
following the v6 recommended pattern.

**Why this priority**: Code generation makes the new pattern the default for new
views and eliminates boilerplate. It depends on the core building blocks being
defined first.

**Independent Test**: A developer runs the generator and receives a view file
that compiles, uses the base widget class, and renders slice builders for each
use-case result.

**Acceptance Scenarios**:

1. **Given** an entity with CRUD use cases, **When** the developer generates its
   view, **Then** the generated view extends the base widget class and uses
   slice builders for use-case results.
2. **Given** generated views, **When** compiled, **Then** they produce no errors
   and follow the v6 builder pattern without manual edits.

---

### User Story 6 - Existing views continue to work without changes (Priority: P3)

A Zuraffa developer who has built views using the pre-v6 pattern (combined
state object, full-widget rebuild) does NOT need to modify them when upgrading
to v6. Their existing views compile and run unchanged.

**Why this priority**: Backward compatibility is a migration concern — it must
be guaranteed, but it does not drive new functionality. It is verified after the
new pattern is defined.

**Independent Test**: A pre-v6 view compiled against the v6 framework runs
without changes. Its behavior is identical to pre-v6. No deprecation errors
block compilation.

**Acceptance Scenarios**:

1. **Given** a view written against the pre-v6 API, **When** the project
   upgrades to v6, **Then** the view compiles without errors or required
   changes.
2. **Given** a pre-v6 view, **When** run on v6, **Then** its behavior is
   identical to the pre-v6 version.

---

### Edge Cases

- **Slice emits null or default value**: The slice builder MUST handle a slice
  whose initial or intermediate value is null or the type's default, rendering the
  empty-state builder when the value represents "no data."
- **Controller disposed while async operation is in flight**: When `onDispose`
  fires while an async use-case is still pending, the controller MUST cancel or
  ignore stale results — no state updates on a disposed widget.
- **Multiple slices in a single view, some loading and some ready**: The view
  MUST render each slice's builder independently; a loading slice must NOT block
  a ready slice from rendering its data.
- **Signal builder receives no initial value**: When a UI signal is created
  without an initial value, the signal builder MUST either defer rendering until
  a value is set or render a defined default, not crash.
- **Slice type changes at runtime (dynamic content)**: If a slice's type is
  generic and the concrete type changes (e.g., via a polymorphic response), the
  slice builder MUST handle type mismatch gracefully — either via a defined
  fallback or a clear error, not a silent crash.
- **Rapid successive slice changes (debouncing)**: When a slice emits multiple
  values in quick succession (e.g., user typing), the slice builder MUST either
  rebuild for each value or apply a configurable debounce — the behavior MUST
  be deterministic and documented.
- **FragmentBuilder used outside a ControlledWidget**: If a developer places a
  slice builder outside the base widget's tree, it MUST produce a clear,
  actionable error rather than silently failing or throwing a runtime exception.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST provide a `ControlledWidget<C>` base class that
  gives subclasses typed access to a controller `C` and exposes `onInit` and
  `onDispose` lifecycle hooks that the framework invokes at the appropriate
  widget lifecycle points.
- **FR-002**: The system MUST provide a `FragmentBuilder<S>` widget that accepts
  a signal slice of type `S`, subscribes to its value, and rebuilds only its
  own subtree when the slice's value changes — not when other slices or the
  parent state object changes.
- **FR-003**: `FragmentBuilder` MUST support optional `onLoading`, `onError`,
  and `onEmpty` builder callbacks and render the appropriate one based on the
  slice's current status (loading, error with error information, or
  empty/no-data).
- **FR-004**: The system MUST provide a `SignalBuilder` widget that accepts a
  single UI signal (e.g., `Signal<bool>`, `Signal<String>`) and rebuilds only
  its subtree when that signal's value changes — separate from domain-state
  slice builders.
- **FR-005**: The code generator (`zfa make`) MUST produce views that extend
  `ControlledWidget`, use `FragmentBuilder` for use-case results, and use
  `SignalBuilder` for UI-only signals, following the v6 recommended pattern.
- **FR-006**: Views written against the pre-v6 API (combined state object,
  full-widget rebuild) MUST compile and run without modification on v6 — no
  breaking changes to existing view code.
- **FR-007**: `ControlledWidget` MUST ensure the typed controller is available
  to subclasses before `onInit` is called — the controller MUST NOT be null
  or uninitialized at any lifecycle point.
- **FR-008**: The system MUST handle all edge cases listed above (null slice
  values, disposed controller with in-flight async, independent slice rendering,
  missing signal initial values, type changes, rapid successive updates,
  `FragmentBuilder` used outside its required context) with clear, documented
  behavior.

### Key Entities

- **ControlledWidget**: A base widget class providing typed controller access
  and automatic lifecycle management (`onInit`, `onDispose`) for views.
- **Controller**: The typed object that encapsulates a view's business
  logic, use-case invocations, and state management; accessed via
  `ControlledWidget`.
- **FragmentBuilder**: A widget that subscribes to a single signal slice and
  rebuilds its subtree only when that slice's value changes; supports loading,
  error, and empty state builders.
- **SignalSlice**: A reactive data stream scoped to a specific piece of state
  (e.g., one use-case result), allowing fine-grained subscription and rebuild.
- **Signal**: A reactive value wrapper for UI-only state (non-domain), used
  with `SignalBuilder` for lightweight, independent rebuilds.
- **SignalBuilder**: A lightweight widget that subscribes to a single `Signal`
  and rebuilds only when that signal changes; used for UI-only state.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A developer can create a view with a typed controller, lifecycle
  hooks, and slice-scoped rebuilds in under 5 minutes from a generated scaffold,
  with no manual lifecycle wiring or rebuild logic.
- **SC-002**: Changing one signal slice in a view rebuilds only the subtree
  bound to that slice; sibling slice builders and unrelated widgets are NOT
  rebuilt, confirmed by rebuild counting in a test.
- **SC-003**: The code generator produces views that compile without errors,
  use `ControlledWidget` and `FragmentBuilder` for domain slices, and
  `SignalBuilder` for UI signals — verified by compiling the generated output.
- **SC-004**: Existing pre-v6 views compile and run without modification on
  v6; their behavior is identical to pre-v6, verified by running an existing
  pre-v6 view test suite against the v6 framework.

## Assumptions

- **Track 2.1 (Signal Slices) is already available.** `FragmentBuilder` depends
  on the signal slice abstraction defined in Track 2.1; this feature does not
  re-implement or redefine slices.
- **Track 2.2 (Dual-Layer State) is already available.** The separation of
  domain state from UI state that enables `SignalBuilder` vs.
  `FragmentBuilder` is defined in Track 2.2.
- **Existing view API is not removed.** The pre-v6 combined-state view pattern
  continues to work; the new builder pattern is additive, not a replacement.
- **Code generation templates are updated separately.** This feature defines
  the widget contracts and builder APIs; the `zfa make` template changes
  consume these contracts but may be delivered in a follow-up if template work
  is scoped independently.
- **Loading/error/empty states are opt-in.** Developers can omit any of the
  state builders; the framework MUST NOT force a default skeleton or error UI.
- **No performance regression.** Granular rebuilds must not be slower than full
  rebuilds in the common case; the slice subscription mechanism MUST add
  negligible overhead beyond the signal notification itself.
