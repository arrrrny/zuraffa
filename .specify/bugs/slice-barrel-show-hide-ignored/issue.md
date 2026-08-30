# `zfa slice cut` discards barrel `export ... show/hide`, breaking the filtered barrel (FR-005)

- **GitHub issue**: https://github.com/arrrrny/zuraffa/issues/605
- **Assessment**: `.specify/bugs/slice-barrel-show-hide-ignored/assessment.md`

> Triaged from `.specify/bugs/slice-barrel-show-hide-ignored/assessment.md`.
> This issue is the **roast** of the newly-merged slice plugin (`d964801d`, #595):
> it leads with the most severe confirmed bug and lists the other gaps found
> while reviewing `lib/src/plugins/slice`.

## Primary bug (high)

`zfa slice cut` is supposed to produce a "filtered" barrel that re-exports only
the symbols the slice needs (FR-005, US1-A4). It does neither:

- `BarrelResolver._exportTargets` (`engine/barrel_resolver.dart:64-77`) reads only
  `directive.uri` and **drops `show`/`hide` combinators** on the barrel's
  `export` directives.
- `BarrelResolver._targetNeeded` (`engine/barrel_resolver.dart:79-99`) decides
  inclusion purely by whether the importer references a top-level name in the
  target — it never consults export-level `show`/`hide`.
- `CutSliceCapability` (`capabilities/cut_slice_capability.dart:403-423`) emits the
  filtered barrel as `export '<kept-target-file>';`, i.e. it **re-exports the
  entire target file** with no `show`/`hide` reconstruction.

### Why it breaks (repro)

A barrel that uses `show` to avoid a name collision:

```dart
// lib/src/presentation/widgets/index.dart
export 'app_card.dart' show AppCard;        // app_card.dart ALSO declares BaseCard
export 'overlay_card.dart' show OverlayCard; // overlay_card.dart ALSO declares BaseCard
```

Cut a slice that imports it. The generated sandbox barrel becomes:

```dart
export '../../app_card.dart';       // re-exports BaseCard too
export '../../overlay_card.dart';    // re-exports BaseCard too -> DUPLICATE BaseCard
```

→ `dart analyze` fails → **the slice does not compile** (SC-002 violation). Even
without a collision, every public symbol of each kept target is pulled in
(SC-003 over-inclusion).

**Untested path**: the bundled fixture
`test/fixtures/slice_test_project/lib/src/presentation/widgets/index.dart` uses no
`show`/`hide`, and `barrel_resolver_test.dart` only covers import-side `show`. The
export-level `show`/`hide` path is entirely unexercised.

### Fix

Preserve the barrel's original export directives verbatim for kept targets (emit
each `ExportDirective` text, `show`/`hide` included) instead of
`export '<path>';`; and make `BarrelResolver` respect export-level `show`/`hide`
in `_targetNeeded`. Then add a colliding-hidden-symbols fixture test asserting the
filtered barrel compiles.

---

## Additional gaps found during the roast

1. **`classifyLayer` substring match** — `models/file_graph.dart:106-107` returns
   `'presenter'` whenever the path *contains* `"presenter"` (whole-path substring,
   not a filename match). `pages/product/presenter_helpers.dart` is misclassified
   as `presenter` and dropped at `--depth view`/`presentation`, leaving a dangling
   import and a non-compiling slice. Fixture uses only `*_presenter.dart`, so
   untested. (high)

2. **`OwnershipClassifier` never returns `framework`** —
   `engine/ownership_classifier.dart:16-28` returns `shared` for every file outside
   the entry page dir, so FR-010's three-way `owned`/`shared`/`framework` is never
   produced and merge emits false-positive "shared file — confirm overwrite"
   prompts for feature-local files. (medium)

3. **`ImportVerifier` hardcodes `lib/`** — `verifier/import_verifier.dart:118-144`
   joins `sandboxDir/lib/<packagePath>` instead of using `PackageResolver`'s
   `packageUri`; projects with a non-`lib` package root get every self-package
   import flagged as missing. (low/medium)

4. **`slice run` standalone-runnability unverified** —
   `runner/slice_runner.dart:91-97` runs `flutter run -t <sandbox>/main_slice.dart`
   from the project root while `sandbox_bootstrapper.dart:89` emits
   `package:<pkg>/...` imports and the sandbox never gets its own `pub get`/package
   config. Whether agent edits actually execute (vs. the project's original code)
   is unconfirmed — US7 ("review agent changes") needs a reproduction. (medium)

5. **`pubspec_filter` keeps only directly-imported packages** —
   `exporter/pubspec_filter.dart:50-67` drops project deps not directly imported,
   including transitive deps the slice's analyzer still needs on a clean machine
   (SC-009). (medium)

6. **Merge deletes the sandbox after any clean merge** —
   `merger/slice_merger.dart:208-210` deletes the sandbox whenever there are no
   conflicts, so a slice can't be re-merged/re-inspected after a successful merge.
   (low; may be intended)

## Suggested labels

`bug`, `slice-plugin`, `spec-043`
