# Bug Verification: `zfa make` crud+vpc+route output compiles (markStale, untyped path params, gate misattribution)

- **Slug**: 1675-make-crud-vpc-route-compile
- **Tested**: 2026-09-18
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: verified
- **TDD verification**: ./tdd/verification.md (TDD mode — verdict: verified)

## Summary

The repro no longer produces non-compiling Dart: the cache-aware repository
delete body emits `await _cachePolicy.invalidate('todo_cache');` (published
API), the generated route module parses the id path parameter per the bound
field type (`int.parse(state.pathParameters['id']!)` for `id:int`), and the
analyze gate attributes `zfa make` output to the generator. The extended
spec-1003 compile gate compiles the emitted cached repository (now with
`delete`) against this package's `CachePolicy` API — the exact lane the
skew previously escaped through — and passes.

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| RED (pre-fix), driver | `dart test test/fixes/bug_1675_make_crud_vpc_route_compile_test.dart` | FAIL × 5 — the RIGHT failures | emitted `markStale` (G1), emitted raw `id: state.pathParameters['id']!` (G2), `hand-authored offending (not generator output): lib/src/data/repositories/data_todo_repository.dart, lib/src/routing/todo_routes.dart` (G3) — the issue's three errors, byte-for-byte |
| RED (pre-fix), compile gate | cached variant with `delete`, generator fix `git stash`-reverted | FAIL | `error - cached/data/repositories/data_product_repository.dart:48:24 - The method 'markStale' isn't defined for the type 'CachePolicy'. ... - undefined_method` |
| GREEN (post-fix), driver | same driver command | PASS | `+5: All tests passed!` |
| GREEN (post-fix), compile gate | `dart test --preset=all test/plugins/repository/repository_compile_test.dart` | PASS | cached delete body compiles against the package API |
| GREEN (post-fix), route suite | `dart test test/plugins/route/` | PASS | `+115` — includes the #336 route-table pins |
| GREEN (post-fix), repository suite | `dart test test/plugins/repository/` | PASS | `+54` |
| GREEN (post-fix), gate unit suite | `dart test --preset=all test/commands/build_command_unit_test.dart` | PASS | `+55` — includes `verifyAnalyzeOrFail` over the repo's own lib |
| CLI e2e spot check | `zfa make Todo --preset=crud --vpc --state --route --mock --use-mock --test --cache --methods=get,getList,create,update,delete` in a consumer sandbox on published zuraffa ^6.1.0; re-emit the cached repository | PASS | `data_todo_repository.dart:82` → `await _cachePolicy.invalidate('todo_cache');` (the exact file:line the issue cites) |
| Analyzer, touched files | `dart analyze` over all 6 touched files | PASS | `No issues found!` |
| Format gate | `dart format .` → `dart format --output=none --set-exit-if-changed .` | PASS | 2944 files, 0 changed |
| Regression sweep | `test/cli` (+276), `test/core` (+687), `test/commands` (+346, no failures), issue #942 (+6), issue #417 (+7) | PASS | no new failures from this fix |

## Pre-existing failures (unrelated, flagged)

- `test/regression/issue_294_entity_without_id_test.dart` "Gap 1" fails on
  the PRISTINE merge-base HEAD identically (verified with this branch's
  changes stashed) — not caused by this fix.
- Flutter-tagged self-hosting suites (`test/templates/self_hosting/*`,
  `@Tags(['flutter'])`) cannot load in this environment (no Flutter SDK);
  they are excluded from the CI fast lane by design.

## Success criteria

| Criterion | Status |
|-----------|--------|
| (1) emitted API calls exist in the resolved package | PROVED (G1 + compile gate + CLI e2e spot check) |
| (2) path params parsed per bound field type | PROVED (G2 two-sided emitted-source pin; route semantics unchanged) |
| (3) analyze gate attributes generator output correctly | PROVED (G3 three-way, incl. byte-for-byte issue excerpt + Windows shapes) |
| (4) full repro compiles through `zfa build` without hand-patching | PROVED at the surface this environment can execute (repository compile gate green; route emission via the same `generateWithContext` path green). The `zfa setup todo_app --platforms=macos` front half requires the Flutter SDK, which this environment does not have; the generator-side equivalent (plugin path + compile gate + CLI repository regen) is fully exercised and green. |
