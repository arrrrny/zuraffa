# Bug Assessment: Slice cut generates slice_di.dart with relative imports that escape the sandbox

- **Slug**: slice-di-import-escapes-sandbox
- **Created**: 2026-08-30
- **Source**: pasted text (failing test output from `dart test`)
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

From the failing test run (13 failures total; 11 of them share this root cause):

```text
Error: Verification failed with 3 unresolved import(s) — the slice is NOT exportable.
unresolved: lib/src/di/slice_di.dart:7 "../../../../../../lib/src/di/usecases/get_product_usecase_di.dart" — escapes the slice sandbox via a relative path traversal
unresolved: lib/src/di/slice_di.dart:8 "../../../../../../lib/src/di/usecases/update_product_usecase_di.dart" — escapes the slice sandbox via a relative path traversal
unresolved: lib/src/di/slice_di.dart:9 "../../../../../../lib/src/di/usecases/fetch_settings_usecase_di.dart" — escapes the slice sandbox via a relative path traversal
```

The same `slice_di.dart` escaping-import rejection also drives the `slice run`
launches (SliceRunner verifies first, then aborts before `flutter run`) and the
verify/export/e2e/polish tests below.

## Symptom

`zfa slice cut <name> --entry <point>` produces a `slice_di.dart` whose `import`
directives point outside the slice sandbox (via `../` traversal), so
`ImportVerifier` marks the slice unverifiable. Expected: the freshly cut slice
verifies clean and is exportable/runnable.

## Reproduction

Any of the commands below reproduces it (each fails on a freshly cut slice):

```bash
dart test test/plugins/slice/slice_verify_integration_test.dart
dart test test/plugins/slice/slice_export_integration_test.dart
dart test test/plugins/slice/slice_e2e_test.dart
dart test test/plugins/slice/slice_polish_test.dart
dart test test/plugins/slice/runner/slice_runner_test.dart
```

Or manually: `dart run bin/zfa.dart slice cut product_feature --entry product`
then inspect `.zuraffa/slices/product_feature/lib/src/di/slice_di.dart` — the
`usecases/*_di.dart` imports contain `../../../../../../lib/src/...`.

## Suspected Code Paths

- `lib/src/plugins/slice/capabilities/cut_slice_capability.dart:306-309` — `_relativeImport(fromDir: p.join(sandboxDir, 'lib', 'src', 'di'), target: nodePath)` uses `nodePath` (the **project-root** file path) as the target, so the resulting relative import points outside the sandbox. It should target the **mirrored** copy inside the sandbox (`p.join(sandboxDir, p.relative(nodePath, from: projectRoot))`), which is a sibling `usecases/...` path.
- `lib/src/plugins/slice/generators/sandbox_bootstrapper.dart:174-203` — `generateSliceDi` emits `import '${real.importPath}';` verbatim; it assumes `importPath` is relative to `slice_di.dart` and inside the sandbox.
- `lib/src/plugins/slice/verifier/import_verifier.dart:158-168` — rejects any relative import whose resolved target is not `isWithin(sandboxDir)`, producing the "escapes the slice sandbox via a relative path traversal" issue.
- `lib/src/plugins/slice/runner/slice_runner.dart:76-89` — `runSlice` verifies first and returns `launched: false` when verification fails, which is why `slice run` aborts before launch and the runner tests see an empty `launched` list / `exitCode 1`.

## Root Cause Hypothesis

`cut_slice_capability.dart:306` computes the `slice_di.dart` import path relative
to the **project** DI file (`nodePath`) instead of the **mirrored sandbox** copy.
The mirror of `lib/src/di/usecases/get_product_usecase_di.dart` lives inside the
sandbox at the same `lib/src/di/usecases/...` location, so the correct relative
import from `sandbox/lib/src/di/` is the sibling `usecases/get_product_usecase_di.dart`.
The generated `../../../../../../lib/src/di/usecases/...` resolves to
`.zuraffa/lib/src/di/...` (outside the slice sandbox), so `ImportVerifier`
rejects it. Confidence: **high**.

## Proposed Remediation

**Preferred**: In `cut_slice_capability.dart:306`, change the `target` passed to
`_relativeImport` from `nodePath` to the mirrored file inside the sandbox:

```dart
importPath: _relativeImport(
  fromDir: p.join(sandboxDir, 'lib', 'src', 'di'),
  target: p.join(sandboxDir, p.relative(nodePath, from: projectRoot)),
),
```

This makes the import a sibling path (`usecases/get_product_usecase_di.dart`)
that resolves inside the sandbox. Confirm the usecase DI files are actually
mirrored into the sandbox at that location (they are — the slice graph walks
`lib/src/di/` per the `rel.startsWith('lib/src/di/')` filter at line 299).

**Alternatives** (optional):
- Have `generateSliceDi` accept sandbox-relative import paths instead of computing them in the capability (push the contract down into `SandboxBootstrapper`).

**Files likely to change**:
- `lib/src/plugins/slice/capabilities/cut_slice_capability.dart`
- (possibly) `lib/src/plugins/slice/generators/sandbox_bootstrapper.dart`

**Tests to add or update**:
- The 11 listed below already lock the behavior; add a focused unit test asserting that every `import` in a freshly generated `slice_di.dart` resolves inside the sandbox (no `../` escaping).

## Risks & Considerations

- If the usecase DI files are NOT mirrored into the sandbox at some depth levels, fixing only the import path could instead leave a missing-in-sandbox error. Verify the `lib/src/di/` mirror happens at all relevant depths.
- `slice run` shells out to `flutter` — unaffected by this change once verification passes.
- This is a regression: previously-cut slices verified clean, so the import-path computation was changed recently.

## Open Questions

- None blocking; root cause is confirmed by the error output.

## Failing tests covered by this assessment

1. `test/plugins/slice/runner/slice_runner_test.dart: SliceRunner (FR-016) U51: builds flutter run -t <main_slice> from the project root`
2. `test/plugins/slice/runner/slice_runner_test.dart: SliceRunner (FR-016) U52/A22 (T108): extra flags pass through verbatim`
3. `test/plugins/slice/runner/slice_runner_test.dart: SliceRunner (FR-016) A20 (T106): the launch uses flutter run with -t from the root (direct runner API)`
4. `test/plugins/slice/slice_export_integration_test.dart: slice export (US8) A23 (T109): tar.gz archive with filtered pubspec`
5. `test/plugins/slice/slice_export_integration_test.dart: slice export (US8) A24 (T110): github export pushes with SLICE.md as README`
6. `test/plugins/slice/slice_export_integration_test.dart: slice export (US8) A25 (T111): repo name auto-generated when --repo omitted`
7. `test/plugins/slice/slice_export_integration_test.dart: slice import (US8) A27 (T113): import pulls the repo back over the sandbox`
8. `test/plugins/slice/slice_polish_test.dart: progress reporting (T074) export reports progress`
9. `test/plugins/slice/slice_e2e_test.dart: T075: cut → verify → modify → merge full lifecycle`
10. `test/plugins/slice/slice_verify_integration_test.dart: slice verify (US6, FR-013..FR-015) A16 (T102): a complete slice verifies clean`
11. `test/plugins/slice/slice_verify_integration_test.dart: slice verify (US6, FR-013..FR-015) A18 (T104): --analyze runs dart analyze and reports errors`
