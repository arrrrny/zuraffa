# Fix: slice cut preserves barrel export `show`/`hide` (issue #605)

- **Slug**: slice-barrel-show-hide-ignored
- **Branch**: `fix/slice-barrel-show-hide-ignored` (from `dd5490d6`)
- **Status**: applied
- **Severity (from assessment)**: high
- **Verdict (from assessment)**: valid

## Root cause

`BarrelResolver._exportTargets` returned only the resolved target **paths**
(`List<String>`), discarding each `ExportDirective`'s `show`/`hide` combinator.
`CutSliceCapability` then re-emitted a bare `export '<target>';` for every kept
target, so a barrel such as:

```dart
export 'primary_button.dart' show PrimaryButton;
```

was cut to `export 'primary_button.dart';` — re-exporting the whole target file
into the slice instead of preserving the symbol filter. See `assessment.md`
(Suspected Code Paths, Root Cause Hypothesis).

## Remediation applied

Introduced a value type `BarrelExport` carrying the verbatim
`directiveText` (`export 'uri' show/hide ...;`) plus the parsed `show`/`hide`
name lists, and threaded it through the barrel pipeline:

- `lib/src/plugins/slice/engine/barrel_resolver.dart`
  - `_exportTargets` → `_exportBarrels`, returning `List<BarrelExport>`.
    Extracts `ShowCombinator.shownNames` / `HideCombinator.hiddenNames` and
    builds the verbatim `directiveText` via `_directiveText`.
  - `_targetNeeded` now takes a `BarrelExport` and filters the declared names by
    its export-level `show`/`hide` combinator before deciding a target is
    needed (so an export-level `show` that hides a name the importer uses no
    longer pulls the target in — A3/A4).
  - `expandImport` returns `List<BarrelExport>`; the non-barrel pass-through
    returns a `BarrelExport` with empty `directiveText`.

- `lib/src/plugins/slice/engine/import_graph_walker.dart`
  - `WalkResult.barrels` and the local `barrels` map now hold
    `List<BarrelExport>`.
  - `_expandImport` records the kept `BarrelExport`s and returns their
    `targetPath`s (callers still need plain paths).

- `lib/src/plugins/slice/capabilities/cut_slice_capability.dart`
  - Filtered-barrel writer emits `keptTarget.directiveText` verbatim (combinator
    preserved) instead of recomputing `export '<target>';`.

## Tests added / updated

- `test/plugins/slice/engine/barrel_resolver_test.dart` (U17–U20): assert
  `directiveText` preserves `show`/`hide`, export-level `show` hides un-shown
  symbols (A4), and colliding hidden symbols are disambiguated by `show` (A3).
- `test/plugins/slice/slice_cut_integration_test.dart` (A4b, issue #605):
  end-to-end cut of a barrel whose target carries `export 'x.dart' show Foo;`
  preserves the `show` in the filtered barrel and does not re-export wholesale.

## Verification

```text
dart test test/plugins/slice/engine/barrel_resolver_test.dart   -> 8 passed
dart test test/plugins/slice/                                    -> 78 passed
dart test --preset=all test/plugins/slice/slice_cut_integration_test.dart -> 9 passed
```

No regressions in the slice plugin suite. `dart analyze` clean on the four
edited files.

## Risks & notes

- `BarrelExport` is a **top-level** class (Dart forbids nested classes; an
  earlier draft nested it and failed to compile).
- Filtered-barrel `directiveText` reuses the original relative URI, which
  resolves identically in the sandbox because the slice preserves the source
  directory layout.
- Out of scope (separate bugs per `assessment.md`): classifyLayer substring,
  ownership classifier, import verifier `lib/` hardcode, slice run, pubspec
  filter.
