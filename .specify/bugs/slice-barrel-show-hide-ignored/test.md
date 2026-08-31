# Test: slice cut preserves barrel export show/hide (issue #605)

- **Slug**: slice-barrel-show-hide-ignored
- **Result**: verified
- **Mode**: TDD (tdd_enabled: true) — fix produced via red/green on the bug
  directory; this step re-runs the behavior tests and records the verdict.

## Reproduction re-run

The bug scenario: a barrel whose target carries an export-level combinator,
e.g. `export 'primary_button.dart' show PrimaryButton;`, was cut to a bare
`export 'primary_button.dart';`, re-exporting the whole target into the slice.

Re-ran the lock-in tests after the fix:

```
$ dart test test/plugins/slice/engine/barrel_resolver_test.dart
00:01 +8: All tests passed!        (U13–U20; U17–U20 assert the combinator)

$ dart test test/plugins/slice/
00:07 +78: All tests passed!       (full fast slice suite, no regressions)

$ dart test --preset=all test/plugins/slice/slice_cut_integration_test.dart
00:02 +9: All tests passed!        (incl. new A4b / issue #605 end-to-end)
```

## What the tests prove

- **U17 (A1)**: `export 'a.dart' show Foo;` is preserved in `directiveText`
  and `show`.
- **U18 (A2)**: `export 'a.dart' hide Bar;` is preserved in `directiveText`
  and `hide`.
- **U19 (A4)**: export-level `show` hides un-shown symbols, so a target whose
  only declared name is hidden is dropped — `_targetNeeded` respects the
  combinator.
- **U20 (A3)**: colliding hidden symbols disambiguated by `show` produce a
  filtered barrel with no duplicate re-export.
- **A4b (cut, issue #605)**: an end-to-end `zfa slice cut` of a barrel whose
  target carries `export 'x.dart' show Foo;` re-emits
  `export 'x.dart' show Foo;` verbatim and does not re-export wholesale
  (`export 'x.dart';` absent).

## Acceptance criteria coverage

| AC  | Covered by                                  | Status   |
| --- | ------------------------------------------- | -------- |
| AC-1 | U17 + A4b                                   | verified |
| AC-2 | U18                                         | verified |
| AC-3 | U20                                         | verified |
| AC-4 | U19                                         | verified |

## Notes

`dart analyze` is clean on the four edited files. No new regressions in the
slice plugin suite. The fix is confined to the barrel pipeline
(`barrel_resolver.dart`, `import_graph_walker.dart`, `cut_slice_capability.dart`)
plus the test additions; `file_graph.dart` needed no change (its `WalkResult`
lives in `import_graph_walker.dart`).

## Next

Restore `.specify/feature.json` to `specs/049-tdd-run` (the bug dir no longer
needs to be the TDD feature) and proceed to the PR (`/skill:speckit-bug-pr`).
