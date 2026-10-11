# Test List: zfa-tdd-init-missing-flutter-app-deps (bug #1349)

Derived from `assessment.md` ("Tests to add or update"). Driven by the
TDD red-green-refactor loop; suite mirrors the hermetic CliRunner
pattern of `test/cli/writers/tdd/bug_1260_skin_dependency_patcher_test.dart`.

## Outer loop: acceptance behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| B-A1 | on a fresh Flutter project, `zfa tdd init` leaves a day-zero surface that is self-consistent: `lib/app.dart` exists, imports `package:zuraffa_flutter/zuraffa_flutter.dart`, and the pubspec declares both packages the module imports | AC-day-zero | DONE |

## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| B-U1 | init on a Flutter project adds `zuraffa_flutter: ^6.0.0` + `get_it: ^9.2.1` under `dependencies:` (before `dev_dependencies:`), never under dev | AC-runtime | DONE |
| B-U2 | the self-heal is idempotent: a second run adds nothing twice (`zuraffa_flutter` and `get_it` each appear exactly once) | AC-idempotent | DONE |
| B-U3 | already-declared deps are preserved byte-for-byte (dev_dependencies also complete, isolating the assertion) | AC-hand-edit | DONE |
| B-U4 | a pure-Dart project's pubspec is untouched by the Flutter app deps (non-Flutter flow unchanged; green pre-fix by design) | AC-scope | DONE |
| B-U5 | an empty inline `dependencies: {}` mapping is expanded to block style without a duplicate top-level section | AC-textual | DONE |
| B-U6 | a malformed (non-map) `dependencies:` value is a loud writer failure (exit != 0, `writer(s) failed`), not a crash | AC-loud | DONE |

## Test artifacts

- B-A1, B-U1..B-U6 → `test/cli/writers/tdd/bug_1349_init_flutter_app_deps_test.dart` (fast tier, hermetic temp fixtures)
