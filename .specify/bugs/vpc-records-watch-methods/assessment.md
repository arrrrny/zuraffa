# Bug Assessment: `vpc_records_test` fails — VPC watch-record generation is skipped in pure-Dart test project

- **Slug**: vpc-records-watch-methods
- **Created**: 2026-08-23
- **Source**: pasted text (failing test output from `test/plugins/vpc_records_test.dart`)
- **Verdict**: valid (test is inconsistent with the current architecture; the source behavior is correct)
- **Severity**: low

## Report (verbatim or summarized)

Failing test file: `test/plugins/vpc_records_test.dart` (subtest `VPC generation uses Dart 3.0 Records for watch methods`). It runs `zfa make Product --methods=watch --with=vpc --state --force` inside a temp project whose `pubspec.yaml` is `name: zuraffa_test` — a **pure-Dart** package (no `flutter:` dependency) — and then asserts that `product_presenter.dart` and `product_controller.dart` exist and emit Dart 3.0 Record-based watch methods.

## Symptom

The generation prints three Engine-Purity skip warnings (`⚠️ Skipping view/presenter/controller generation: target project is a pure-Dart package`) and writes only the usecase and state files. `product_presenter.dart` / `product_controller.dart` are never created, so the test fails at `expect(presenterFile.existsSync(), isTrue)` with `Expected: true / Actual: <false>`.

## Reproduction

1. Create a temp dir with a pure-Dart `pubspec.yaml` (`name: zuraffa_test`, no `flutter:` key).
2. Run `zfa make Product --methods=watch --with=vpc --state --force` in that dir.
3. Observe: presenter/controller are skipped; only `watch_product_usecase.dart` and `product_state.dart` are written.
4. The test's `presenterFile.existsSync()` returns `false` → assertion fails.

## Suspected Code Paths

- `lib/src/plugins/presenter/presenter_plugin.dart:63` (`generateWithContext`) and the `controller`/`view` plugins gate generation on `detectProjectFlavor(outputDir) == ProjectFlavor.pureDart`, printing the Engine-Purity skip and returning `[]`. This is the direct cause of the missing presenter/controller.
- `lib/src/utils/project_flavor.dart` — `detectProjectFlavor` returns `pureDart` when the pubspec has no `flutter:` dependency. The test's pubspec has none.
- `lib/src/plugins/presenter/presenter_plugin.dart:795` (`_buildWatchRecordMethod`) and `lib/src/plugins/controller/controller_plugin_bodies.dart:863` — when generation actually runs, the presenter emits `watchProductRecord(String id)` returning the Record `(Future<Result<Product, AppFailure>> initial, Stream<Result<Product, AppFailure>> updates)` and `return (...first, ...)`, and the controller emits `final (initialFuture, updatesStream) = _presenter.watchProductRecord(id);` + `updatesStream.listen(...)`. These already match every assertion in the test, so once a view/presenter/controller is generated, the content checks pass.

## Root Cause Hypothesis

The test was written before the pure-Dart split (Constitution VII — Engine Purity). After that split, the presenter/controller/view plugins intentionally refuse to emit Flutter-widget/dependent code into a pure-Dart package. The test still creates a **pure-Dart** pubspec and asserts that presenter/controller files are generated, which now conflicts with that guard. The skip is correct and intentional; the **test is the part that is now inconsistent with the architecture** — it needs a Flutter project (a `flutter:` dependency in `pubspec.yaml`) for presenter/controller generation to run. Confidence: high.

## Proposed Remediation

**Preferred**: Update `test/plugins/vpc_records_test.dart` so the temp project is a Flutter project, by adding a `flutter:` SDK dependency to the `pubspec.yaml` written in `setUp` (line 38-39). The test only inspects generated file *content* (it never compiles the generated Flutter code), so `detectProjectFlavor` just needs to see `flutter:` in the pubspec. After this change the presenter/controller are generated and the existing Record assertions validate correctly, since `_buildWatchRecordMethod` and `controller_plugin_bodies.dart:863` are already correct.

**Alternatives**:
- Remove the pure-Dart skip in the presenter/controller/view plugins so `make --with=vpc --state` always emits Flutter-dependent code — **rejected**: it violates Constitution VII (Engine Purity) and would break `dart analyze` for pure-Dart consumers.
- Add a flag to force generation in pure-Dart — **rejected**: same constitution violation.

**Files likely to change**:
- `test/plugins/vpc_records_test.dart` (add `flutter:` to the test pubspec in `setUp`).

**Tests to add or update**:
- The existing subtest already covers the Record matrix once presenter/controller generate; no new test needed. Optionally add a sibling assertion that a pure-Dart `make --with=vpc` prints the skip warning (locking in Engine-Purity behavior), but that is out of scope for getting green.

## Risks & Considerations

- The fix is test-only; it changes no production behavior. The source (VPC Record watch generation + controller destructuring) is already correct.
- Adding `flutter:` to the test pubspec may cause `make` to also attempt Flutter-only layers if future `--with` values are added; the current test only uses `--with=vpc`, so only presenter/controller/state are generated.

## Open Questions

- None.
