# GREEN evidence (e2e) — captured 2026-09-01T18:09:56Z

## pubspec.yaml after fix (zfa source with patcher fix)
```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
  build_runner: ^2.16.0
  json_serializable: ^6.14.1

  test: ^1.0.0
  mocktail: ^1.0.0
  coverage: ^1.6.0
  mutation_test: ^1.0.0
flutter:
```

## flutter pub get resolves test alongside flutter_test
```
+ test 1.31.1  (pub deps: - test 1.31.1; test_api 0.7.12 shared with flutter_test — no conflict)
```

## flutter test test/tdd/a1_test.dart (compiles; honest-red assertion only)
```
00:00 +0 -1: A1 (AC-1) a `toggle` method is generated in the repository interface, usecase, datasources (remote + local), presenter, controller, and state. [E]
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_a1 not implemented>
00:00 +0 -1: Some tests failed.
```

## day-zero baseline: flutter test (smoke green +1, a1 honest-red by design)
```
00:00 +1 -1: /home/z/my-project/repro716/test/tdd/a1_test.dart: A1 (AC-1) ... [E]
00:00 +1 -1: Some tests failed.
(+1 = test/bootstrap_smoke_test.dart green day zero; -1 = a1_test honest-red
 via UnimplementedError assertion, NOT a compile/load error)
```
