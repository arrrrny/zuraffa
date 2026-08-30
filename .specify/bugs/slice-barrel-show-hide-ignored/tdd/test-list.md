---
feature: slice-barrel-show-hide-ignored
loop: outside-in
profile: .specify/memory/tdd-profile.md
spec_criteria: 4
planned_at: dd5490d6
updated_at: dd5490d6
suite_baseline: green
---

# Test List: slice cut must preserve barrel export show/hide (FR-005)

Outer-only plan (no `plan.md` in the bug directory). One acceptance behavior per
acceptance criterion from `spec.md`.

## Outer loop: acceptance behaviors

| id  | behavior                                                                                     | traces | kind    | state    | test                                                                                  |
| --- | -------------------------------------------------------------------------------------------- | ------ | ------- | -------- | ------------------------------------------------------------------------------------- |
| A1  | A barrel `export 'a.dart' show Foo;` is re-emitted verbatim in the filtered barrel (with `show Foo`) | AC-1   | example | PENDING  | `test/plugins/slice/slice_cut_barrel_show_hide_test.dart::preserves show clause`       |
| A2  | A barrel `export 'a.dart' hide Bar;` is re-emitted verbatim in the filtered barrel (with `hide Bar`) | AC-2   | example | PENDING  | `test/plugins/slice/slice_cut_barrel_show_hide_test.dart::preserves hide clause`       |
| A3  | A barrel whose `show` clauses disambiguate colliding symbols still produces a compiling sandbox (no duplicate-export error) | AC-3   | example | PENDING  | `test/plugins/slice/slice_cut_barrel_show-hide_test.dart::colliding symbols compile`   |
| A4  | `BarrelResolver._targetNeeded` respects export-level `show`/`hide` when deciding a target is needed | AC-4   | example | PENDING  | `test/plugins/slice/engine/barrel_resolver_test.dart::export show/hide respected`      |

## Inner loop: unit behaviors

No `plan.md` present (outer-only). The unit behaviors that back A1–A3 are:

- `engine/barrel_resolver.dart` `_exportTargets` must preserve each `ExportDirective`'s
  `show`/`hide` combinators (currently drops them).
- `capabilities/cut_slice_capability.dart` filtered-barrel emission must re-emit the
  original export directives verbatim (preserving `show`/`hide`), not
  `export '<target>'`.

These are derived from `assessment.md` (Suspected Code Paths), not from `plan.md`.

## Invariants and edge cases still to place

- Import-level `show` on the importing statement (already covered by `barrel_resolver_test.dart::U13`) must keep working.
- A barrel with neither `show` nor `hide` (the fixture's `widgets/index.dart`) must continue to emit the kept targets unchanged.

## Out of scope

- Symbol-level filtering (`export 'a.dart' show <only the slice's used symbols>`): not required; preserving the original directive verbatim is sufficient.
- The other gaps in `assessment.md` (classifyLayer substring, ownership classifier, import verifier lib/ hardcode, slice run, pubspec filter): separate bugs.

## Verification commands

Copied verbatim from `.specify/memory/tdd-profile.md` at planning time:

- Single test: `dart test <file> --plain-name "<name>"`
- Whole file: `dart test <file>`
- Full suite (repo): `dart test` — slow; do not run for feature work, run the scoped subset instead.
- Static analysis (feature scope): `dart analyze lib/src/plugins/slice/ test/plugins/slice/`
