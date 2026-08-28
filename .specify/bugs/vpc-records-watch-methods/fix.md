# Bug Fix: `vpc_records_test` fails — VPC watch-record generation skipped in pure-Dart test project

- **Slug**: vpc-records-watch-methods
- **Fixed**: 2026-08-23
- **Assessment**: ./assessment.md
- **Status**: applied

## Summary

The source behavior is correct: the presenter/controller/view plugins deliberately
skip Flutter-dependent generation in pure-Dart packages (Constitution VII — Engine
Purity). The bug was that `vpc_records_test.dart` created a pure-Dart `pubspec.yaml`
(no `flutter:` dependency) and then asserted that `product_presenter.dart` /
`product_controller.dart` (which emit Dart 3.0 Records for watch methods) were
generated. With the pure-Dart guard in place, those files are skipped, so the test
failed at `expect(presenterFile.existsSync(), isTrue)`. The fix makes the temp
project a Flutter project by adding a `flutter:` SDK dependency, so the plugins
generate the presenter/controller and the existing Record assertions validate.

## Changes

| File | Change | Notes |
|------|--------|-------|
| `test/plugins/vpc_records_test.dart` | modified | Replace the `name: zuraffa_test` pubspec written in `setUp` with one that adds `dependencies: flutter: sdk: flutter`, so the temp project is detected as a Flutter project. |

## Diff Highlights (optional)

```diff
-    ).writeAsString('name: zuraffa_test');
+    ).writeAsString('''
+name: zuraffa_test
+dependencies:
+  flutter:
+    sdk: flutter
+''');
```

## Tests Added or Updated

- `test/plugins/vpc_records_test.dart::VPC generation uses Dart 3.0 Records for watch methods` — now passes because the presenter/controller are generated and emit `watchProductRecord` returning `(Future<…> initial, Stream<…> updates)` plus the controller's `final (initialFuture, updatesStream) = _presenter.watchProductRecord(id);` and `updatesStream.listen(...)`.

## Local Verification

- Commands run: `dart test test/plugins/vpc_records_test.dart` → `All tests passed!` (1/1, ~6s).
- Manual checks: the generation now reports `✨ Created: 5 files` including
  `product_presenter.dart` / `product_controller.dart`; the pure-Dart Engine-Purity
  skip is preserved for genuine pure-Dart projects.

## Deviations from Assessment

None. The applied change matches the preferred remediation in `assessment.md` exactly.

## Follow-ups

- Optionally add a sibling assertion that a genuine pure-Dart `make --with=vpc` prints
  the Engine-Purity skip warning, to lock in that behavior (out of scope for green).
