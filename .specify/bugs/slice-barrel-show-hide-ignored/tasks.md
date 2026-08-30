# Tasks: slice-barrel-show-hide-ignored

## TDD behavior tasks

- [x] [A1] Filtered barrel preserves `export 'a.dart' show Foo;` verbatim
- [x] [A2] Filtered barrel preserves `export 'a.dart' hide Bar;` verbatim
- [x] [A3] Colliding symbols disambiguated by `show` still compile in the sandbox
- [x] [A4] `BarrelResolver._targetNeeded` respects export-level `show`/`hide`

## Implementation tasks

- [x] Preserve `show`/`hide` combinators in `BarrelResolver._exportTargets` (renamed `_exportBarrels`)
- [x] Emit original export directives verbatim in `CutSliceCapability` filtered-barrel writer
