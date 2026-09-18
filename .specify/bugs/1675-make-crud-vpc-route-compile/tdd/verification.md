# TDD Verification: 1675-make-crud-vpc-route-compile

- **Slug**: 1675-make-crud-vpc-route-compile
- **Verified**: 2026-09-18
- **Method**: real red → green over the in-process generator subjects
  (`RoutePlugin.generateWithContext` — the exact `zfa make` plugin path;
  `RepositoryPlugin.generateWithContext` with cache on; the
  `BuildCommand.analyzeGateRemedyLines` classifier), plus the spec-1003
  compile gate (self-contained pure-Dart fixture with a path dependency on
  this package — the "compiles the emitted repository against the published
  package API" referee), run against the REAL files in this session.
- **Deterministic-engine note**: `zfa tdd verify` was not dispatched —
  this bug directory has no `tdd/artifacts.json` scope for the
  step-spawning pipeline and the subject under fix is this repository
  itself, so the loop evidence is the driver-level run below (the
  established bug-dir pattern, cf. 1669-graceful-exit-consumes-marker,
  1483-vacuous-green-remedy-wrong-file). The `tdd` extension v1.1.2 is
  installed and enabled in this repo (specify CLI 1.0.9.dev0;
  `specify extension list` → "✓ TDD Extension").
- **Result**: verified — every check below is from an ACTUAL run in this
  session on the fix branch; nothing is copied or back-dated.

## Checks

| # | Check | Command | Result | Evidence |
|---|-------|---------|--------|----------|
| 1 | Analyzer, touched files | `dart analyze lib/src/commands/build_command.dart lib/src/plugins/repository/generators/implementation_generator_cached.dart lib/src/plugins/route/route_plugin.dart test/fixes/bug_1675_make_crud_vpc_route_compile_test.dart test/plugins/repository/repository_compile_test.dart test/commands/build_command_unit_test.dart` | PASS | `No issues found!` |
| 2 | RED (pre-fix) — driver | `dart test test/fixes/bug_1675_make_crud_vpc_route_compile_test.dart` on the tests alone | FAIL × 5 — the RIGHT failures | G1: emitted `await _cachePolicy.markStale('todo_cache');` in the delete body (the issue's `undefined_method`, byte-for-byte); G2: emitted `id: state.pathParameters['id']!` (raw String into the int?-typed view field, `todo_routes.dart`); G3 × 3: `hand-authored offending (not generator output): lib/src/data/repositories/data_todo_repository.dart, lib/src/routing/todo_routes.dart` — the misattribution, byte-for-byte |
| 3 | RED (pre-fix) — compile gate (generator fix reverted via `git stash`) | `dart test --preset=all test/plugins/repository/repository_compile_test.dart` with the extended cached variant | FAIL — the RIGHT failure | `error - cached/data/repositories/data_product_repository.dart:48:24 - The method 'markStale' isn't defined for the type 'CachePolicy'. ... - undefined_method` — proves the extended gate actually catches the skew |
| 4 | GREEN (post-fix) — driver | same driver command, fix applied | PASS | `00:00 +5: All tests passed!` |
| 5 | GREEN (post-fix) — compile gate | `dart test --preset=all test/plugins/repository/repository_compile_test.dart` (cached variant now `methods: ['get','delete']`) | PASS | `+1: All tests passed!` — the cache-aware delete body compiles against the package API |
| 6 | GREEN — route plugin suite | `dart test test/plugins/route/` | PASS | `+115: All tests passed!` (includes the #336 route-table pins) |
| 7 | GREEN — repository plugin suite | `dart test test/plugins/repository/` | PASS | `+54: All tests passed!` |
| 8 | GREEN — analyze-gate unit suite (incl. updated label pin + `verifyAnalyzeOrFail` over the repo's own lib) | `dart test --preset=all test/commands/build_command_unit_test.dart` | PASS | `+55: All tests passed!` |
| 9 | GREEN — CLI e2e spot check | `zfa make Todo --preset=crud --vpc --state --route --mock --use-mock --test --cache --methods=...` in a pure-Dart consumer sandbox (published zuraffa ^6.1.0 resolved), re-emit the cached repository | PASS | `lib/src/data/repositories/data_todo_repository.dart:82` now emits `await _cachePolicy.invalidate('todo_cache');` (the exact file:line the issue cites) |
| 10 | Regression — issue #942 / #417 suites (drive `generateWithContext`) | `dart test --preset=all test/regression/issue_942_entity_name_collides_framework_export_test.dart test/regression/issue_417_mock_datasource_missing_interface_test.dart` | PASS | `+6` (942) and `+7 -1` where the -1 is the PRE-EXISTING `issue_294` Gap-1 failure (fails identically with this branch's changes stashed — unrelated to #1675, flagged below) |
| 11 | Regression — broad fast lane (directories: `test/cli`, `test/core`) | `dart test -j 2 <dir>` | PASS | cli `+276`, core `+687`, all green |
| 12 | Format gate | `dart format .` then `dart format --output=none --set-exit-if-changed .` | PASS | 2944 files, 0 changed after the initial pass formatted the new test file |

## Review-fix follow-up (review of 16682a3)

The review of this PR's head raised one 🟡 finding
(`build_command.dart:891-895` — the ownership classifier's segment test
matched anywhere in the path although its doc comment claimed "under the
output dir") and one 🔵 no-change-requested note (`route_plugin.dart:262-265`
— `int.parse` on a malformed URL id; the throwing parse is the pinned #336
contract). Only the 🟡 finding produced code changes. Every check below is
from an ACTUAL run in this session, on the review-fix commit.

## Checks (review-fix follow-up)

| # | Check | Command | Result | Evidence |
|---|-------|---------|--------|----------|
| 13 | Analyzer, touched files | `dart analyze lib/src/commands/build_command.dart test/commands/build_command_generated_path_attribution_test.dart` | PASS | `No issues found!` |
| 14 | RED — anchor mutant (segment test deliberately left un-anchored, the pre-fix `/<segment>/` match) | `dart test test/commands/build_command_generated_path_attribution_test.dart` | FAIL × 2 — the RIGHT failures | `owned-segment names outside the output dir stay hand-authored` and `an explicit output dir re-anchors the segment check` failed (the un-anchored classifier attributes `test/data/…` / `lib/data/…` / `lib/src/datax/…` to the generator); the trade-off pin passed as designed — it holds under both heuristics, so it pins semantics rather than the heuristic |
| 15 | GREEN — new pins (default/fast lane: the file is untagged, so a bare `dart test` selects it) | same command, anchor restored | PASS | `00:00 +5: All tests passed!` |
| 16 | GREEN — slow classifier suite (incl. the real `dart analyze lib` inside `verifyAnalyzeOrFail`) | `dart test --preset=all test/commands/build_command_unit_test.dart` | PASS | `+55: All tests passed!`; the spawned analyze run reported `Analyzing lib... No issues found!` |
| 17 | GREEN — regression bug-1675 driver | `dart test --preset=regression test/fixes/bug_1675_make_crud_vpc_route_compile_test.dart` | PASS | `+5: All tests passed!` (A4/A5/U3 attribution pins unchanged and still green under the anchored classifier) |
| 18 | Format gate | `dart format --output=none --set-exit-if-changed lib test` | PASS | `2737 files (0 changed)` |

## Pre-existing failures flagged (NOT caused by this fix)

- `test/regression/issue_294_entity_without_id_test.dart` — "Gap 1" test
  fails on the PRISTINE merge-base HEAD (a9329746) identically: verified by
  stashing this branch's changes and re-running. Unrelated to #1675.
- Environment limitation, not a test failure: a full `-j` default fast-lane
  sweep in this sandbox repeatedly exhausted disk via unbounded
  `/tmp/dart_test.kernel.*` caches (an 8.5GB single cache observed) and the
  Flutter-tagged self-hosting suites cannot load without a Flutter SDK.
  Every suite covering the touched surfaces ran to completion green
  (checks 4–11). No new failures from this fix were observed anywhere.

## Mutation coverage rationale

The compile gate's red proof (check 3) doubles as the mutation check for
A1/U1: reverting the one-line generator change (the exact mutant
`invalidate` → `markStale`) is KILLED by the extended gate at
`data_product_repository.dart:48`. The route plumbing mutant (dropping the
`idFieldType` passthrough) is killed by U2/A3's two-sided pin
(`isNot(contains("id: state.pathParameters['id']!"))` AND
`contains("int.parse(state.pathParameters['id']!)")`) — the pre-fix run
evidence (check 2) shows both sides firing. The attribution mutants
(classifier missing a segment / over-attributing) are killed by the
three-way G3 group (all-generator single remedy, mixed-case group
membership, six-segment + backslash probe). The review-fix anchor mutant
(dropping the output-dir prefix from the segment test) is killed by check
14's two failing pins — and only by those two, which is the point: the
trade-off pin is heuristic-independent by construction.
