# Cycle Log: ControlledWidget with FragmentBuilder for Granular Rebuilds

Append only. Newest last. Every entry's `red` block is the evidence that the test
existed and failed before the implementation.

## Baseline

- suite: `dart test test/state` -> 68 passed, 0 failed (feature scope per profile; fast tier, `slow` tags excluded)
- full-suite baseline: `dart test` (fast tier) started in parallel at 4c1c2641 — recorded below when complete; feature-scope green is the planning gate
- commit: `4c1c2641`
- recorded: cycle 0, before any change

## Cycle 1: U1..U5 mount layer (WidgetHost, ViewContext, FragmentContextError)

- test: `test/state/widgets/widget_host_test.dart` (new, 5 tests) + `test/state/widgets/controlled_widget_test.dart` (new, 2 tests)
- red: `dart test test/state/widgets/widget_host_test.dart test/state/widgets/controlled_widget_test.dart` -> both files failed to load: "Error: 'WidgetHost' isn't a type", "Error: Method not found: 'ControlledWidget'" (+2 -2, compile red — types did not exist)
- green: added `lib/src/state/widgets/widget_host.dart` (ViewFragment, ViewContext, WidgetHost, FragmentContextError) and `lib/src/state/widgets/controlled_widget.dart`; filled the widget_host export slot in `lib/zuraffa.dart`. Suite `dart test test/state/widgets/` -> 7 passed
- refactor: dropped `@mustCallSuper` from no-op hooks (subclasses override freely, per spec intent); gave `build` a `null`-returning default so bare subclasses mount; removed redundant widget_host re-export from controlled_widget.dart
- commit: (committed with this feature's implementation commit)

## Cycle 2: U8, U9, U13, U17 FragmentBuilder data path

- test: `test/state/widgets/fragment_builder_test.dart` (new, 4 tests) — slice-A change rebuilds only fragment A; same-turn independence; builder receives slice value; detached fragment ignores emissions
- red: `dart test test/state/widgets/fragment_builder_test.dart` -> "Error: 'FragmentBuilder' isn't a type" (+0 -1, compile red)
- green: added `lib/src/state/widgets/fragment_builder.dart` (data path only: subscribe via slice.listen, per-emission rebuild, detach cancels subscription) + barrel export. Suite -> 11 passed
- refactor: replaced the duplicate `import 'widget_host.dart'` with the barrel-only import (unnecessary_import)
- commit: (same implementation commit)

## Cycle 3: U10, U11, U12, U14 state builders

- test: appended "FragmentBuilder state builders (FR-003)" group (4 tests) to fragment_builder_test.dart
- red: `dart test test/state/widgets/fragment_builder_test.dart` -> +4 -4 assertion failures: "Expected: FragmentState:<FragmentState.loading> Actual: FragmentState:<FragmentState.initial>" (x4) — v1 had no state resolution
- green: implemented the six-step state machine (error -> loading-no-data -> empty -> type-guard -> empty-value -> data) with optional onLoading/onError/onEmpty. Suite -> 8 passed in file
- refactor: fixed `String.take` misuse (substring clipping) found by the compiler during green-up
- commit: (same implementation commit)

## Cycle 4: U15, U16, U18, U18b, U19 edge cases

- test: appended "FragmentBuilder edge cases (FR-008)" group (5 tests)
- red: initial draft used `SignalSlice<dynamic>` for the type-mismatch case — the compiler rejected it ("The argument type 'SignalSlice<dynamic>' can't be assigned to the parameter type 'SignalSlice<int>'"): Dart's reified generics make an untyped value reaching the builder unreachable. Test rewritten to the reachable flow (upstream type change -> validation Failure -> error state). U16/U18/U18b/U19 were born green — their guards shipped with the cycle-3 state machine; deliberate mutants (below) prove the tests are load-bearing
- green: `dart test test/state/widgets/fragment_builder_test.dart` -> 13 passed
- refactor: none needed
- deliberate mutants (mutation tool: none wired; sampling per rubric):
  - M1 `_isEmptyValue => false` -> U12 failed (+0 -1) — killed
  - M2 `recordRebuild` without count -> U16 failed (+0 -1) — killed
  - M3 `_onSliceChange` attach-guard removed -> U17 still passed — SURVIVED. Rationale: the observable detached-ignore behavior is enforced by subscription cancellation (detach cancels the slice subscription, so the emission never arrives); the `isAttached` guard is defense-in-depth for a mid-notification detach race that cannot be triggered deterministically through the public API because `Signal` listener iteration order (identity HashSet) is unspecified. Guard retained with this recorded rationale.
  - M4 disposed-at-attach guard disabled -> U18b failed (+0 -1) — killed
  - M5 SignalBuilder disposed-fallback removed -> U21 failed (+0 -1) — killed
- commit: (same implementation commit)

## Cycle 5: U20, U21, U21b, U22 SignalBuilder

- test: `test/state/widgets/signal_builder_test.dart` (new, 4 tests)
- red: `dart test test/state/widgets/signal_builder_test.dart` -> "Error: 'SignalBuilder' isn't a type" (+0 -1, compile red)
- green: added `lib/src/state/widgets/signal_builder.dart` + barrel export. Suite test/state/widgets -> 24 passed
- refactor: replaced an `_InertContext implements ViewContext` hack with a nullable-context `fallback` signature
- commit: (same implementation commit)

## Cycle 6: U23, U24, U25, U26 generator pureDart mode

- test: `test/state/widgets/sc_003_generated_view_compiles_test.dart` (new, 4 tests: emission pattern, byte-identical Flutter golden, dart-analyze compile proof in a temp package dir inside the repo, barrel exports)
- red: `dart test test/state/widgets/sc_003_generated_view_compiles_test.dart` -> "Error: No named parameter with the name 'pureDart'" (+0 -1, compile red)
- green: added `pureDart` flag to `ViewTemplateGenerator.generateView` (typed slice-field emission; default Flutter path untouched) plus a covariant `domain` getter to `generatePresenter` so generated views can use typed `controller.domain.<sliceKey>` access. Suite -> 27 passed
- refactor: fixed a generated-code syntax error found by the compile proof itself (a trailing `//` comment swallowed the block's closing brace); fixture presenter uses a concrete SlicePresenter subclass because the shipped generatePresenter emits `SlicePresenter()` — SlicePresenter is abstract, so THAT emission cannot compile as-is (pre-existing quirk, Flutter output was never compile-checked; flagged in verification.md, out of scope for this spec)
- commit: (same implementation commit)

## Cycle 7: A1, A2, A4 acceptance (+A3 covered by sc_003)

- test: `sc_001_typed_controller_lifecycle_test.dart`, `sc_002_slice_isolated_rebuild_test.dart`, `sc_004_pre_v6_compat_test.dart` (new)
- red: `dart test test/state/widgets/sc_001... sc_002...` -> "Error: The getter 'isLoading' isn't defined for the type 'ViewState'" (presenters needed the covariant view override — same lesson as the generated presenter), then runtime "Null check operator used on a null value" from `slice('products')!` — generated late-final slice fields are lazy and never bootstrap themselves, so string-key lookup returns null. This exposed the real bootstrap gap in the generated pattern
- green: pure-Dart generated views and acceptance views use typed slice-field access (`controller.domain.products.refresh()` / `slice: controller.domain.products`), which bootstraps the lazy binding; acceptance presenters carry covariant `view` + `domain` overrides (generatePresenter now emits the domain override too). Suite `dart test test/state/widgets/` -> 31 passed
- refactor: counted-rebuild expectation corrected (signal builder: eager initial + one change = 2 cycles)
- commit: (same implementation commit)

## Full-suite regression (fast tier)

- `dart test test/state` -> 99 passed, 0 failed (baseline 68 — +31 new widget tests, 0 regressions)
- `dart test test/core test/plugins/route` -> 607 passed, 1 skipped, 0 failed
- `dart test test/plugins/state` -> 2 passed
- `dart analyze lib/ test/state/widgets/` -> 0 errors; 1 pre-existing warning (`route_builder.dart` `_parseFirstGoRoutePath` unused — exists on master)
- full `dart test` (fast tier across the whole repo): run before PR, recorded in verification.md
