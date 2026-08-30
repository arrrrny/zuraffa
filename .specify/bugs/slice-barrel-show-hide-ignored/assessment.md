# Bug Assessment: `zfa slice cut` discards barrel `export ... show/hide`, breaking the filtered barrel (FR-005)

- **Slug**: slice-barrel-show-hide-ignored
- **Created**: 2026-08-30
- **Source**: Manual code review of `lib/src/plugins/slice` (spec `043-slice-plugin`), triggered by a "roast" of the newly-merged slice feature. No external report / URL.
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

The slice plugin (commit `d964801d`, PR #595) extracts a runnable subset of a
Zuraffa app from an entry point. For barrels (`index.dart` re-export files),
FR-005 requires that *only the symbols actually needed by the slice are
included* — the entire barrel contents must not be pulled in. The
implementation violates this in two places: it ignores `show`/`hide` combinators
on the barrel's own `export` directives, and it re-emits each kept target as a
plain `export '<file>';` that dumps the whole file's public API into the
sandbox. The result is over-inclusion (SC-003) and, when the original barrel's
`show`/`hide` existed to avoid a name collision, a non-compiling slice
(SC-002).

## Symptom

When a slice is cut from a feature that imports a barrel which uses
`export 'a.dart' show Foo;` (or `hide`), the generated "filtered" barrel in the
sandbox re-exports the kept target files in full and drops the `show`/`hide`
clauses. If two kept targets declare a symbol the original barrel disambiguated
via `show`, the sandbox barrel now exports the duplicate symbol and
`dart analyze` fails — the slice does not compile. Even absent a collision,
every public symbol of each kept target is pulled into the slice, defeating the
size reduction that FR-005 exists to provide.

## Reproduction

1. In a Zuraffa project (`lib/src/presentation/widgets/index.dart`):

   ```dart
   export 'app_card.dart' show AppCard;        // app_card.dart ALSO declares BaseCard
   export 'overlay_card.dart' show OverlayCard; // overlay_card.dart ALSO declares BaseCard
   ```

   (`BaseCard` is a deliberate collision the `show` clauses hide.)

2. A page imports `package:<pkg>/presentation/widgets/index.dart` and uses
   `AppCard` + `OverlayCard` only.

3. Run:

   ```bash
   dart run bin/zfa.dart slice cut card_feature --entry card --depth feature
   ```

4. Inspect the emitted filtered barrel:

   ```bash
   cat .zuraffa/slices/card_feature/lib/src/presentation/widgets/index.dart
   ```

   Observed (cut_slice_capability.dart:412-420):

   ```dart
   // Filtered by `zfa slice cut` ...
   library;
   export '../../app_card.dart';      // re-exports BaseCard too
   export '../../overlay_card.dart';   // re-exports BaseCard too -> duplicate BaseCard
   ```

5. `dart analyze .zuraffa/slices/card_feature` → duplicate-export error → slice
   fails to compile.

This path is **untested**: the bundled fixture
`test/fixtures/slice_test_project/lib/src/presentation/widgets/index.dart`
re-exports its 4 widgets with no `show`/`hide`, and
`test/plugins/slice/engine/barrel_resolver_test.dart` only exercises
import-side `show` (the importer's clause), never export-side `show`/`hide`.

## Suspected Code Paths

- `lib/src/plugins/slice/engine/barrel_resolver.dart:64-77` — `_exportTargets`
  reads only `directive.uri.stringValue` and discards any
  `ShowCombinator`/`HideCombinator` on the `ExportDirective`.
- `lib/src/plugins/slice/engine/barrel_resolver.dart:79-99` — `_targetNeeded`
  decides inclusion purely by whether the importer references a top-level name
  declared in the target file; it never consults export-level `show`/`hide`.
  (Import-level `show` on the importing statement *is* respected via
  `shownSymbols`, but export-level is not.)
- `lib/src/plugins/slice/capabilities/cut_slice_capability.dart:403-423` — emits
  the filtered barrel as `export '<relative-path-to-kept-target>';`, i.e. it
  re-exports the **entire** kept target file with no `show`/`hide` reconstruction.

## Root Cause Hypothesis

The barrel "filter" only filters *which target files* to keep (by importer
reference), but then re-emits each kept target wholesale and throws away the
barrel's `show`/`hide` constraints. Both the walker's target-selection
(`_targetNeeded`) and the cut's barrel-writer ignore export-level combinators,
so FR-005's "only the symbols actually needed" guarantee is not met. Confidence:
**high** — confirmed by direct reading of the three sites above; the fixture
lacks a `show`/`hide` barrel so the gap was never exercised.

## Proposed Remediation

**Preferred**: Preserve the barrel's original export directives verbatim for the
kept targets. In `CutSliceCapability`, instead of `export '<path>';`, emit each
original `ExportDirective` text (including its `show`/`hide`) for targets that
survived filtering. This is semantically correct with minimal risk. In parallel,
make `BarrelResolver` respect export-level `show`/`hide` when deciding
`_targetNeeded` (a target whose referenced symbol is hidden by the barrel should
not be force-included).

**Alternatives**:
- Emit `export '<target>' show <only symbols referenced by the slice>` — finer
  granularity, but fragile for re-exported symbols and lower priority.
- Leave the filtered barrel as a verbatim copy of the original barrel file when
  all targets are kept (simplest, but doesn't shrink the barrel at all).

**Files likely to change**:
- `lib/src/plugins/slice/engine/barrel_resolver.dart`
- `lib/src/plugins/slice/capabilities/cut_slice_capability.dart`
- `test/plugins/slice/engine/barrel_resolver_test.dart` (add export `show`/`hide` cases)
- `test/plugins/slice/slice_cut_integration_test.dart` (assert filtered barrel preserves `show`/`hide` and compiles without duplicate-export errors)

**Tests to add or update**:
- A fixture barrel with colliding hidden symbols
  (`export 'a.dart' show Foo; export 'b.dart' show Foo;` where both `a`/`b`
  also declare `Foo`) cut and verified to compile with no duplicate-export error.
- Assertion that the emitted filtered barrel mirrors the original export
  directives verbatim (preserving `show`/`hide`).

## Risks & Considerations

- Barrel emission runs for essentially every real slice (barrels are the norm in
  Zuraffa), so the change must keep relative export paths valid inside the
  sandbox.
- Preserving `show`/`hide` verbatim changes the sandbox's observable API surface
  for agents; that is the *intended* behavior (FR-005) but should be called out
  in the slice's `SLICE.md`.
- `verify` (FR-013) currently only checks import resolution, not duplicate
  exports — a collision would still slip through `slice verify`, so a
  compile-level check is the real safety net.

## Open Questions

- None blocking. The fix is local to barrel emission + target selection.

---

## Additional gaps found during the roast (not the primary bug)

These were uncovered while reviewing the feature and are listed so the fix can be
batched; each is a distinct issue from the one above.

1. **`classifyLayer` substring match misclassifies non-presenter files as the
   `presenter` layer** — `lib/src/plugins/slice/models/file_graph.dart:106-107`
   returns `'presenter'` whenever the path *contains* the substring
   `"presenter"` (a whole-path substring, not a filename match). A helper such
   as `lib/src/presentation/pages/product/presenter_helpers.dart` is classified
   as `presenter` and dropped at `--depth view`/`presentation`, leaving a dangling
   import and a non-compiling slice for a file the view genuinely needs. The test
   fixture uses only `*_presenter.dart`, so the case is untested. (Severity:
   high.)

2. **`OwnershipClassifier` never returns `framework` and over-labels files as
   `shared`** — `lib/src/plugins/slice/engine/ownership_classifier.dart:16-28`
   returns `shared` for *every* file outside the entry page directory, so FR-010's
   three-way `owned`/`shared`/`framework` classification is never produced and
   merge emits false-positive "shared file modified — confirm overwrite" prompts
   for files that are local to the feature but live outside
   `pages/<feature>/`. (Severity: medium.)

3. **`ImportVerifier` hardcodes the `lib/` package root** —
   `lib/src/plugins/slice/verifier/import_verifier.dart:118-144` joins
   `sandboxDir/lib/<packagePath>` instead of using `PackageResolver`'s
   `packageUri`. Projects whose package root is not `lib/` would have every
   self-package import reported as missing. Low frequency for default pub
   layouts, but inconsistent with the resolver used everywhere else. (Severity:
   low/medium.)

4. **`slice run` standalone-runnability is unverified** —
   `runner/slice_runner.dart:91-97` runs `flutter run -t <sandbox>/main_slice.dart`
   from the project root, while `sandbox_bootstrapper.dart:89` emits
   `package:<pkg>/...` self-imports and the sandbox never gets its own
   `pub get`/package config. Whether the agent's sandbox edits actually execute
   (vs. the project's original code) depends on Flutter's auto-`pub get` and
   package-config resolution; US7 ("review the agent's changes") needs a
   reproduction to confirm. (Severity: medium, needs reproduction.)

5. **`pubspec_filter` keeps only directly-imported packages** —
   `lib/src/plugins/slice/exporter/pubspec_filter.dart:50-67` scans sliced files
   for `package:` imports and drops any project dependency not directly imported,
   including transitive deps the slice's analyzer still needs on a clean machine
   (SC-009). (Severity: medium.)

6. **Merge deletes the sandbox after any clean merge, not just no-change** —
   `lib/src/plugins/slice/merger/slice_merger.dart:208-210` deletes the sandbox
   dir whenever there are no conflicts, so a slice cannot be re-merged or
   re-inspected after a successful merge. (Severity: low; may be intended.)
