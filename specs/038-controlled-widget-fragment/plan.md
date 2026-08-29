# Implementation Plan: ControlledWidget with FragmentBuilder for Granular Rebuilds (038-controlled-widget-fragment)

**Branch**: `038-controlled-widget-fragment` | **Date**: 2026-08-29 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/038-controlled-widget-fragment/spec.md`

## Summary

Add the v6 Track 2.4 presentation contracts — `ControlledWidget<C>`,
`FragmentBuilder<S>`, and `SignalBuilder<T>` — to the pure-Dart `zuraffa`
core, together with the minimal mount/lifecycle layer that invokes
`onInit`/`onDispose`, attaches fragments to a view context, and drives
slice-scoped granular rebuilds. The classes fill the three pre-arranged
export slots in `lib/zuraffa.dart` (lines ~443, ~474, ~476) and complete the
v6 builder pattern that `ViewTemplateGenerator` already emits on master.

The core technical approach: define a **pure-Dart reactive mount layer**
(`WidgetHost` + `ViewContext`) that hosts one root `ControlledWidget` and any
number of attached `FragmentBuilder`/`SignalBuilder` nodes. A
`FragmentBuilder` subscribes to exactly one `SignalSlice` (Track 2.1) and
re-invokes only its own state builder (`onLoading`/`onError`/`onEmpty`/
`builder`) when that slice changes; a `SignalBuilder` does the same for one
UI `Signal` (Track 2.2 view state). Rebuild isolation is observable and
testable: every reactive node exposes a `rebuildCount`, so "only the bound
subtree rebuilds" (SC-002) is proven by counting. The generator work (FR-005)
extends the existing `ViewTemplateGenerator` with a `pureDart` mode whose
output compiles and mounts inside this repo, making SC-003's "compile the
generated output" mechanically verifiable in CI, while the default Flutter
emission stays byte-identical (FR-006).

## Technical Context

**Language/Version**: Dart 3.13.2 (stable). Pubspec constraint `sdk: ^3.11.0`;
3.13.2 satisfies it. Pure-Dart root package — **no Flutter SDK and no
`package:flutter` import** anywhere in the new code (repo-wide constraint
established by the pure-Dart core split, issue #495).

**Primary Dependencies**:
- `SignalSlice<T>` (`lib/src/state/slices/signal_slice.dart`, Track 2.1) —
  `listen((T? data, AppFailure? error))`, `data`, `error`, `isLoading`,
  `isDisposed`. `FragmentBuilder` consumes this contract; it does NOT
  re-implement or wrap slices.
- `Signal<T>` / `SignalSubscription` (`lib/src/core/signals/signal.dart`,
  Tracks 1.x/2.2) — eager initial delivery on `listen`, `dispose()` clears
  listeners, `value` throws `StateError` after dispose.
- `DualLayerPresenter` + `DomainState.slice<T>(key)` + `ViewState`
  (`lib/src/state/...`, Track 2.2) — the canonical controller shape the
  generated views drive; `ViewTemplateGenerator` already emits
  `controller.domain.slice(...)` / `controller.view.<signal>` access.
- `AppFailure` (`lib/src/core/failure.dart`) — error type surfaced to
  `onError` builders; `AppFailure.validation` fits the type-mismatch edge
  case.
- `code_builder` + `dart_style` — only touched via the existing
  `ViewTemplateGenerator` (`lib/src/state/generator/view_template_generator.dart`).
- `test: ^1.25.0` — unit + scenario tests, per the TDD profile.

**Storage**: none. The mount layer is in-process, in-memory state. Nothing
is persisted; no I/O beyond the generator writing source files (existing
behavior).

**Testing**: `dart test`. Layout mirrors source: `lib/src/state/widgets/x.dart`
↔ `test/state/widgets/x_test.dart`. Scenario-style acceptance tests that
trace to SC-001..SC-004 live in `test/state/widgets/sc_<NNN>_<slug>_test.dart`.
Red tests are committed in the same commit as the code that turns them green;
the cycle log records the red command and output (per
`.specify/memory/tdd-profile.md`).

**Target Platform**: anywhere Dart runs (the zuraffa package itself: CLI,
CI, hosted tooling). The Flutter rendering of these contracts lives in the
separate `zuraffa_flutter` package, which re-exports the core; nothing in
this feature changes that boundary.

**Project Type**: runtime library (`lib/src/state/widgets/`) + generator
extension (`ViewTemplateGenerator.pureDart` mode) inside the existing CLI
package, exported through the root `lib/zuraffa.dart` barrel.

**Performance Goals**: per-slice-change rebuild cost is O(1) in the number
of attached fragments — one listener invocation, one builder call. No
change to `SignalSlice`/`Signal` notification paths (assumption: "granular
rebuilds must not be slower than full rebuilds"; the notification mechanism
already exists — we only subscribe to it).

**Constraints**:
- Pure-Dart only: no `package:flutter` import in `lib/src/state/widgets/`
  or `lib/src/state/generator/`.
- No breaking changes: `SignalSlice`, `SlicePresenter`, `DualLayerPresenter`,
  `DomainState`, `ViewState`, `StateGenerator`, `ViewTemplateGenerator`
  default (Flutter) output, and all pre-v6 view code must keep compiling and
  running identically (FR-006). The generator's Flutter emission stays
  byte-identical; `pureDart` is an opt-in flag.
- Loading/error/empty builders are opt-in; no default skeleton/error UI is
  forced (spec assumption).
- The three `zuraffa.dart` export slots must be filled in their existing
  positions (comment → real `export` line), preserving file ordering.

**Scale/Scope**: ~4 new source files (~450 LOC with docs), 1 generator
method extended, 3 export lines, ~6 test files (~900 LOC). No schema, no
CLI surface, no new dependencies.

## Constitution Check

`.specify/memory/constitution.md` is an unfilled template (no project
principles recorded), so the general spec-kit gates apply, checked against
this feature:

| Gate | Status | Notes |
|------|--------|-------|
| Test-first | PASS | TDD extension drives the cycle: `tdd/test-list.md` before implementation; red evidence recorded in `tdd/cycle-log.md`. |
| Simplicity / YAGNI | PASS | One mount abstraction (`WidgetHost`/`ViewContext`), three widget contracts, no element-tree inflation engine, no renderer. Builders return opaque `Object?` output hosts interpret. |
| No breaking changes | PASS | Additive only; default generator output unchanged; existing suites re-run green (SC-004). |
| Library-first, documented | PASS | Every public symbol gets dartdoc with a usage example; contracts live under `lib/src/state/widgets/` and are barrel-exported. |
| Pure-Dart boundary | PASS | Zero Flutter imports; `dart analyze` on the touched paths is the gate. |

No violations to justify — Complexity Tracking table not needed.

## Project Structure

### Documentation (this feature)

```text
specs/038-controlled-widget-fragment/
├── spec.md              # Input (draft, pre-existing)
├── plan.md              # This file
├── tasks.md             # /speckit.tasks output
└── tdd/
    ├── test-list.md     # /speckit.tdd.plan output
    ├── cycle-log.md     # red/green evidence per behavior
    └── verification.md  # /speckit.tdd.verify output
```

### Source Code (repository root)

```text
lib/src/state/widgets/
├── widget_host.dart     # WidgetHost + ViewContext + FragmentContextError
├── controlled_widget.dart  # ControlledWidget<C> abstract base
├── fragment_builder.dart   # FragmentBuilder<S> + FragmentState enum
└── signal_builder.dart     # SignalBuilder<T>

lib/src/state/generator/
└── view_template_generator.dart  # + generateView(pureDart: true) mode

lib/zuraffa.dart         # fill 3 commented export slots

test/state/widgets/
├── widget_host_test.dart
├── controlled_widget_test.dart
├── fragment_builder_test.dart
├── signal_builder_test.dart
├── sc_001_typed_controller_lifecycle_test.dart
├── sc_002_slice_isolated_rebuild_test.dart
├── sc_003_generated_view_compiles_test.dart
└── sc_004_pre_v6_compat_test.dart
```

**Structure Decision**: mirror the existing `lib/src/state/` layout — the
widgets belong to the v6 state family (they consume slices/signals from it),
and `test/state/widgets/` mirrors source per the TDD profile. This matches
how Track 2.1–2.3 code is organized.

## Key Design Decisions

1. **Pure-Dart contracts, not Flutter widgets.** Master's `ViewTemplateGenerator`
   emits Flutter source for user apps (imports `zuraffa_flutter`), but the
   core package cannot import Flutter. The core therefore defines the
   reactive contracts + mount semantics; `zuraffa_flutter` remains free to
   wrap them in `StatefulWidget`s. This is why the earlier Track 2.3+2.4
   branch's Flutter-based widget files were never merged — they would break
   the pure-Dart constraint.
2. **Mount model — host + context, no element tree.** `WidgetHost` mounts one
   root `ControlledWidget`: controller is a final field (FR-007 — available
   before `onInit` by construction), `onInit()` fires exactly once on mount,
   `build(context)` runs once (initial wiring), fragments attach via
   `context.attach(...)`, and `unmount()` detaches everything then fires
   `onDispose()` exactly once. A full inflation/reconciliation engine is
   deliberately out of scope (YAGNI).
3. **Fragments are persistent reactive nodes.** A `FragmentBuilder` attaches
   once and re-invokes exactly one state builder per slice emission; its
   last output and a `rebuildCount` are public, making rebuild isolation
   directly assertable (SC-002) and useful to the XRay tooling later.
4. **State precedence in `FragmentBuilder`:** error → loading (when no data
   yet) → empty (`data == null`, or an empty `Iterable`/`Map`/`String`) →
   data. Precedence, the empty definition, and per-emission (non-debounced)
   rebuild semantics are documented in dartdoc — the spec demands
   "deterministic and documented" behavior for rapid updates.
5. **Context requirement is fail-fast.** `context.attach(fragment)` with a
   null/detached context, or a `FragmentBuilder` constructed without a
   mounted `ControlledWidget` above it, throws `FragmentContextError` with
   an actionable message at attach time — not a silent no-op, not a
   `StateError` crash mid-render (FR-008 edge case).
6. **Generator `pureDart` mode.** `generateView(..., pureDart: true)` emits a
   view importing only `package:zuraffa/zuraffa.dart` and using the core
   contracts; the test compiles and mounts it (SC-003 verified by
   `dart analyze` on generated output in a temp package). Default (Flutter)
   output is untouched (FR-006).
7. **`ControlledWidgetDetector` left as-is.** It flags `extends
   ControlledWidget` in *user projects* as legacy v5 usage (informational
   severity). v6 user apps extend the `zuraffa_flutter` wrapper, not the
   core contract, so no false positive is introduced; updating the detector
   is out of scope for this spec (no FR requires it).
