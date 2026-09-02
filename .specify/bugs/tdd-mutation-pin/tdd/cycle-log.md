# Cycle Log — Bug #755: tdd-mutation-pin

Single-cycle bug fix. The bug has a narrow blast radius (one source file,
two `static const Map<String, String>` literals), so the loop is one red,
one green, no refactor.

## Cycle 1 — pin maps match MutationVerifier v1.8.0+ format

### Red

Command:

```bash
dart test --preset=all \
  test/cli/writers/tdd/pubspec_dev_dependencies_patcher_test.dart \
  --name "755"
```

The `--preset=all` is required because the test file carries `@Tags(['slow'])`
and the default `dart test` invocation excludes the slow tier (see
`dart_test.yaml`). `--name "755"` filters to the new `bug #755` group.

Observed output (verbatim, only the failing assertions shown — the runner
printed 8 failures in total):

```
00:00 +0 -1: bug #755 — pins match MutationVerifier v1.8.0+ format flutterDevDependencies pins mutation_test at ^1.8.0 (matches verifier) [E]
  Expected: '^1.8.0'
    Actual: '^1.0.0'
     Which: is different.
            Expected: ^1.8.0
              Actual: ^1.0.0
                         ^
             Differ at offset 3

00:00 +0 -3: bug #755 — pins match MutationVerifier v1.8.0+ format flutterDevDependencies pins coverage at ^1.15.1 (current latest) [E]
  Expected: '^1.15.1'
    Actual: '^1.6.0'

00:00 +0 -5: bug #755 — pins match MutationVerifier v1.8.0+ format flutterDevDependencies does NOT include mocktail (unused by generated test templates) [E]
  Expected: false
    Actual: <true>

00:00 +0 -7: bug #755 — pins match MutationVerifier v1.8.0+ format flutter-mode ensure writes mutation_test: ^1.8.0 into pubspec.yaml [E]
  Expected: '^1.8.0'
    Actual: '^1.0.0'

00:00 +0 -8: Some tests failed.
Failing tests:
  test/cli/writers/tdd/pubspec_dev_dependencies_patcher_test.dart: bug #755 — pins match MutationVerifier v1.8.0+ format dart-mode ensure writes mutation_test: ^1.8.0 into pubspec.yaml
  test/cli/writers/tdd/pubspec_dev_dependencies_patcher_test.dart: bug #755 — pins match MutationVerifier v1.8.0+ format dartDevDependencies does NOT include mocktail (unused by generated test templates)
  test/cli/writers/tdd/pubspec_dev_dependencies_patcher_test.dart: bug #755 — pins match MutationVerifier v1.8.0+ format dartDevDependencies pins coverage at ^1.15.1 (current latest)
  test/cli/writers/tdd/pubspec_dev_dependencies_patcher_test.dart: bug #755 — pins match MutationVerifier v1.8.0+ format dartDevDependencies pins mutation_test at ^1.8.0 (matches verifier)
  ... and 4 more
```

All 8 new behaviors failed against the unmodified source — the test
class could not pass with `mutation_test: ^1.0.0`, `coverage: ^1.6.0`,
and `mocktail: ^1.0.0` still pinned in the source maps. The bug is
reproduced.

### Green

Edit applied to `lib/src/cli/writers/tdd/pubspec_dev_dependencies_patcher.dart`:

- `flutterDevDependencies`: removed `mocktail: ^1.0.0`; bumped `coverage`
  from `^1.6.0` to `^1.15.1`; bumped `mutation_test` from `^1.0.0` to
  `^1.8.0`.
- `dartDevDependencies`: same three changes.
- Added a `Bug #755:` comment block above both maps documenting why.

Three pre-existing tests in the same file encoded the old buggy contract
(`added.length == 7`, `mocktail` expected in the written pubspec, etc.).
They were updated to assert the new contract — the assertions were
tightening (e.g. `7 -> 6`), not loosening, so this is not a weakened
existing test (see Phase 2 of `verification.md`).

Command:

```bash
dart test --preset=all \
  test/cli/writers/tdd/pubspec_dev_dependencies_patcher_test.dart
```

Observed output (final lines):

```
00:00 +16: bug #755 — pins match MutationVerifier v1.8.0+ format dart-mode ensure writes mutation_test: ^1.8.0 into pubspec.yaml
00:00 +17: All tests passed!
```

All 17 tests pass (8 new bug-#755 tests + 9 pre-existing tests after
updating the 3 that encoded the old buggy contract).

### Refactor

None required. The change is a version-pin bump on two `static const`
maps; there is no behavior to refactor.
