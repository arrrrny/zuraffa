# Implementation Plan: @Route Decorator for Auto-Generated Navigation Configuration

**Branch**: `033-route-decorator-nav` | **Date**: 2026-08-29 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/033-route-decorator-nav/spec.md`

## Summary

This feature completes v6 Track 6.1 (issue #187): a `@Route` class annotation on
View classes that `zfa build` compiles into a single auto-generated GoRouter
configuration file (`lib/src/routing/zfa_router.g.dart`), with typed
path/query parameter extraction, redirect rules, nested shell routes, and
middleware guards — all validated at build time.

The repo already carries a dormant DDA (Decorator-Driven Architecture)
foundation from Track 1.3: `lib/src/dda/` has the `ASTScanner`
(analyzer-based annotation scan), `ZorphyDecoratorPlugin` SPI +
`ZorphyPluginRegistry`, `DecoratorDispatcher`, a `BuildPipeline` orchestrator,
and a **pre-written route slice** (`ZfaRoute` annotation, `RouteDDAPlugin`,
`RouteGenerator` → `zfa_router.g.dart`, 17 golden tests in
`test/dda/route_golden_test.dart`). That slice is library-only: no CLI command
invokes it, the scanner hands annotation arguments to plugins as **raw source
strings** (`'/products'` arrives *with quotes*, `true` arrives as the *String*
`'true'`), there is **no build-time validation** (duplicates, missing parents,
non-View classes, unsupported param types, dangling redirect targets are all
accepted silently), the shell-route grouping never renders the shell's own
View, and an annotation-free project skips generation entirely instead of
producing a valid empty config.

This plan closes those gaps and wires the route stage into `zfa build`,
turning the dormant pipeline into the spec's contract: annotate → build →
generated navigation config, with every misconfiguration caught before any
code is written.

## Technical Context

**Language/Version**: Dart 3.11+ (repo `sdk: ^3.11.0`); toolchain used for
this work: Dart 3.13.2 (stable) on linux_x64. Pure Dart — no Flutter imports
under `lib/` (repo hard rule, regression test
`test/regression/issue_512_pure_dart_flutter_import_guard_test.dart`). The
*generated* `zfa_router.g.dart` targets Flutter apps (it imports
`package:go_router/go_router.dart` + `package:flutter/material.dart`), but the
generator itself stays pure Dart.

**Primary Dependencies**: `analyzer` 14.1.0 (already pinned; the scanner's
syntactic fast path uses `parseString` from
`package:analyzer/dart/analysis/utilities.dart`), `code_builder`,
`dart_style`, `path`, `yaml` — all existing. Zero new packages.

**Existing subsystems (relevant)**:

- `lib/src/dda/compiler/ast_scanner.dart` — `ASTScanner.scan()` resolves every
  file under `<root>/lib` through `AnalysisContextCollection` and visits class
 /method metadata via `_DecoratorVisitor`. `_parseAnnotation` stores named
  args via `arg.argumentExpression.toSource()` → everything is a raw source
  string. `Annotation.constructorName` (the `redirect` in
  `@Route.redirect(...)`) is not captured today.
- `lib/src/dda/models/decorator_ast.dart` — `DecoratorAST.get<T>()` throws
  `DecoratorParseError` on type mismatch, which is why real scanner output
  (`deepLinkAware: true` → String `'true'`) breaks
  `RouteDDAPlugin.onApply`'s `decorator.get<bool>('deepLinkAware')`.
- `lib/src/dda/plugins/route/route_annotation.dart` — `ZfaRoute` const
  annotation (`path`, `name`, `deepLinkAware`, `parentPath`,
  `redirectFrom`/`redirectTo`, `queryParameters`, `middleware`), the
  `ZfaRoute.redirect(from:, to:)` named constructor, deprecated
  `typedef Route = ZfaRoute`, plus pure-Dart `ZuraffaRouteState`,
  `ZuraffaRouteGuard`, `RouteParams` runtime types.
- `lib/src/dda/plugins/route/route_plugin.dart` — `RouteDDAPlugin`
  (`targetDecorators: ['Route']`) collects routes into `RouteGenerator`.
  Matches the *typof* spelling only (`@Route(...)`), not `@ZfaRoute(...)`.
- `lib/src/dda/plugins/route/route_generator.dart` — `addRoute`/`addRedirect`
  → `generate()` emits `createZfaRouter()` + per-route
  `<View>RouteParams extends RouteParams` classes (typed fields,
  `fromGoRouterState` factory), `ShellRoute` grouping by `parentPath`
  (builder renders only `child`, not the shell View), guard `redirect:`
  callbacks via `ZuraffaRouteGuard`, root-level redirect rules. Path params
  are hard-typed `String`; query params take declared types.
- `lib/src/dda/compiler/build_pipeline.dart` — 6-stage orchestrator; stage
  5.5 writes `zfa_router.g.dart` **iff** `RouteDDAPlugin.hasRoutes` and looks
  the plugin up in the *global* `ZorphyPluginRegistry`, which nothing
  populates in production (`PluginDiscovery._loadPackagePlugins` throws
  "not yet implemented"). `BuildPipeline` is not invoked from any CLI command.
- `lib/src/commands/build_command.dart` — `zfa build`: optional `--clean` →
  `BuildYamlGuard` pre-flight → `dart run build_runner build` (subprocess) →
  post-build safety nets (`verifyOutputsOrFail`, `verifyDeclaredPartsOrFail`,
  `verifyAnalyzeOrFail`). No DDA stage.

**Spec-reading decisions (ambiguities resolved)**:

1. **"Empty config" edge case** — when `zfa build` finds no `@Route`
   annotations the pipeline MUST NOT fail. Resolution (dual behavior,
   mirroring how spec 037 resolved its path ambiguity): if a previous
   `zfa_router.g.dart` exists it is regenerated as a valid *empty* config
   (routes removed → file shrinks; no stale routes survive); if none exists
   nothing is written (a project that never used `@Route` must not suddenly
   grow a Flutter-importing file that breaks `dart analyze` in pure-Dart
   packages).
2. **`isShell` vs `parentPath`** — spec FR-001 names `isShell` + `parent`;
   the existing annotation has `parentPath`. Both are supported: `isShell:
   true` marks a route as a shell whose View renders *around* its children
   (`ShellRoute(builder: (c, s, child) => DashboardShellView(child: child))`),
   and `parent` accepts either a route *name* or a route *path*
   (`parentPath` remains the path-only legacy spelling). A `parent` that
   references a non-shell route is a build-time error (FR-006).
3. **Non-View annotation target** — FR-006 lists "annotations on non-View
   classes" as build-time errors. Strictness rule: class-declared annotations
   on classes whose name does not end in `View`/`Shell`/`Page`/`Screen` →
   error; annotations on methods/fields → error. The error carries the file
   location and the offending class name.
4. **`@Route` vs `@ZfaRoute` spelling** — the plugin accepts both decorator
   names (`Route` via the typedef, `ZfaRoute` canonical). The scanner
   captures `constructorName`, so `@Route.redirect(from:, to:)` /
   `@ZfaRoute.redirect(...)` are recognized as redirect rules; the legacy
   `redirectFrom:`/`redirectTo:` named args keep working.
5. **go_router dependency precondition** — routes found in a project whose
   pubspec lacks `go_router` fail the build with an actionable error
   (install `go_router`) instead of emitting a file that fails
   `dart analyze` downstream. The empty/stale-regeneration path never emits
   Flutter imports.
6. **Path param types** — SC-004's typed `RouteParams`: `:id` params are
   `String` by default and can be declared `int`/`double`/`bool` via the new
   `pathParameters: {'id': 'int'}` annotation argument (same shape as the
   existing `queryParameters`). Anything outside
   `{String, int, double, bool}` is a build-time error (FR-006 "unsupported
   parameter types").
7. **Guard resolution** — spec Assumptions mention guards "resolved via the
   DI container at runtime". The generated code instantiates guards
   directly (`AuthGuard()`) — the shape the existing goldens assert and the
   dormant generator emits. Guards stay plain constructors; DI resolution
   is deferred (guards themselves may pull dependencies from DI inside
   `canActivate`). Documented as a deliberate v1 deviation.
8. **Controller param plumbing (FR-003/FR-004)** — "made available to the
   controller at initialization time" follows the v6 convention discovered
   in the codebase: route params reach the controller through the View.
   The generated builder constructs `<View>RouteParams.fromGoRouterState`
   and passes it to the View; the View's state hands typed fields to its
   Controller at initialization. No separate controller-injection channel
   is invented.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

The Zuraffa constitution (`.specify/memory/constitution.md`) is still in
template form; the default gates apply, matching prior specs (036, 037):

1. **Library-First**: All new logic lives in libraries under
   `lib/src/dda/plugins/route/` (validator, stage) exported through
   `lib/zuraffa.dart`; `lib/src/commands/build_command.dart` is a thin wrapper
   that calls the stage.
2. **CLI Interface**: `zfa build` gains the DDA route stage (no new
   subcommand; `--no-dda-routes` opts out, `--dda-routes-only` runs only the
   route scan). Errors fail the command with exit code 1 and actionable
   messages.
3. **Test-First (NON-NEGOTIABLE)**: Every behavior in `tdd/test-list.md` has
   a failing test BEFORE its implementation. Red evidence recorded under
   `tdd/red/` and cited in `tdd/verification.md`.
4. **Integration Testing**: pipeline-level tests run the real
   `RouteBuildStage` against temp projects on disk (annotate → stage →
   assert file contents), not just the generator unit APIs.
5. **Simplicity**: Zero new dependencies; the fast scan path reuses
   `parseString` from the pinned analyzer. No reflection.

All gates pass at design time.

## Project Structure

### Documentation (this feature)

```text
specs/033-route-decorator-nav/
├── spec.md              (input — already exists)
├── plan.md              (this file)
├── tasks.md             (MVP-first task list)
└── tdd/
    ├── test-list.md     (behaviors + tests + implementations)
    ├── cycle-log.md     (baseline + per-cycle red/green evidence)
    ├── red/             (red evidence per behavior)
    └── verification.md  (green state + SC mapping)
```

### Source code

```text
lib/src/dda/
├── models/decorator_ast.dart        (EXTENDED — constructorName field so
│                                     @Route.redirect is distinguishable)
├── compiler/ast_scanner.dart        (EXTENDED — literal parsing: String /
│                                     bool / int / double / null → typed
│                                     values, list/map args → raw source
│                                     strings for downstream parsing;
│                                     constructorName captured;
│                                     syntactic-only fast path via
│                                     parseString for annotation scans)
├── compiler/build_pipeline.dart     (EXTENDED — builtin DDA plugin
│                                     registration (fresh instances per run),
│                                     route stage shared with RouteBuildStage,
│                                     validation errors fail the pipeline)
└── plugins/route/
    ├── route_annotation.dart        (EXTENDED — isShell, parent,
    │                                 pathParameters params)
    ├── route_validator.dart         (NEW — FR-006 build-time validation:
    │                                 duplicate paths/names, missing parents,
    │                                 parent-not-shell, non-View targets,
    │                                 unsupported param types, dangling
    │                                 redirect targets, go_router missing)
    ├── route_generator.dart         (EXTENDED — isShell shells render the
    │                                 shell View around children; parent by
    │                                 name-or-path; typed path params;
    │                                 generateEmpty() valid empty config;
    │                                 validation hook before emit)
    └── route_build_stage.dart       (NEW — the zfa build entry: fresh
                                      registry + scan + dispatch + validate +
                                      write/regenerate-empty/skip)

lib/src/commands/build_command.dart  (EXTENDED — runs RouteBuildStage before
                                      build_runner; --no-dda-routes /
                                      --dda-routes-only flags; DDA errors
                                      fail the build)
lib/zuraffa.dart                     (EXTENDED — export route_validator.dart,
                                      route_build_stage.dart)
```

### Test fixtures

```text
test/fixtures/route_dda/            (NEW — temp-project builders live in the
                                      test files; no committed JSON needed —
                                      fixtures are .dart sources written into
                                      temp dirs by the tests themselves)
```

## Goals & Strategy

### Primary goal

`@Route(path: '/products/:id')` on a View + `zfa build` → a single
`lib/src/routing/zfa_router.g.dart` containing the GoRouter config, typed
`RouteParams` classes, redirects, nested shells, and guards — with every
misconfiguration (duplicate path, missing parent, non-View target,
unsupported param type, dangling redirect target, missing go_router)
reported as a build-time error that fails `zfa build`, and an
annotation-free project producing a valid (possibly empty) config without
failure.

### Non-goals

- Runtime navigation behavior (GoRouter semantics are the target package's).
- Deep-link platform file generation (`apple-app-site-association` /
  `assetlinks.json`) — the existing deep-link *routes* plugin
  (`lib/src/plugins/route/builders/deep_link_routes_builder.dart`) owns
  platform manifests; the DDA path documents `deepLinkAware` routes in the
  generated file (comment marker), as today.
- Merging DDA routes with the imperative `getAllRoutes()` aggregator from the
  CLI route plugin (separate system; both can coexist — the app chooses
  which router to mount).
- Auth/Cache/Retry/TrackEvent DDA generators (their dormant state is
  unchanged; only the shared stage/registry plumbing they sit on is fixed).

### Strategy

1. **Scanner slice (P0 — unblocks everything)**: typed literal parsing +
   constructorName + fast syntactic path. This is the foundation the e2e
   story depends on (scanner output currently cannot feed `RouteDDAPlugin`
   at all).
2. **MVP slice (P1 — US1/US2/US7)**: `RouteBuildStage` wired into
   `zfa build`, `@Route`-only scan, `zfa_router.g.dart` emission, typed
   path+query params. Satisfies SC-001 (single annotation, zero manual
   config) and SC-004 (compile-time-safe RouteParams).
3. **Validation slice (P1 — FR-006)**: `RouteValidator` + stage failure
   semantics. Satisfies SC-003.
4. **P2 slice — redirects (US3) + nested shells (US4) + guards (US5)**:
   already-generated shapes from the dormant code, now exercised through the
   real scanner/stage e2e (incl. `.redirect` constructor form).
5. **P3 slice — deep-link markers (US6) + performance (SC-002)**: 100-View
   temp project completes the stage in <2s (wall-clock asserted).

### Architecture

```
zfa build
   │
   ├─ (unless --no-dda-routes)  RouteBuildStage.run(projectRoot)
   │      1. fresh RouteDDAPlugin → isolated ZorphyPluginRegistry snapshot
   │      2. ASTScanner(projectRoot/lib, resolve: false).scan()   ← fast
   │      3. filter results to @Route/@ZfaRoute (+ constructorName)
   │      4. dispatch → RouteDDAPlugin.onApply collects routes/redirects
   │         (literal args now typed: bool true, String '/products', …)
   │      5. RouteValidator.validate(collected) → List<RouteError>
   │            duplicate paths/names · missing parents · parent-not-shell
   │            non-View target · unsupported param type · dangling redirect
   │            target · go_router missing from pubspec
   │      6. errors? → print each with file:line, fail build (exit 1)
   │      7. routes? → write lib/src/routing/zfa_router.g.dart
   │         no routes + stale file? → write valid empty config
   │         no routes + no file?  → skip (log)
   │      8. BuildResult{success, generatedFiles, errors}
   │
   ├─ build_yaml guard → dart run build_runner build (existing)
   └─ post-build verify nets (existing)
```

`BuildPipeline` (the library orchestrator) gets the same stage-5.5 through
`RouteBuildStage` so both entry points converge on one implementation; its
plugin discovery now registers the builtin DDA plugins (fresh per run) so
library consumers no longer depend on manual `ZorphyPluginRegistry.register`
calls.

### Risks

- **Scanner regression** — the literal-parsing change touches
  `_parseAnnotation`, which every DDA plugin consumes. Mitigation: existing
  cache-DDA tests (regex over raw strings) keep passing because list/map
  args still arrive as raw source strings; only scalar literals become typed.
- **Global registry pollution** — `ZorphyPluginRegistry` is process-global;
  tests and repeated builds must see fresh plugin instances (routes would
  otherwise accumulate across runs and break idempotency). Mitigation: the
  stage snapshots + restores the registry and always uses its own plugin
  instance.
- **Perf budget** — the resolved-unit path needs an
  `AnalysisContextCollection` and full resolution per file; 100 Views could
  blow the 2s budget. Mitigation: the stage scans syntactically
  (`parseString`), which needs no analysis context; the golden path is
  asserted with a wall-clock test.
- **Idempotency** — repeated `zfa build` must produce byte-identical output
  (US1 scenario 3). Mitigation: deterministic emission (sorted imports,
  stable ordering by scan order + name) and an explicit idempotency test
  (two stage runs → identical bytes).

## Changes

### Phase 1: Scanner foundations

`DecoratorAST.constructorName`; typed literal parsing in `_parseAnnotation`;
`ASTScanner(resolve: false)` fast path; scanner unit tests over in-memory
sources (parseString path) and on-disk temp projects.

### Phase 2: Route stage MVP (P1)

`RouteBuildStage`; annotation extensions (`isShell`, `parent`,
`pathParameters`); typed path params in `RouteGenerator`; `zfa build` wiring
with `--no-dda-routes` / `--dda-routes-only`; e2e stage tests.

### Phase 3: Validation (P1, FR-006 / SC-003)

`RouteValidator` + stage failure semantics + per-category tests.

### Phase 4: P2/P3 completeness

`.redirect` constructor e2e; shell rendering (`isShell` + `parent` by name);
guards e2e; deep-link markers; empty/stale regeneration rule; idempotency;
100-View performance test (SC-002).

### Phase 5: Export & Verify

Barrel exports, `dart analyze`, full `dart test`, red/green bookkeeping in
`tdd/verification.md`.

## Sketch

### DecoratorAST (literal values)

```dart
class DecoratorAST {
  final String name;                 // 'Route' | 'ZfaRoute'
  final String? constructorName;     // 'redirect' for @Route.redirect(...)
  // namedArgs values after the scanner fix:
  //   '/products'  → String  (quotes stripped)
  //   true/false   → bool
  //   42 / 3.14    → int / double
  //   null         → null
  //   [A, B]       → List<String> of raw sources (['A', 'B'])
  //   {'q': 'String'} → raw source string "{'q': 'String'}" (parsed by the
  //                     owning plugin — keeps map arg handling unchanged)
}
```

### RouteValidator

```dart
class RouteValidationError {
  final RouteValidationErrorCode code; // duplicatePath, duplicateName,
                                       // missingParent, parentNotShell,
                                       // nonViewTarget, unsupportedParamType,
                                       // danglingRedirectTarget,
                                       // goRouterMissing
  final String message;                // actionable, names the classes/paths
  final String? filePath; final int? line;
}

class RouteValidator {
  /// [entries] — what the scan collected; [pubspecDeps] — target project's
  /// dependency names (for the go_router precondition).
  List<RouteValidationError> validate({
    required List<RouteEntry> entries,
    required List<String> redirectRules,
    required Set<String> pubspecDeps,
  });
}
```

### RouteBuildStage

```dart
class RouteBuildStage {
  RouteBuildStage({required this.projectRoot, this.dryRun = false,
                   this.verbose = false, this.fileSystem});
  Future<BuildResult> run();
  // 1..8 as in the architecture diagram; exit path mirrors
  //    BuildCommand's failure convention (throws StateError with the
  //    formatted error list; command prints + exit(1)).
}
```

### Generated file (shapes asserted by tests)

```dart
// GENERATED — zfa DDA pipeline — Track 6.1. DO NOT EDIT.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:myapp/views/product_detail_view.dart';

class ProductDetailViewRouteParams extends RouteParams {
  final int id;                       // typed via pathParameters: {'id': 'int'}
  factory ProductDetailViewRouteParams.fromGoRouterState(GoRouterState state)
      => ProductDetailViewRouteParams._(id: int.parse(state.pathParameters['id']!),
           pathParameters: state.pathParameters,
           queryParameters: state.uriQueryParameters);
  // ...
}

GoRouter createZfaRouter() => GoRouter(
      routes: [
        ShellRoute(                     // isShell: true + children via parent
          builder: (context, state, child) =>
              DashboardShellView(child: child),
          routes: [GoRoute(path: '/dashboard/analytics', ...)],
        ),
      ],
      redirect: (context, state) {      // @Route.redirect rules
        if (state.matchedLocation == '/old') return '/new';
        return null;
      },
      initialLocation: '/',
    );
```

## Deferred / Future Work

- Platform deep-link manifest emission for `deepLinkAware` routes (owns to
  the existing deep-link routes plugin; tracked separately).
- Merging annotated routes into the imperative `getAllRoutes()` aggregator
  (app_shell) behind one router entry point.
- Activating the dormant Auth/Cache/Retry/TrackEvent DDA generators through
  the same stage (their validation + stage semantics are separate specs).
- Route-level `@Route.query` narrowing against mission vocabulary (v6 agent
  track).
