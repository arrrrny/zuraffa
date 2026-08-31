# Bug Spec: slice cut must preserve barrel `export ... show/hide` (FR-005)

- **Slug**: slice-barrel-show-hide-ignored
- **Source assessment**: ./assessment.md
- **GitHub issue**: https://github.com/arrrrny/zuraffa/issues/605

## Problem

`zfa slice cut` is supposed to emit a *filtered* barrel that re-exports only the
symbols the slice needs (FR-005, US1-A4). It currently:

1. drops `show`/`hide` combinators on the barrel's own `export` directives
   (`engine/barrel_resolver.dart:64-77` `_exportTargets`, `:79-99` `_targetNeeded`), and
2. re-emits each kept target as a bare `export '<file>';` that dumps the whole
   file's public API (`capabilities/cut_slice_capability.dart:403-423`).

Net effect: over-inclusion (SC-003) and, when the original barrel used `show`/`hide`
to avoid a name collision, a **non-compiling slice** (SC-002).

## Acceptance Criteria (the fixed behavior)

- **AC-1**: When a barrel uses `export 'a.dart' show Foo;`, the generated filtered
  barrel re-emits that directive *verbatim* (preserving the `show Foo` clause),
  not `export 'a.dart';`.
- **AC-2**: When a barrel uses `export 'a.dart' hide Bar;`, the generated filtered
  barrel preserves the `hide Bar` clause.
- **AC-3**: A barrel whose `show`/`hide` clauses disambiguate colliding symbols
  (e.g. `export 'app_card.dart' show AppCard;` + `export 'overlay_card.dart' show
  OverlayCard;`, both targets also declaring `BaseCard`) still produces a sandbox
  barrel with **no duplicate-export error** — the slice must compile
  (`dart analyze` passes on the sandbox).
- **AC-4**: `BarrelResolver._targetNeeded` respects export-level `show`/`hide` so a
  target whose referenced symbol is hidden by the barrel is not force-included as if
  the whole file were visible.

## Failing-test scenario (from assessment reproduction)

Given a project with:

```dart
// lib/src/presentation/widgets/index.dart
export 'app_card.dart' show AppCard;        // app_card.dart ALSO declares BaseCard
export 'overlay_card.dart' show OverlayCard; // overlay_card.dart ALSO declares BaseCard
```

and a page that imports the barrel and uses only `AppCard` + `OverlayCard`:

- `dart run bin/zfa.dart slice cut card_feature --entry card --depth feature`
- Then `dart analyze .zuraffa/slices/card_feature` must pass.
- The emitted `.zuraffa/slices/card_feature/lib/src/presentation/widgets/index.dart`
  must preserve the `show` clauses (not re-export the targets in full).

## Out of scope (this bug)

- Finer symbol-level filtering (emitting `export 'a.dart' show <only the slice's
  used symbols>`), which can break re-exported symbols. Preserving the original
  directive text verbatim is sufficient and correct.
- The other gaps listed in assessment.md (classifyLayer substring, ownership
  classifier, import verifier lib/ hardcode, slice run, pubspec filter) — tracked
  separately.
