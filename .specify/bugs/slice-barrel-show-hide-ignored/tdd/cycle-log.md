# Cycle Log: slice cut must preserve barrel export show/hide (FR-005)

Append only. Newest last. Every entry's `red` block is the evidence that the test
existed and failed before the implementation.

## Baseline

- suite: `dart test test/plugins/slice/engine/barrel_resolver_test.dart` -> 4 passed, 0 failed
- repo slice tests green at planning time
- commit: `dd5490d6`
- recorded: cycle 0, before any change

## A1–A4 (FR-005 fix)

### RED — behavior test existed and failed before implementation

The resolver tests (U13–U16 already passed) were extended to U17–U20 asserting
`BarrelExport.directiveText` / `show` / `hide` are populated, and a cut-level
acceptance test (A4b) asserts the filtered barrel emits
`export 'primary_button.dart' show PrimaryButton;` verbatim. Before the fix,
`BarrelExport` did not exist as a type and `_exportTargets` returned
`List<String>`, so the suite failed to compile:

```
$ dart test test/plugins/slice/engine/barrel_resolver_test.dart
... test/plugins/slice/engine/barrel_resolver_test.dart: Error: Type 'BarrelExport' not found.
... The name 'BarrelExport' isn't a type, so it can't be used as a type argument.
```

Root cause captured in `assessment.md`: `BarrelResolver._exportTargets` dropped
each `ExportDirective`'s `show`/`hide` combinator and returned bare target
paths; `CutSliceCapability` re-emitted `export '<target>';` wholesale.

### GREEN — implementation present, behavior locked

- `BarrelResolver._exportTargets` -> `_exportBarrels` returns
  `List<BarrelExport>`, each carrying `directiveText` (verbatim
  `export 'uri' show/hide ...;`) plus `show`/`hide` name lists.
- `BarrelResolver._targetNeeded` now takes a `BarrelExport` and filters
  declared names by its export-level `show`/`hide` combinator before deciding
  a target is needed (A3/A4).
- `ImportGraphWalker` / `WalkResult.barrels` now carry `List<BarrelExport>`.
- `CutSliceCapability` emits `keptTarget.directiveText` verbatim (combinator
  preserved), instead of recomputing `export '<target>';`.

Verification:

```
$ dart test test/plugins/slice/engine/barrel_resolver_test.dart
00:01 +8: All tests passed!   (U13–U20)

$ dart test test/plugins/slice/   (fast unit suite)
00:07 +78: All tests passed!

$ dart test --preset=all test/plugins/slice/slice_cut_integration_test.dart
00:02 +9: All tests passed!   (incl. new A4b / issue #605)
```

- recorded: after implementation, branch `fix/slice-barrel-show-hide-ignored`
- outcome: GREEN, no regressions in the slice plugin suite.
