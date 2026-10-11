# Red Evidence: zfa-tdd-init-missing-flutter-app-deps (bug #1349)

Suite: `test/cli/writers/tdd/bug_1349_init_flutter_app_deps_test.dart`
Run BEFORE any production change (HEAD d23bde35, Dart 3.13.3):

```
command: dart test test/cli/writers/tdd/bug_1349_init_flutter_app_deps_test.dart
exit: 1
result: 00:00 +2 -5: Some tests failed.
```

Failing (the bug, reproduced by test):

- B-U1 — `Flutter project: init adds zuraffa_flutter + get_it under dependencies`
  ```
  Expected: contains 'zuraffa_flutter: ^6.0.0'
    Actual: 'name: bug1349_init_fixture\nenvironment:\n  sdk: ^3.11.0\ndependencies:\n  flutter:\n    sdk: flutter\n\ndev_dependencies:\n  flutter_test:\n ...'
    Which: does not contain 'zuraffa_flutter: ^6.0.0'
  ```
- B-A1 — `Flutter project: the day-zero surface is self-consistent after init`
- B-U2 — `self-heal is idempotent: a second run adds nothing twice`
- B-U5 — `empty inline dependencies mapping is expanded without duplication`
- B-U6 — `malformed dependencies value is reported as a writer failure`
  ```
  Expected: not <0>
    Actual: <0>
  ```
  (pre-fix, init exits 0 on a malformed `dependencies:` because the value
  is never inspected — the self-heal does not exist yet)

Green pre-fix (preserved invariants, must stay green post-fix):

- B-U3 — already-declared deps preserved byte-for-byte
- B-U4 — pure-Dart pubspec untouched by the Flutter app deps

One test-file fix during authoring (before first red run): the B-U3
fixture initially omitted the complete dev_dependencies block, so the
legitimate dev-deps self-heal mutated the file and the byte-for-byte
assertion was invalid; the fixture now seeds a complete
dev_dependencies section. The first RED run above is from the corrected
suite.
