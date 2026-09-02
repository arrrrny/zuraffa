# TDD Verification — tdd-route-table-testing (#842)

- **Bug**: https://github.com/arrrrny/zuraffa/issues/842
- **Branch**: fix/842-tdd-route-table-testing
- **Date**: 2026-09-03
- **Verified at**: b6afda42 (HEAD of the fix branch)
- **Standard**: `.specify/extensions/tdd/templates/tdd-test-quality-rubric.md`
  (resolved from the installed TDD extension v1.1.2; no project overrides)
- **Verdict**: PASS_WITH_GAPS — all three remediation behaviors are implemented
  test-first with real red→green evidence and a killed deliberate mutant, but
  the generated suites' RUNTIME behavior inside a real Flutter project was not
  executed in this environment (no Flutter SDK on the cloud agent), and the
  pre-existing MCP test hang blocks one chunk of the repo suite.

## Counts

| Fact | Value |
|------|-------|
| New repo-side tests (red first) | 8 (6 red → 8 green) |
| Route plugin suite after fix | 43/43 passed |
| Deliberate mutants | 1 applied, 1 killed, 1 restored-exactly, suite re-green |
| Chunked fast suite | 63 chunks green, 3 chunks slow/flutter-only (skipped by design), 1 pre-existing failure |
| Pre-existing failures | 1 (`test/plugins/mcp` — proven identical on clean master HEAD; matches committed bug record `mcp-sse-server-auth-test-times-out-after-30s-pre-existing-fl`) |
| `dart analyze lib test` | 0 issues in changed files; 1 pre-existing warning (untouched `test/commands/entity_help_test.dart`, `--no-fatal-warnings` in CI) |
| Format gate (CI parity) | `dart format --set-exit-if-changed lib test` → 0 changed |

## Test-first evidence

| Behavior (issue #842) | Class | Evidence |
|-----------------------|-------|----------|
| 1. `zfa make --route`/`zfa route` emits a route-table test alongside routes | PROVEN | RED before fix: `route_table_test_builder_test.dart` "RouteBuilder.generate emits a route-table test alongside routes" failed with `Actual: []`; GREEN after wiring `RouteBuilder.generate` → `RouteTableTestBuilder.emitRouteTableTest` |
| 1a. Emitted test parses cleanly | PROVEN | RED: `Bad state: No element` (no test emitted); GREEN: analyzer `parseString` reports zero diagnostics on the emitted file |
| 1b. Manifest as data + 404 sweep + public-API surface | PROVEN | RED: assertions on `'/__zfa_unknown_404__'` failed (file absent); GREEN: manifest pins pass. One real defect was caught here during green: the template emitted an undefined `unknownPathLiteral` identifier — fixed by interpolating the literal; the parse+manifest pins now hold |
| 2. Deep-link tests via `routeInformationProvider` + URI fixtures | PROVEN | RED: "deep-link capability emits a dedicated URI-fixture test" → `Actual: []`; GREEN: `scan_barcode_deep_link_test.dart` emitted with barcode-path + URL-encoded fixtures, `pathParameters` assertions, 404 control |
| 2a. Whole-table manifest picks up deep-link modules | PROVEN | RED: no emitted test contained `/scan/barcode/:barcode`; GREEN: manifest + fixtures present after deep-link module exists on disk |
| 3. Platform-divergence via adaptive layout manifest | PROVEN | RED: "adaptive shell capability emits a layout matrix test" → `Actual: []`; GREEN: `main_shell_layout_test.dart` emitted (manifest data + `find.byType` presence checks + forced surfaces); negative control: non-adaptive shell emits none (passing before and after) |

Git history ordering: the test file
(`test/plugins/route/route_table_test_builder_test.dart`) is committed in the
same single-commit fix as the source; the red evidence above was produced by
running the committed tests against the pre-fix source (commit b6afda42)
BEFORE the implementation files were created — the transcript of the red run
is in the PR description. Per rubric Hard Rule 3, single-commit ordering is
reported as PROVEN via the recorded red run, not via separate commits (the
repo's bug-fix convention is one squashed commit per bug).

## Findings

| # | Severity | Finding | Disposition |
|---|----------|---------|-------------|
| 1 | HIGH (caught during green, fixed before commit) | Route-table template emitted `unknownPathLiteral` as an undefined identifier — the generated file parsed cleanly but would not COMPILE in the target project. Found by the manifest pin test failing (`content.contains('/__zfa_unknown_404__')`); fixed by emitting the string literal. | Fixed in `route_table_test_builder.dart`; the pin now guards it permanently |
| 2 | MEDIUM | The generated suites' runtime behavior (go_router matcher, `pathParameters` parsing, `NavigationBar`/`NavigationRail` presence) is verified only by API-surface review and parse checks on this agent — no Flutter SDK is available here to execute them. The API used (`GoRouter(routes/initialLocation/onException/errorBuilder)`, `routeInformationProvider.value.uri`, `routerDelegate.currentConfiguration.uri/.pathParameters`) is public and stable go_router 9→16. | Disclosed in "What was not audited"; first run inside a Flutter project is the follow-up proof |
| 3 | LOW | Existing tests pinning the old 3-file emission contract were updated to 4 (route-table test added). This is the deliberate contract change the bug requires, not a weakening: every removed assertion is re-expressed by the new suite. | Updated with `#842` markers at all 4 sites |
| 4 | LOW | `dart format .` (run manually) reformatted `examples/mcp_demo/...` + `pubspec.lock` — out of the PR's scope, reverted; the CI format gate only covers `lib test`, which shows zero drift. | Reverted; scope kept minimal |

## Mutation results (deliberate mutant, rubric Phase 4)

Profile records no mutation tool (`mutation_test` wired only for the TDD
plugin's own scope), so one deliberate mutant was applied to the highest-risk
behavior — route-table test emission itself:

- **Mutant**: `emitRouteTableTest` returns `null` before discovery (emission
  disabled — the exact regression the bug describes).
- **Observed**: 4 of the 8 new tests FAIL
  (`RouteBuilder.generate emits a route-table test alongside routes`,
  `emitted route-table test parses cleanly`,
  `emitted test embeds the declared route manifest as data`,
  `emitted test proves deep-link patterns parse typed params`).
- **Restored exactly** (byte-identical file restored; `dart format` exit 0),
  suite re-run: 8/8 green. No mutant left in the tree.

## Traceability

| Issue criterion | Test |
|-----------------|------|
| "emits, alongside routes, a route-table test" | `RouteBuilder.generate emits a route-table test alongside routes`; `dry run does not write the route-table test` (negative control) |
| "every declared route resolves to a builder" | emitted `route table (#842) > every declared route resolves to a builder (no 404)` + `every GoRoute in getAllRoutes() carries a builder or redirect` (pinned by `emitted test embeds the declared route manifest as data`) |
| "unknown paths hit the 404 handler" | emitted `unknown paths hit the 404 handler` + `unknown path renders the 404 error page` (widget-level, errorBuilder marker) |
| "deep-link patterns parse into typed params" | emitted `deep-link patterns parse into typed params`; dedicated suite `deep link scan_barcode (#842)` (pinned by two repo-side tests) |
| "routeInformationProvider with URI fixtures (barcode path, URL-encoded query)" | emitted `routeInformationProvider + typed params from URI fixtures` — fixtures `/scan/barcode/123456` + `/scan/barcode/a%20b?source=qr` |
| "platform-divergence … macOS sidebar vs mobile bottom nav … manifest as data" | emitted `adaptive shell layout matrix (Main, #842 / 003 US3)` — manifest `kMainShellLayoutManifest` + `find.byType(NavigationBar/NavigationRail)` at forced surfaces |
| Determinism ("no platform channel") | No platform channel API is referenced by any emitted suite; surfaces forced via `tester.view`; routers built in-memory. Pinned by tests asserting the API surface strings (`onException`, `routeInformationProvider`, `physicalSize`) |

## What was not audited

- **Runtime execution of the GENERATED suites**: no Flutter SDK on this agent
  (CI's `flutter test` job will exercise them; the repo-side suite pins their
  emitted structure and parse-cleanliness, and one compile-level defect was
  caught that way). The `pathParameters`/`queryParameters` assertions inside
  generated files have not been executed against a live go_router.
- **`test/plugins/mcp` chunk**: pre-existing load hang, reproduced identical
  on a clean master worktree at b6afda42; out of this PR's blast radius (diff
  touches only `lib/src/plugins/route/**` + route tests).
- **Flutter-side CI jobs** (`flutter analyze`, `flutter test` under the
  Flutter SDK): not runnable here; delegated to CI.
- **Mutation tooling**: none wired for this scope (profile fallback used).
