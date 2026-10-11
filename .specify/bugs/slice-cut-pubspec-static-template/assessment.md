# Bug Assessment: slice cut — sandbox pubspec does not declare the copied closure's package imports (issue #1304)

- **Slug**: slice-cut-pubspec-static-template
- **Issue**: 1304 (severity high, label `bug`)
- **Verdict**: valid; cut-side completeness gap confirmed against the code
- **Scope of remediation**: the slice cut pubspec writer ONLY. The verify gate
  semantics and the closure scan are NOT to be changed. One PR per bug.

## Symptom

`zfa slice cut <name> --entry <page> --depth full` exits 0, but
`zfa slice verify <name> --json` fails the `selfContainment` check with
`package "<name>" is not declared in pubspec.yaml` for every copied file that
imports a package the host resolves only transitively (`package:zuraffa/*`
when the host declares `zuraffa_flutter`, which resolves `zuraffa`
transitively).

## Reproduction

Confirmed on master (EPIC 4 re-evaluation, `239016de`) on a real scaffolded
app; reconfirmed on this branch's pre-fix code against a faithful
Flutter-shaped fixture host (`login_demo`: get_it + equatable declared,
`collection` resolved transitively, copied repository imports
`package:collection/collection.dart`): cut exits 0, `slice verify --json`
exits 1 with the `selfContainment` offender naming `collection`.

## Suspected Code Paths

- `lib/src/plugins/slice/exporter/pubspec_filter.dart` — the cut's pubspec
  writer. It scans the copied closure for `package:` imports (correct), but
  then intersects the used packages with the HOST pubspec's declared
  dependencies only; a used package the host does not declare directly is
  silently dropped from the sandbox pubspec. (The "static template" in the
  issue's title describes the observed output — on the repro host the
  kept set happened to be exactly the host-declared packages the closure
  imported: `flutter`, `shadcn_ui`, `zorphy_annotation`, `zuraffa_flutter`.)
- `lib/src/plugins/slice/verifier/import_verifier.dart` — the honest gate:
  with no `--host-root`, `slice verify --json` checks every sandbox import
  against the SANDBOX pubspec (`hostRoot ?? sandboxDir`), so the omission is
  detected with a machine-checkable verdict and a `--> fix:` line. Correct
  behavior; not to be changed.

## Root Cause

The pubspec writer drops imported-but-undeclared (transitive-only) packages
instead of deriving the sandbox dependencies from the copied closure.

## Proposed Remediation (applied)

In `PubspecFilter.filter()` (the cut's pubspec writer — and nothing else):

1. Keep the existing closure scan of `package:` imports across copied files
   (same scan as before; the closure scan itself is untouched).
2. For every imported package:
   - declared by the host (`dependencies:` or `dev_dependencies:`) → keep the
     host entry verbatim (git/path/hosted sources preserved — U56 unchanged);
   - NOT declared by the host → synthesize a `dependencies:` entry:
     version resolved from the host's `pubspec.lock` → `^<version>`,
     falling back to `any` plus an inline `# WARNING (issue #1304)` comment
     when the lock has no entry.
3. Determinism: derived entries are emitted sorted (SplayTreeMap), after the
   host-kept entries, so identical inputs yield byte-identical pubspecs
   (FR-007).
4. Verify gate semantics and closure scan: unchanged.

## Risks & Considerations

- A derived `^<lock-version>` pins the transitive package to the host's
  resolved version; if the host lock drifts, re-cut regenerates the
  constraint. The `any` fallback is the documented escape hatch for
  lock-less hosts.
- Generated harness files (e.g. `main_slice.dart`) intentionally keep their
  Flutter entry-point shape; on non-Flutter hosts the flutter SDK entry is
  absent from the host pubspec and the harness import is reported by the
  verifier as designed. Out of scope for #1304 (generator, not the pubspec
  writer; all zuraffa-scaffolded hosts are Flutter apps).
- `suiteState` fails for sandboxes without a `test/` directory by design
  ("never as passing" per the verifier contract) — observed identically
  before and after the fix; not a regression and not in scope.

## Open Questions

- None blocking. The `--depth feature` relative-import observation in the
  issue is documentation/behavior follow-up independent of the pubspec
  writer.
