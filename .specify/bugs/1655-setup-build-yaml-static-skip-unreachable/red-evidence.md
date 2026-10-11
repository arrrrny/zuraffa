# Red Evidence — Bug #1655 (static first-build skip unreachable for zfa setup-created apps)

Captured 2026-09-15, this session, on `fix/1655-setup-build-yaml-static-skip-unreachable`
at the #1641 merge base (`f011e3fb`), Dart 3.13.4 (stable), BEFORE the fix.

## Suite 1 — the new #1655 tests (pre-fix)

```
dart test test/plugins/tdd/services/build_relevance_test.dart
→ 00:00 +30 -1: Some tests failed.

Failing tests:
  test/plugins/tdd/services/build_relevance_test.dart: refactorBuildSkipNote
  (issue #1624) a fresh app with the pristine zfa setup build.yaml skips the
  first build statically (issue #1655 — the reported bug)

  Expected: 'refactor build pass skipped: build_runner has never run here …'
  Actual:   <null>
  Which:    not an <Instance of 'String'>
```

The failing assertion IS the issue's bug: a fresh app whose build.yaml is
byte-identical to what `zfa setup` writes (`DependencyWirer.buildYamlContent`)
with zero builder-facing files gets `null` (run the build) from
`refactorBuildSkipNote` — the `_staticFirstBuildSkipNote` build.yaml-existence
trigger (`lib/src/plugins/tdd/services/build_relevance.dart`, the #1634 rule
1c) short-circuits before the static scan, so the first refactor pays the
entrypoint AOT compile.

The #1655 guard tests passed pre-fix, as expected for contract guards (they
pin behavior that must survive the fix):

- pristine template + @Zorphy annotation → run (null) — passes (trivially
  pre-fix: any build.yaml runs; post-fix the scan must keep firing)
- MODIFIED setup template → run (null) — passes (criterion 2)
- pristine template + non-Dart source in a walked root → run (null) — passes
- user-authored build.yaml (the #1634 test, custom content) → run (null) —
  passes (criterion 2)
