# Bug Issue: [BUG] zfa tdd gen: missing test package in dev_dependencies

- **Slug**: zfa-tdd-missing-test-package
- **Fetched**: 2026-09-01
- **Issue**: 688
- **URL**: https://github.com/arrrrny/zuraffa/issues/688
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny (Ahmet TOK)
- **Labels**: bug

## Body

zfa tdd gen generates tests that import package:test/test.dart, but the test package is NOT included in dev_dependencies by zfa setup or zfa tdd init.

zfa setup adds mocktail, coverage, and mutation_test as TDD dev_dependencies, but forgets test, making generated tests uncompilable out of the box.

## Steps to Reproduce

1. zfa setup --platforms=ios,android,macos zik_zak_tdd
2. cd zik_zak_tdd && zfa tdd init
3. Copy any spec (e.g. specs/001-app-bootstrap/spec.md)
4. zfa tdd plan 001-app-bootstrap
5. zfa tdd gen A7 --feature=001-app-bootstrap
6. flutter test test/tdd/a7_test.dart → compile error: Couldn't resolve the package test in package:test/test.dart

## Expected Behavior

Generated tests should compile and run (fail with assertion, but compile cleanly).

## Actual Behavior

package:test/test.dart is not found. The test package is absent from pubspec.yaml dev_dependencies.

Missing: test: ^1.0.0

## Workaround

Manually add test: ^1.0.0 to dev_dependencies and run flutter pub get.

## Environment

- zfa version: current
- Flutter version: 3.41.0+
- Dart version: 3.11.0+
- Platform: macOS

## Comments

None.
