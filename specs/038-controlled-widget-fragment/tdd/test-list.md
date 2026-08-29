---
feature: 038-controlled-widget-fragment
loop: outside-in
profile: .specify/memory/tdd-profile.md
spec_criteria: 4 # SC-001..SC-004 in spec.md "Success Criteria"; 16 story-level acceptance scenarios traced through the inner loop
planned_at: 4c1c2641
updated_at: post-implementation (all behaviors DONE)
suite_baseline: green # `dart test test/state` -> 68 passed, 0 failed at 4c1c2641; full-suite baseline running in parallel, feature scope is the gate per profile
---

# Test List: ControlledWidget with FragmentBuilder for Granular Rebuilds

## Outer loop: acceptance behaviors

One per success criterion in `spec.md`. Each stays red until the feature works
end to end through its real entry point — the public `package:zuraffa`
surface (widget contracts + mount layer) and the generator pipeline.

| id  | behavior                                                                                                                            | traces  | kind    | state   | test |
| --- | ----------------------------------------------------------------------------------------------------------------------------------- | ------- | ------- | ------- | ---- |
| A1  | A developer-style view with a typed controller mounts, auto-fires `onInit` → slice refresh → data render, with zero manual lifecycle/subscription wiring | SC-001  | example | DONE | `test/state/widgets/sc_001_typed_controller_lifecycle_test.dart::A1` |
| A2  | Changing one signal slice rebuilds only the subtree bound to that slice; the sibling fragment and the parent view do not rebuild (rebuild counting) | SC-002  | example | DONE | `test/state/widgets/sc_002_slice_isolated_rebuild_test.dart::A2` |
| A3  | `zfa make`-style generation produces a view that compiles (dart-analyzed) and uses `ControlledWidget` + `FragmentBuilder` + `SignalBuilder` | SC-003  | example | DONE | `test/state/widgets/sc_003_generated_view_compiles_test.dart::U23/U25` |
| A4  | A pre-v6 pattern view (SlicePresenter + `combinedState`, full-rebuild, no widget layer) compiles and behaves identically on v6            | SC-004  | example | DONE | `test/state/widgets/sc_004_pre_v6_compat_test.dart::A4` |

## Inner loop: unit behaviors

Grouped by the component from `plan.md` that owns them.

### `lib/src/state/widgets/widget_host.dart` (WidgetHost, ViewContext, FragmentContextError)

| id  | behavior                                                                                                        | traces             | kind    | state   | test |
| --- | --------------------------------------------------------------------------------------------------------------- | ------------------ | ------- | ------- | ---- |
| U1  | `mount()` invokes `onInit` exactly once and `build(context)` exactly once                                        | FR-001, US1-S1     | example | DONE | `test/state/widgets/widget_host_test.dart::mount() invokes onInit` |
| U2  | The typed controller is non-null and accessible inside `onInit` — set before any lifecycle hook runs             | FR-007, US1-S3     | example | DONE | `test/state/widgets/widget_host_test.dart::controller is non-null` |
| U3  | `unmount()` invokes `onDispose` exactly once; a second `unmount()` is a no-op (no double-dispose)                | FR-001, US1-S2     | example | DONE | `test/state/widgets/widget_host_test.dart::unmount() invokes onDispose` |
| U4  | Attaching a fragment with a detached/absent ViewContext throws `FragmentContextError` with an actionable message  | FR-008 (edge: outside context) | example | DONE | `test/state/widgets/widget_host_test.dart::attaching to a detached context` |
| U5  | `unmount()` detaches all attached fragments; slice emissions after unmount trigger no rebuilds and no state errors | FR-008 (edge: disposed controller, in-flight async) | example | DONE | `test/state/widgets/widget_host_test.dart::unmount() detaches every` |

### `lib/src/state/widgets/controlled_widget.dart` (ControlledWidget\<C\>)

| id  | behavior                                                                                          | traces         | kind    | state   | test |
| --- | ------------------------------------------------------------------------------------------------- | -------------- | ------- | ------- | ---- |
| U6  | A subclass accesses the controller with the declared static type `C` (no cast) in `onInit`/`build` | FR-001, FR-007 | example | DONE | `test/state/widgets/controlled_widget_test.dart::subclass reads the controller` |
| U7  | A subclass that overrides nothing mounts and unmounts cleanly on the default no-op hooks          | FR-001         | example | DONE | `test/state/widgets/controlled_widget_test.dart::default hooks are no-ops` |

### `lib/src/state/widgets/fragment_builder.dart` (FragmentBuilder\<S\>)

| id  | behavior                                                                                                                | traces                     | kind    | state   | test |
| --- | ----------------------------------------------------------------------------------------------------------------------- | -------------------------- | ------- | ------- | ---- |
| U8  | A slice-A emission increments fragment A's `rebuildCount` by exactly 1 and leaves fragment B's unchanged                  | FR-002, US2-S1/S2, SC-002  | example | DONE | `test/state/widgets/fragment_builder_test.dart::slice-A change rebuilds only` |
| U9  | Slices A and B both change in the same turn → each bound fragment rebuilds exactly once, independently                    | FR-002, US2-S3             | example | DONE | `test/state/widgets/fragment_builder_test.dart::same turn` |
| U10 | A loading slice with no data renders `onLoading`; a loading slice WITH stale data keeps showing data                      | FR-003, US3-S1             | example | DONE | `test/state/widgets/fragment_builder_test.dart::loading slice renders onLoading` |
| U11 | A failed slice renders `onError` and the builder receives the `AppFailure`                                                | FR-003, US3-S2             | example | DONE | `test/state/widgets/fragment_builder_test.dart::failed slice renders onError` |
| U12 | A successful slice with `null` data renders `onEmpty`; empty `Iterable`/`Map`/`String` data also renders `onEmpty`        | FR-003, US3-S3, FR-008 (null/default slice) | example | DONE | `test/state/widgets/fragment_builder_test.dart::null data and empty collections` |
| U13 | A successful slice with data invokes `builder` with the slice value                                                       | FR-002, US3-S4             | example | DONE | `test/state/widgets/fragment_builder_test.dart::data emission invokes builder` |
| U14 | Omitting a state builder falls through to the next applicable state without crashing (opt-in, no forced UI)               | FR-003 (assumption)        | example | DONE | `test/state/widgets/fragment_builder_test.dart::omitted state builders` |
| U15 | A `SignalSlice<dynamic>` emitting a value whose runtime type is not `S` surfaces a validation failure via `onError`, no crash | FR-008 (type changes)   | example | DONE | `test/state/widgets/fragment_builder_test.dart::type change surfaces as a clear error` |
| U16 | Rapid successive emissions (3 values, same turn) produce exactly 3 rebuilds — deterministic, no coalescing                | FR-008 (rapid updates)     | example | DONE | `test/state/widgets/fragment_builder_test.dart::rapid successive emissions` |
| U17 | A detached fragment ignores subsequent slice emissions (no rebuild, no output change)                                     | FR-008 (in-flight async)   | example | DONE | `test/state/widgets/fragment_builder_test.dart::detached fragment ignores` |
| U18 | A slice disposed while attached ends the fragment cleanly — no crash, output freezes at last state                        | FR-008                    | example | DONE | `test/state/widgets/fragment_builder_test.dart::slice disposed while attached` |
| U19 | Two fragments where one slice is loading and the other ready: the ready fragment renders data; loading does not block it  | FR-008 (independent rendering) | example | DONE | `test/state/widgets/fragment_builder_test.dart::loading slice does not block` |

### `lib/src/state/widgets/signal_builder.dart` (SignalBuilder\<T\>)

| id  | behavior                                                                                                   | traces                     | kind    | state   | test |
| --- | ---------------------------------------------------------------------------------------------------------- | -------------------------- | ------- | ------- | ---- |
| U20 | A signal change rebuilds only the bound `SignalBuilder`; a sibling `FragmentBuilder` and other signal builders do not rebuild | FR-004, US4-S1/S2 | example | DONE | `test/state/widgets/signal_builder_test.dart::signal change rebuilds only` |
| U21 | A disposed signal renders the defined fallback without throwing                                                                           | FR-004, US4-S3, FR-008 (disposed signal) | example | DONE | `test/state/widgets/signal_builder_test.dart::disposed signal renders fallback` |
| U22 | A nullable signal with `null` initial value renders a defined default (builder receives `null`) rather than crashing                      | FR-008 (missing initial values) | example | DONE | `test/state/widgets/signal_builder_test.dart::nullable signal with null initial` |

### `lib/src/state/generator/view_template_generator.dart` (pureDart mode)

| id  | behavior                                                                                                                       | traces        | kind    | state   | test |
| --- | ------------------------------------------------------------------------------------------------------------------------------- | ------------- | ------- | ------- | ---- |
| U23 | `generateView(..., pureDart: true)` emits a view extending `ControlledWidget`, one `FragmentBuilder` per use case, `SignalBuilder` per UI signal, importing only `package:zuraffa/zuraffa.dart` | FR-005, US5-S1 | example | DONE | `test/state/widgets/sc_003_generated_view_compiles_test.dart::emits ControlledWidget` |
| U24 | Default (Flutter) emission is byte-identical to pre-feature output — the new flag changes nothing when unset                     | FR-006        | example | DONE | `test/state/widgets/sc_003_generated_view_compiles_test.dart::byte-identical` |
| U25 | The generated pure-Dart view file passes `dart analyze` inside a temp package depending on zuraffa and mounts under `WidgetHost` | FR-005, US5-S2, SC-003 | example | DONE | `test/state/widgets/sc_003_generated_view_compiles_test.dart::compiles under dart analyze` |

### `lib/zuraffa.dart` (barrel exports)

| id  | behavior                                                                                                        | traces      | kind    | state   | test |
| --- | --------------------------------------------------------------------------------------------------------------- | ----------- | ------- | ------- | ---- |
| U26 | `ControlledWidget`, `FragmentBuilder`, `SignalBuilder`, `WidgetHost`, `ViewContext`, `FragmentContextError` are importable from `package:zuraffa/zuraffa.dart` | FR-001..FR-004 | example | DONE | `test/state/widgets/sc_003_generated_view_compiles_test.dart::package barrel` |

## Invariants and edge cases still to place

None — all edge cases from spec.md are placed on components above (U4, U12, U15, U16, U17, U18, U19, U21, U22).

## Out of scope

- Flutter widget implementations of these contracts — they belong to the separate `zuraffa_flutter` package; this feature defines the pure-Dart core contracts (spec assumption: "Code generation templates are updated separately" boundary).
- Debounced/coalesced fragment rebuilds — spec allows per-emission rebuilds as the deterministic documented behavior (U16 pins it); a configurable debounce is not required by any FR.
- `ControlledWidgetDetector` false-positive concerns for v6 user apps — informational-severity migration hint on user-project code, no FR covers it (plan.md decision 7).
- Performance benchmarking beyond rebuild-count assertions — spec assumption "no performance regression" is honored by not changing the notification path; no benchmark FR exists.

## Verification commands

Copied verbatim from `.specify/memory/tdd-profile.md` at planning time:

- Single test: `dart test test/<path>.dart -P "<name>"` (the `-P` filter matches test names containing the string)
- Full suite (feature scope): `dart test test/state/`
- Static analysis (feature scope): `dart analyze lib/src/state/ test/state/`
- Static analysis (full repo): `dart analyze`
