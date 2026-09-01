# Bug Issue: test package still missing from dev_dependencies after zfa setup

- **Slug**: test-package-missing-after-setup
- **Fetched**: 2026-09-01T17:23:21Z
- **Issue**: 716
- **URL**: https://github.com/arrrrny/zuraffa/issues/716
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**:

## Body

## Bug Description

The `test` package is still missing from `dev_dependencies` after `zfa setup`. Generated tests use `package:test/test.dart` which does not resolve, making them uncompilable out of the box.

## Confirmation (v6.1.0, fresh project)

Just tested on a brand new project created with `zfa setup --platforms=ios,android,macos` at zfa v6.1.0.

**Result:** BUG STILL PRESENT.

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
  build_runner: ^2.16.0
  json_serializable: ^6.14.1
  mocktail: ^1.0.0
  coverage: ^1.6.0
  mutation_test: ^1.0.0
```

**Missing:** `test: ^1.0.0`

Generated tests use `package:test/test.dart` which does not resolve:

```
Error: Could not resolve the package 'test' in 'package:test/test.dart'.
test/tdd/a7_test.dart:16:8: Error: Not found: 'package:test/test.dart'
import 'package:test/test.dart';
       ^
```

## Steps to Reproduce

1. `zfa setup --platforms=ios,android,macos zik_zak_tdd`
2. `cd zik_zak_tdd && zfa tdd init`
3. Copy any spec (e.g. `specs/001-app-bootstrap/spec.md`)
4. `zfa tdd plan 001-app-bootstrap`
5. `zfa tdd gen A7 --feature=001-app-bootstrap`
6. `flutter test test/tdd/a7_test.dart` → **compile error**

## Workaround

`flutter pub add dev:test`

## Environment

- zfa version: v6.1.0
- Flutter version: 3.41.0+
- Dart version: 3.11.0+
- Platform: macOS

## Comments

None.
