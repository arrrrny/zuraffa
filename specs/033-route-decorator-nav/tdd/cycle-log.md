# Cycle Log: @Route Decorator for Auto-Generated Navigation Configuration

Append only. Newest last. Every entry's `red` block is the evidence that the test
existed and failed before the implementation.

## Baseline

- suite: `dart test test/dda/` -> 35 passed, 0 failed
- commit: `b3926c93`
- recorded: cycle 0, before any change

## Cycle 1: scanner literal parsing + constructorName (U1–U7)

- test: `test/dda/ast_scanner_literal_test.dart` + `test/dda/ast_scanner_ctor_test.dart` (new)
- red: `dart test test/dda/ast_scanner_literal_test.dart`
  -> 5 assertion failures: `Expected: <true> Actual: 'true'` (bool),
     `Expected: '/home' Actual: '/home'` (quoted string),
     `Expected: Instance of 'List' Actual: '[AuthGuard, LogGuard]'`,
     null/numeric equivalents; ctor test failed compile
     (`constructorName` undefined on DecoratorAST). Evidence:
     `tdd/red/01-all-behaviors.md`.
- green: `lib/src/dda/models/decorator_ast.dart` gained `constructorName`;
  `lib/src/dda/compiler/ast_scanner.dart` `_parseAnnotation` now converts
  literal args to typed values (String/bool/int/double/null/List), derives
  the constructor name from dotted annotation names (`@Route.redirect`).
  Also fixed while here: import URIs now use the pubspec-derived package
  name (`package:stage_app/...`, was hardcoded `zuraffa`).
- refactor: `_parseLiteral` extracted; lenient `_stringArg`/`_boolArg`
  helpers in RouteDDAPlugin tolerate legacy raw-source values.
- commit: (this branch, spec 033)

## Cycle 2: syntactic fast path (U8–U9)

- test: `test/dda/ast_scanner_fast_path_test.dart` (new)
- red: compile error `No named parameter with the name 'resolve'`.
- green: `ASTScanner(resolve: false)` parses via `parseString` (no analysis
  context, no pubspec requirement); `_dartFiles()` sorted for determinism;
  optional `contentFilter` pre-skips files that cannot contain the target
  decorators (SC-002 budget guard).
- refactor: none beyond the above.
- commit: (this branch, spec 033)

## Cycle 3: route validator (U25–U33 / A3)

- test: `test/dda/route_validator_test.dart` (new — 13 tests, one per
  FR-006 category plus boundary cases)
- red: compile errors (`RouteValidator`, `RouteEntryInfo`,
  `RouteValidationErrorCode` undefined). Evidence: `tdd/red/01-all-behaviors.md`.
- green: `lib/src/dda/plugins/route/route_validator.dart` — 8 error codes,
  actionable messages naming both offending classes/paths, parent resolution
  by name/path/slashless-path, go_router precondition.
- refactor: none.
- commit: (this branch, spec 033)

## Cycle 4: route build stage + zfa build wiring (U10–U24, U34–U36 / A1, A4)

- test: `test/dda/route_build_stage_test.dart` (new — 17 stage e2e tests +
  3 subprocess command-wiring tests)
- red: compile error `Method not found: 'RouteBuildStage'`. Evidence:
  `tdd/red/01-all-behaviors.md`.
- green: `lib/src/dda/plugins/route/route_build_stage.dart` (scan → collect
  → validate → write/regenerate-empty/delete-stale/skip);
  `lib/src/commands/build_command.dart` runs the stage first with
  `--dda-routes` / `--dda-routes-only` flags; `RouteGenerator` gained
  isShell shells rendering the shell View around children, parent by
  name-or-path with absolute child paths, typed path params, sorted imports,
  valid empty-config emission; `RouteDDAPlugin` accepts both spellings,
  rejects non-View targets with locations; `BuildPipeline` stage 5.5 now
  delegates to the stage and registers builtin DDA plugins.
- refactor: RouteBuildStage extracted so `zfa build` and `BuildPipeline`
  share one implementation.
- commit: (this branch, spec 033)

## Cycle 5: performance budget (A2 / SC-002)

- test: `test/dda/route_perf_test.dart` (new)
- red: compile error (`RouteBuildStage` undefined) — authored with cycle 4.
- green: 100 annotated Views compile in well under 2s on the syntactic path
  (observed ~0.4s stage runtime inside the test).
- refactor: none needed — budget met without further optimization.
- commit: (this branch, spec 033)

## Verification summary

- `dart analyze` (root package lib/ + test/): 0 errors.
- `dart test` (full fast tier, run directory-by-directory to keep the shared
  sandbox's test kernel within disk limits): **2576 passed, 0 failed**
  (agent 144, app_update 6, biometrics 7, cli 139, clipboard 6, commands
  235, config 10, core 572 (+1 skipped), dda 80, device 6, domain 18,
  graphql 192, i18n 11, logging 6, mcp 71, migration 20, plugins 767,
  regression 78, scripts 1, secure_storage 11, session 20, share 5,
  state 99, utils 72).
- Pre-existing, unrelated: `dart analyze` reports 23 errors in the
  `examples/mcp_demo/` and `zikzak_session/` sub-packages (missing generated
  files until their own generation runs) — verified identical on unmodified
  master via `git stash`. `test/benchmark`, `test/integration`,
  `test/property` are tagged `slow` and excluded by `dart_test.yaml`
  (no tests run by default).
