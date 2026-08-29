# Tasks: @Route Decorator for Auto-Generated Navigation Configuration

**Input**: Design documents from `specs/033-route-decorator-nav/`

**Prerequisites**: plan.md (required), spec.md (required for user stories).

**Tests**: Tasks marked with `[T]` are behavior-driving test tasks written FIRST
(TDD red), then made green by their pairing implementation task.

**Organization**: grouped by user story; each story is an MVP increment.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: US1=Registration (P1), US2=Params (P1), US3=Redirects (P2),
  US4=Nested (P2), US5=Guards (P2), US6=Deep links (P3), US7=Typed params (P3)

## Phase 1: Runtime support classes (shared infrastructure)

- [x] T01 [T] US2 RED: `test/routing/route_params_test.dart` —
      `ZfaRouteParams.stringParam/intParam/doubleParam/boolParam` parse
      values with correct types + fallbacks; `bind`/`currentAs<T>` holder
      stores and retrieves the current params instance.
- [x] T02 US2 GREEN: Implement `lib/src/routing/route_params.dart`.
- [x] T03 [T] US5 RED: `test/routing/route_guard_test.dart` —
      `ZuraffaRouteGuard.canActivate` contract, default `redirectPath`
      `/login`, `ZfaRouteNavigationContext` fields (path, pathParameters,
      queryParameters).
- [x] T04 US5 GREEN: Implement `lib/src/routing/route_guard.dart`.

## Phase 2: Scanner (US1)

- [x] T05 [T] US1 RED: `test/routing/route_annotation_scanner_test.dart` —
      scans `@Route(path:)` on View classes (name ends `View` or extends a
      `*View` class); decodes `path`, `deepLinkAware`, `isShell`, `parent`,
      `name`, `middleware: [A, B]`, `params: {'id': int}`, `query: ['q']`,
      `redirect: RouteRedirect(from:, to:)`, `guardRedirect`;
      `@Route.redirect(from:, to:)` standalone form;
      `@Route.middleware([G])` standalone form merged with `@Route(...)`;
      non-View classes flagged (error in strict mode, warning in lenient);
      `.g.dart` files skipped; View constructor `child` param detection for
      shells.
- [x] T06 US1 GREEN: Implement
      `lib/src/routing/route_annotation_scanner.dart` +
      `route_annotation.dart` (const annotation classes) +
      `route_model.dart`.

## Phase 3: Validator (FR-006 / SC-003)

- [x] T07 [T] US1 RED: `test/routing/route_validator_test.dart` —
      duplicate paths (error lists BOTH classes); missing parent (error
      names the missing parent); parent cycles (error); unsupported param
      type `Foo` (error names the type); redirect target undefined (error);
      param key not present in path (error); controller type mismatch
      (SC-004: annotated `params: {'id': int}` vs sibling
      `ProductController` field `String id` → error naming both types);
      valid configuration passes clean.
- [x] T08 US1 GREEN: Implement `lib/src/routing/route_validator.dart`.

## Phase 4: Config generation (US1/US2/US3/US4/US5/US6/US7)

- [x] T09 [T] US1 RED: `test/routing/route_config_generator_test.dart` —
      flat routes render `GoRoute(path:, name:, builder:)` binding
      `XRouteParams.fromMaps(...)` via `ZfaRouteParams.bind` and returning
      the View; nested shells render `ShellRoute` with children and
      relative child paths (`/analytics` under `/dashboard` → child path
      `analytics`); shell View receives `child:` only when its constructor
      declares it; redirects render `GoRoute(path: from, redirect: (_, __) => to)`;
      guards render `redirect: (_, state) => zfaGuardRedirect([...])` with
      guard classes instantiated; typed RouteParams classes render with
      typed fields + `fromMaps` factories using the typed parse helpers;
      imports emitted as `package:<pkg>/...` from pubspec name; generated
      file parses back with zero syntax errors; deep-link files
      (`apple-app-site-association`, `assetlinks.json`) contain
      deepLinkAware paths; no deepLinkAware → no side files.
- [x] T10 US1 GREEN: Implement
      `lib/src/routing/route_config_generator.dart`.

## Phase 5: Compiler orchestration + `zfa build` wiring (US1/SC-001/SC-002)

- [x] T11 [T] US1 RED: `test/routing/route_annotation_compiler_test.dart` —
      e2e over a temp project: writes `lib/src/routing/zfa_router.g.dart`;
      idempotent (two runs → byte-identical output); 100 annotated Views
      compile < 2s (SC-002); zero annotations + stale router file →
      valid empty config; zero annotations + no router file → no file
      written; validation errors → `RouteCompilationException` carrying
      ALL errors with file:line locations.
- [x] T12 US1 GREEN: Implement
      `lib/src/routing/route_annotation_compiler.dart`.
- [x] T13 [T] US1 RED: `test/commands/build_route_step_test.dart` —
      `BuildCommand.compileRouteAnnotations(projectRoot)` (extracted,
      in-process testable): success path returns 0 and writes artifacts;
      validation failure returns 1 (build must fail) and prints every
      error; zero-annotation project returns 0 without writing.
- [x] T14 US1 GREEN: Wire the step into `BuildCommand.run()` before
      `_runBuild()`; exports in `lib/zuraffa.dart`.

## Phase 6: Export, Analyze, Verify

- [x] T15 [P?] Export routing libraries from `lib/zuraffa.dart`.
- [x] T16 `dart analyze` — zero errors, zero new warnings (pre-existing
      baseline untouched).
- [x] T17 Full `dart test` — ACTUAL pass/fail counts; pre-existing
      failures flagged.
- [x] T18 Red evidence for every behavior under `tdd/red/`; author
      `tdd/verification.md` mapping SC-001..004 to tests.
