# Issue: `zfa tdd run` doesn't support multiple features in same project (ownership conflict)

- **Slug**: tdd-run-multi-feature-ownership
- **Fetched**: 2026-09-03
- **Issue**: 801
- **URL**: https://github.com/arrrrny/zuraffa/issues/801
- **State**: open
- **Severity**: high (labels: bug)
- **Author**: arrrrny

## Body (verbatim)

## Bug Description

`zfa tdd run` does not support multiple features in the same project. When
running a second feature spec, it fails with `ownership conflict` because the
test files from the first feature (`test/tdd/a1_test.dart`, etc.) still exist
on disk but are not registered in the second feature's `artifacts.json`.

## Confirmation (v6.1.0 with all latest fixes)

Tested on a project with 3 specs (001, 004, 005).

**Result:** BUG CONFIRMED.

First run (spec 004) succeeds, creating `test/tdd/a1_test.dart` through
`test/tdd/u10_test.dart`.

Second run (spec 005) fails:

```
$ zfa tdd run 005-hive-caching-layer
zfa tdd run: feature 005-hive-caching-layer — 17 behavior(s)
[run] A1 gen -> error
   ❌ Error: Bad state: zfa tdd gen: ownership conflict — OwnershipConflict:
   test file "/Users/ahmettok/zik_zak_tdd/test/tdd/a1_test.dart" exists on
   disk but the registry has no recorded ownership. Refusing to overwrite
   non-owned content.
```

The test file path `test/tdd/a1_test.dart` is shared between features, but
the ownership registry is per-feature.

## Steps to Reproduce

1. `zfa setup --platforms=macos zik_zak_tdd`
2. `cd zik_zak_tdd && zfa tdd init`
3. Copy two specs: `specs/001-app-bootstrap/spec.md` and
   `specs/004-dependency-injection/spec.md`
4. `zfa tdd run 001-app-bootstrap` (succeeds, creates test/tdd/a1_test.dart
   etc.)
5. `zfa tdd run 004-dependency-injection`
   → **exit 1**: `ownership conflict` on A1 gen

## Workaround

Manually move the first feature's tdd files aside before running the second:

```bash
mv test/tdd /tmp/tdd_001_backup
mv lib/tdd /tmp/tdd_001_lib_backup
```

## Expected Behavior

The TDD cycle should support multiple features in the same project, either
by:

- Using per-feature subdirectories (e.g.,
  `test/tdd/001-app-bootstrap/a1_test.dart`)
- Cleaning up the first feature's artifacts when starting the second
- Supporting a `zfa tdd run --clean` flag

## Environment

- zfa version: v6.1.0 (with all latest fixes)
- Flutter version: 3.41.0+
- Dart version: 3.11.0+
- Platform: macOS
