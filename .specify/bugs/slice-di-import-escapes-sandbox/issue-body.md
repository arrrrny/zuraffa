## Symptom

`zfa slice cut <name> --entry <point>` produces a `slice_di.dart` whose `import`
directives point outside the slice sandbox (via `../` traversal), so
`ImportVerifier` marks the slice unverifiable. The freshly cut slice should verify
clean and be exportable/runnable.

## Reproduction

```bash
dart test test/plugins/slice/slice_verify_integration_test.dart
dart test test/plugins/slice/slice_export_integration_test.dart
dart test test/plugins/slice/slice_e2e_test.dart
dart test test/plugins/slice/slice_polish_test.dart
dart test test/plugins/slice/runner/slice_runner_test.dart
```

Error seen:
```text
Error: Verification failed with 3 unresolved import(s) — the slice is NOT exportable.
unresolved: lib/src/di/slice_di.dart:7 "../../../../../../lib/src/di/usecases/get_product_usecase_di.dart" — escapes the slice sandbox via a relative path traversal
```

## Suspected Code Paths

- `lib/src/plugins/slice/capabilities/cut_slice_capability.dart:306-309` — `_relativeImport(fromDir: sandboxDir/lib/src/di, target: nodePath)` uses the **project-root** file as target, producing an escaping relative import. Should target the mirrored sandbox copy.
- `lib/src/plugins/slice/generators/sandbox_bootstrapper.dart:174-203` — emits `import '${real.importPath}';` verbatim.
- `lib/src/plugins/slice/verifier/import_verifier.dart:158-168` — rejects relative imports escaping the sandbox.
- `lib/src/plugins/slice/runner/slice_runner.dart:76-89` — `runSlice` verifies first, aborts before launch.

## Root Cause Hypothesis

`cut_slice_capability.dart:306` computes the `slice_di.dart` import path relative
to the project DI file instead of the mirrored sandbox copy. The mirror lives at
the same `lib/src/di/usecases/...` inside the sandbox, so the import should be the
sibling `usecases/get_product_usecase_di.dart`. Confidence: **high**.

## Severity

high — core slice feature fully broken (cut → verify → export → run all fail on any real project); 11 tests red.

## Failing tests covered

- slice_runner_test.dart: U51, U52/A22, A20 (FR-016)
- slice_export_integration_test.dart: A23, A24, A25, A27 (US8)
- slice_polish_test.dart: export reports progress (T074)
- slice_e2e_test.dart: T075 full lifecycle
- slice_verify_integration_test.dart: A16, A18 (US6)

Assessment: .specify/bugs/slice-di-import-escapes-sandbox/assessment.md
