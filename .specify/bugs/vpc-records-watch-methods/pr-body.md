## Summary

`test/plugins/vpc_records_test.dart` (subtest `VPC generation uses Dart 3.0 Records for watch methods`) created a **pure-Dart** temp project (`name: zuraffa_test`, no `flutter:` dependency) and then asserted that `product_presenter.dart` / `product_controller.dart` were generated. Since the pure-Dart split (Constitution VII — Engine Purity), the presenter/controller/view plugins intentionally skip Flutter-dependent generation in pure-Dart packages, so those files were skipped and the test failed at `expect(presenterFile.existsSync(), isTrue)`.

This change adds a `flutter:` SDK dependency to the test's temp pubspec so the plugins generate the presenter/controller, and the existing Record-matrix assertions (presenter `watchProductRecord` returning `(Future<…> initial, Stream<…> updates)` + controller `final (initialFuture, updatesStream) = _presenter.watchProductRecord(id);` / `updatesStream.listen(...)`) validate correctly. Production behavior is unchanged — the VPC Record generation source was already correct.

## Changes

| File | Change |
|------|--------|
| `test/plugins/vpc_records_test.dart` | Add `flutter:` SDK dependency to the test pubspec so the temp project is detected as a Flutter project |

## Local Verification

`dart test test/plugins/vpc_records_test.dart` → `All tests passed!` (1/1);

## Assessment

- Assessment: `.specify/bugs/vpc-records-watch-methods/assessment.md`
