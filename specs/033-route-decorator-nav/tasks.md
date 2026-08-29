# Tasks: @Route Decorator for Auto-Generated Navigation Configuration

**Input**: Design documents from `specs/033-route-decorator-nav/`

**Prerequisites**: plan.md (required), spec.md (required for user stories).

**Tests**: Tasks marked with `[T]` are behavior-driving test tasks written FIRST
(TDD red), then made green by their pairing implementation task. Tests are
MANDATORY per the spec's SC-001..004.

**Organization**: Tasks are grouped by user story from `spec.md`. Each user
story can be implemented + tested independently and shipped as an MVP increment.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: US1=Route Registration (P1), US2=URL Parameters (P1),
  US3=Redirects (P2), US4=Nested Routes (P2), US5=Guards (P2),
  US6=Deep Links (P3), US7=Typed Params (P3), EC=Edge Cases
- Exact file paths are in descriptions

## Phase 1: Scanner Foundations (shared infrastructure)

- [x] T01 [P?] US1 RED: Write `test/dda/ast_scanner_literal_test.dart`:
  - string literal arg `path: '/products'` scans to typed `String`
    `'/products'` (no quotes) via `DecoratorAST.get<String>`;
  - bool literal `deepLinkAware: true` scans to typed `bool` `true`;
  - int/double literals scan to `int`/`double`;
  - `null` literal scans to null;
  - list literal `middleware: [AuthGuard]` scans to `List<String>`
    `['AuthGuard']` (raw sources, brackets stripped);
  - map literal `queryParameters: {'q': 'String'}` scans to a raw source
    string the plugin can parse;
  - `@Route.redirect(from: '/old', to: '/new')` reports
    `decoratorName == 'Route'` AND `constructorName == 'redirect'`;
  - `@ZfaRoute(...)` reports `name == 'ZfaRoute'`;
  - positional arg `@Route('/products')` scans to positionalArgs
    `['/products']`.
- [x] T02 US1 GREEN: Extend `lib/src/dda/models/decorator_ast.dart`
      (`constructorName` field) and `lib/src/dda/compiler/ast_scanner.dart`
      (typed literal parsing + constructorName capture). Passes T01.
- [x] T03 [T] US1 RED: Write `test/dda/ast_scanner_fast_path_test.dart`:
  - `ASTScanner(projectRoot: <tmp>, resolve: false).scan()` parses an
    on-disk temp project WITHOUT a pubspec.yaml (syntactic path needs no
    analysis context) and still yields class annotations with typed args;
  - the resolved path (default) still scans the same temp project once a
    minimal pubspec exists (no regression);
  - `.g.dart` / `.freezed.dart` files remain excluded on both paths.
- [x] T04 US1 GREEN: Add the `resolve: false` fast path to `ASTScanner`
      (parseString). Passes T03.

## Phase 2: User Story 1 — Route Registration via Annotation (P1, MVP)

- [x] T05 [T] US1 RED: Write `test/dda/route_build_stage_test.dart` (stage
  e2e, temp project: pubspec with `go_router`, one View file with
  `@ZfaRoute(path: '/products')`):
  - `RouteBuildStage(tmpRoot).run()` succeeds and writes
    `lib/src/routing/zfa_router.g.dart`;
  - file contains `createZfaRouter`, `GoRouter`, `path: '/products'`,
    `name: 'products'`, `ProductsView`, the view import
    `package:tmp_app/...`, and the DO-NOT-EDIT header;
  - second run over unchanged sources produces byte-identical output
    (idempotency — US1 scenario 3);
  - two annotated Views (US1 scenario 4) → both routes in ONE file.
- [x] T06 US1 GREEN: Implement
      `lib/src/dda/plugins/route/route_build_stage.dart` (fresh-registry
      snapshot/restore, scan → filter Route/ZfaRoute → dispatch → write);
      wire `zfa build` (`lib/src/commands/build_command.dart`) to run the
      stage before build_runner with `--no-dda-routes` /
      `--dda-routes-only` flags. Passes T05.
- [x] T07 [T] US1 RED: Extend `test/dda/route_build_stage_test.dart`:
  - `@Route(path: '/home')` (typof spelling) and `@ZfaRoute(...)` both
    produce routes (spelling acceptance);
  - method-level `@Route` and class names not ending in
    View/Shell/Page/Screen are rejected (see Phase 3 for error shape);
  - `zfa build` integration: `BuildCommand` with `--dda-routes-only` on the
    temp project produces the same file as the direct stage run.
- [x] T08 US1 GREEN: RouteDDAPlugin accepts both decorator names
      (`targetDecorators: ['Route', 'ZfaRoute']`), rejects non-class /
      non-View targets with actionable errors; BuildCommand flags. Passes
      T07.

## Phase 3: Build-Time Validation (FR-006 / SC-003 — P1)

- [x] T09 [T] US1 RED: Write `test/dda/route_validator_test.dart` — one
  test per error category:
  - duplicate paths → error naming BOTH annotated classes + the path;
  - duplicate route names → error;
  - `parent` referencing an unknown route name/path → "parent route not
    found" naming the parent and the child class;
  - `parent` referencing a non-shell route → error;
  - `@Route` on a non-View class → error naming the class + location;
  - unsupported param type (`pathParameters: {'id': 'Duration'}`) → error
    naming the type and the allowed set;
  - redirect `to` target not among route paths → "undefined redirect
    target" error;
  - routes present but `go_router` absent from pubspec deps → actionable
    install error;
  - clean project → zero errors.
- [x] T10 US1 GREEN: Implement
      `lib/src/dda/plugins/route/route_validator.dart`; stage runs it and
      fails (formatted errors, no file written) when non-empty. Passes T09.
- [x] T11 [T] US1 RED: Extend `test/dda/route_build_stage_test.dart`:
  - duplicate-path temp project → stage fails, lists both classes,
    writes NO router file (validate-before-write);
  - `zfa build` surfaces DDA errors and exits non-zero (command-level
    integration via `BuildCommand` helper).

## Phase 4: P2 Stories — Redirects, Nested Shells, Guards

- [x] T12 [T] US3 RED: Extend `test/dda/route_build_stage_test.dart`:
  - `@ZfaRoute.redirect(from: '/legacy', to: '/home')` on a class →
    redirect rule in generated file (redirect callback matching
    `matchedLocation == '/legacy'` → `'/home'`);
  - legacy `redirectFrom:`/`redirectTo:` named-args form still works;
  - redirect-only annotation contributes no GoRoute;
  - redirect to unknown target → build error (ties Phase 3).
- [x] T13 US3 GREEN: RouteDDAPlugin handles `constructorName == 'redirect'`
      + `from`/`to` args + legacy form; generator emits redirect callback.
      Passes T12.
- [x] T14 [T] US4 RED: Extend `test/dda/route_build_stage_test.dart`:
  - shell View `@ZfaRoute(path: '/dashboard', isShell: true)` + child
    `@ZfaRoute(path: '/dashboard/analytics', parent: 'dashboard')` →
    `ShellRoute` nesting the child GoRoute with
    `builder: (context, state, child) => DashboardShellView(child: child)`;
  - `parent: '/dashboard'` (path form) nests identically;
  - missing parent → build error (Phase 3 wiring).
- [x] T15 US4 GREEN: `isShell` + `parent` (name-or-path) in annotation,
      plugin, generator (shell builder renders the shell View; children
      grouped under the shell). Passes T14.
- [x] T16 [T] US5 RED: Extend `test/dda/route_build_stage_test.dart`:
  - `middleware: [AuthGuard]` → generated route has an async `redirect:`
    guard block invoking `AuthGuard().canActivate(...)` and honoring
    `onRejected(...)` before route activation;
  - middleware list arg round-trips through the scanner (typed list from
    T01/T02).
- [x] T17 US5 GREEN: guard generation through the real scanner path
      (existing generator shape, now e2e). Passes T16.

## Phase 5: P3 Stories — Typed Params, Deep Links, Edge Cases, Perf

- [x] T18 [T] US2/US7 RED: Extend `test/dda/route_build_stage_test.dart`:
  - `path: '/items/:id'` + `pathParameters: {'id': 'int'}` →
    `ItemsViewRouteParams` with `final int id` and
    `int.parse(state.pathParameters['id']!)` in the factory (typed path
    param);
  - `path: '/search'` + `queryParameters: {'q': 'String', 'page': 'int'}`
    → typed query fields with defaults for missing values;
  - mixed route `/users/:userId/settings` + `queryParameters: {'tab':
    'String'}` + `pathParameters: {'userId': 'int'}` → both typed fields
    in ONE params class;
  - unsupported `pathParameters` type → build error (Phase 3 wiring);
  - default (undeclared) path params remain `String` (SC-004 backward
    compatibility with existing goldens).
- [x] T19 US2/US7 GREEN: `pathParameters` annotation arg + typed path
      params in generator. Passes T18.
- [x] T20 [T] US6 RED: Extend `test/dda/route_build_stage_test.dart`:
  - `deepLinkAware: true` route carries the deep-link marker comment in
    the generated file; plain routes carry none.
- [x] T21 US6 GREEN: marker emission (existing shape, now e2e-asserted).
      Passes T20.
- [x] T22 [T] EC RED: Extend `test/dda/route_build_stage_test.dart`:
  - no annotations + no previous file → stage succeeds, writes nothing;
  - no annotations + stale `zfa_router.g.dart` → regenerated as a valid
    EMPTY config (parses, no stale routes, `createZfaRouter` present);
  - routes removed between runs → regenerated file loses them (stale
    route cleanup);
  - pure-Dart project (no go_router, no annotations) → no file, success.
- [x] T23 EC GREEN: empty/stale regeneration rule in the stage. Passes
      T22.
- [x] T24 [T] US1 RED: Write `test/dda/route_perf_test.dart` (SC-002):
  temp project with 100 annotated View files + go_router pubspec →
  `RouteBuildStage.run()` completes in < 2s wall clock and the output
  contains all 100 routes.
- [x] T25 SC-002 GREEN: perf verification (fast path already in place;
  optimize only if the budget is exceeded). Passes T24.

## Phase 6: Export & Verify

- [x] T26 Export `route_validator.dart` + `route_build_stage.dart` from
      `lib/zuraffa.dart`; keep `route_golden_test.dart` green (existing
      generator API unchanged).
- [x] T27 Full verification: `dart analyze` clean, `dart test` green,
      red/green evidence consolidated in `tdd/verification.md`, tasks
      checkboxes updated.
