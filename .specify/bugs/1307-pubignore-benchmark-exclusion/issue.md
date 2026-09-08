# Bug Issue: Published package 6.2.0/6.2.1 broken — .pubignore 'benchmark/' excludes lib/src/core/benchmark/ but zuraffa.dart still exports benchmark_contract.dart

- **Slug**: 1307-pubignore-benchmark-exclusion
- **Fetched**: 2026-09-08T12:28:40Z
- **Issue**: 1307
- **URL**: https://github.com/arrrrny/zuraffa/issues/1307
- **State**: open
- **Severity**: high (per bug report; no severity:* label applied)
- **Author**: arrrrrny
- **Labels**: (none)

## Body

## Summary
Every project scaffolded with `zfa setup` (and any consumer of `zuraffa: ^6.2.0`) fails to compile at day zero because the **published pub.dev package is missing `lib/src/core/benchmark/`** while `lib/zuraffa.dart` still exports it.

## Repro
```bash
zfa setup todo_planner --platforms=ios,macos
cd todo_planner && flutter pub get && flutter test
```

## Expected
Day-zero baseline green (`test/bootstrap_smoke_test.dart` passes).

## Actual
```
../../.pub-cache/hosted/pub.dev/zuraffa-6.2.1/lib/zuraffa.dart:294:1: Error: Error when reading
'.../zuraffa-6.2.1/lib/src/core/benchmark/benchmark_contract.dart': No such file or directory
export 'src/core/benchmark/benchmark_contract.dart';
```
Verified on pub.dev tarballs for **both 6.2.0 and 6.2.1**: `lib/src/core/benchmark/` is entirely absent, yet `lib/zuraffa.dart` contains 11 benchmark-related export lines.

## Root cause
`.pubignore` contains the line `benchmark/`. Pub's ignore rules follow gitignore semantics: a pattern with a trailing slash and no leading slash matches directories **at any depth**, so it excludes not only the top-level `benchmark/` folder but also `lib/src/core/benchmark/`. The export in `lib/zuraffa.dart` was then published pointing at a file that wasn't in the tarball.

## Suggested fix
1. Anchor the ignore to the root: change `benchmark/` → `/benchmark/` (and audit sibling entries like `benchmarks/`, `test/fixtures/`, `specs/` for the same any-depth hazard).
2. Add a publish-time guard: after `dart pub publish --dry-run`, verify every file referenced by `export`/`part` directives in `lib/` exists in the published file set (e.g. a test that parses `lib/zuraffa.dart` exports and asserts each resolves under the tree pub would upload).
3. Republish 6.2.2 with the corrected ignore so the export set and tarball agree.

## Comments

None.
