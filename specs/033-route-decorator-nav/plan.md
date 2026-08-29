# Implementation Plan: @Route Decorator for Auto-Generated Navigation Configuration

**Branch**: `033-route-decorator-nav` | **Date**: 2026-08-29 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/033-route-decorator-nav/spec.md`

## Summary

Adds an `@Route` class annotation that produces an auto-generated navigation
configuration when `zfa build` runs. Annotating a View with
`@Route(path: '/products/:id')` (plus optional `deepLinkAware`, `isShell`,
`parent`, `middleware`, `redirect`, `name`, `params`, `query`,
`guardRedirect`) is all a developer needs — the build compiles every
annotation into a single `lib/src/routing/zfa_router.g.dart` file targeting
`package:go_router`, with typed `RouteParams` classes per route, redirect
rules, nested shell hierarchies, guard wrapping, and platform deep-link
side files.

The repo already provides the pieces this feature builds on: the DDA
foundation (`lib/src/dda/` — Track 1.3 annotation scanning patterns), the
analyzer's parse-only `parseString` API used across
`lib/src/core/ast/file_parser.dart`, the go_router-emitting RouteBuilder
family (`lib/src/plugins/route/builders/`) for the v5 entity-route flow,
AND a partial Track 6.1 foundation in `lib/src/dda/plugins/route/`
(`ZfaRoute` annotation + `RouteGenerator` + `RouteDDAPlugin` + 12 golden
tests). **Integration decision (refined during implementation):** the
existing `ZfaRoute` annotation class is EXTENDED in place with the spec
033 parameters (`isShell`, `parent`, `redirect`, `params`, `guardRedirect`)
and its `Route` typedef becomes the canonical non-deprecated spelling; the
existing `ZuraffaRouteGuard`/`ZuraffaRouteState` guard API is the one
generated code targets. The new `lib/src/routing/` module provides the
missing pipeline: parse-only scanner, FR-006 validator, deterministic
config generator, compiler orchestration, deep-link side files, and the
`zfa build` pre-step. The v5 entity RouteBuilder and the existing DDA
`RouteGenerator`/golden tests are untouched.

## Technical Context

**Language/Version**: Dart 3.11+ (repo `sdk: ^3.11.0`); toolchain Dart
3.13.2. Pure Dart under `lib/` (no Flutter imports — the generated router
file targets the user's Flutter project, where go_router is available; the
zuraffa package itself never imports Flutter or go_router).

**Primary Dependencies**: `analyzer` (parse-only `parseString` — no
`AnalysisContextCollection`, keeping the 100-View scan well under the
SC-002 2-second budget), `code_builder` + `dart_style` for emitting
formatted, parse-guaranteed Dart, `path`, `yaml` (target `pubspec.yaml`
package name for import URIs). Zero new packages.

**Scanning approach**: syntactic, parse-only. `@Route(...)` annotations,
class names, superclass names and constructor parameters are all visible in
the unresolved AST — resolution is unnecessary for annotation args, which
the scanner reads as source strings (`'/products/:id'`, `true`,
`[AuthGuard]`, `RouteRedirect(from: '/old', to: '/new')`) and decodes with
small deterministic parsers (quote stripping, list splitting, key/value
regex extraction).

**Annotation forms supported** (both spec spellings):
- `@Route(path: ..., deepLinkAware: ..., isShell: ..., parent: ...,
  middleware: [...], redirect: RouteRedirect(from: ..., to: ...), name: ...,
  params: {'id': int}, query: ['q'], guardRedirect: '/login')`
- `@Route.redirect(from: '/old', to: '/new')` — standalone redirect rule
  (named-constructor annotation; the analyzer exposes `name: Route`,
  `constructorName: redirect`).
- `@Route.middleware([AuthGuard])` — standalone guard list, mergeable with
  `@Route(...)` on the same class.

**View/controller conventions** (spec Assumptions):
- A View class's name ends with `View`, or it extends a class whose name
  ends with `View`. Anything else annotated with `@Route` is a build error
  (strict mode, default) or a warning (lenient mode).
- Route name defaults to the View class name minus the `View` suffix with
  a lowercase first letter (`DashboardView` → `dashboard`); `parent`
  references these names. An explicit `name:` argument wins.
- Each View conventionally pairs with a Controller
  (`ProductView` ↔ `ProductController`). SC-004's type-mismatch check
  compares an annotated `params` type against a same-named
  constructor/field declaration on the sibling Controller class when one
  can be located in the same directory; mismatches are build errors.

**Generated artifacts** (into the target project):
- `lib/src/routing/zfa_router.g.dart` — `zfaRoutes` (GoRoute/ShellRoute
  tree), `zfaRouteRedirects`, per-route `<Name>RouteParams` classes, guard
  helper. Imports views/guards via `package:<pkg>/...` URIs derived from
  the target `pubspec.yaml` name and the scanned file locations.
- `.well-known/apple-app-site-association` and `.well-known/assetlinks.json`
  — only when `deepLinkAware: true` routes exist (side-effect files per
  spec Assumptions; content includes the route paths).

**Runtime support in zuraffa lib** (pure Dart, unit-testable in this repo):
- `ZfaRouteParams` base class + typed parse helpers (`intParam`,
  `doubleParam`, `boolParam`, `stringParam`) + a current-params holder
  (`ZfaRouteParams.bind` / `currentAs<T>()`) that makes parameters
  available to controllers at initialization (FR-003/FR-004).
- `ZuraffaRouteGuard` interface (`canActivate(ZfaRouteNavigationContext)`,
  `redirectPath` defaulting to `/login`) + `ZfaRouteNavigationContext`
  value object (FR-008).

**`zfa build` integration**: `BuildCommand.run()` gains a pre-build step
(`RouteAnnotationCompiler.compileForBuild(projectRoot)`) executed before
build_runner: scans `lib/` for `@Route`; if any annotation exists (or a
stale generated router file is present), compiles + writes the artifacts;
validation failures print every error and fail the build with exit 1.
Projects without any `@Route` annotations and without a stale router file
are left untouched (no repo pollution — important because the zuraffa repo
itself runs `zfa build` paths in its own test suite). The compiler is a
standalone library so tests drive it directly without spawning
build_runner.

**Idempotency**: deterministic output ordering (routes sorted by full
path, then name; stable param maps) makes repeated runs byte-identical.

**Performance**: SC-002 — parse-only scanning ≈ a few ms per file; 100
Views compile in well under 2s (asserted with a wall-clock budget in the
test suite against a generated 100-View temp project).

**Testing**: `package:test`, fast tier. Temp-project fixtures written by
the tests (like `test/plugins/route/route_generator_test.dart` does for
the v5 RouteBuilder). Generated Dart is validated syntactically by parsing
it with `parseString` and asserting zero syntax errors.

## Constitution Check

1. **Library-First**: scanning/model/validation/generation are libraries
   under `lib/src/routing/`, exported via `lib/zuraffa.dart`; the build
   command step is a thin orchestrator.
2. **CLI Interface**: `zfa build` compiles routes pre-build_runner; no new
   user-facing command needed (spec names `zfa build` as the trigger).
3. **Test-First (NON-NEGOTIABLE)**: every behavior in `tdd/test-list.md`
   has a failing test first; red evidence under `tdd/red/`.
4. **Integration Testing**: end-to-end tests write annotated temp
   projects → compile → assert generated file contents + deep-link files +
   exit semantics.
5. **Simplicity**: no new dependencies; parse-only analyzer usage; the
   generated file is plain text emitted through `code_builder`-free
   hand-rolled emitter for exact idempotent output. (Decision: emit the
   router file with a deterministic hand-rolled emitter rather than
   `code_builder` — code_builder's ordering/dedup behavior adds noise to
   byte-identical output requirements; the file is syntax-checked by
   parsing it back.)

## Project Structure

```text
lib/src/routing/
├── route_annotation.dart         (NEW — @Route const class + RouteRedirect +
│                                   RouteParamSpec value types)
├── route_guard.dart              (NEW — ZuraffaRouteGuard, ZfaRouteNavigationContext)
├── route_params.dart             (NEW — ZfaRouteParams base, typed parse
│                                   helpers, bind/currentAs holder)
├── route_model.dart              (NEW — RouteDeclaration, RouteRedirectRule,
│                                   RouteCompilationError, RouteCompilationResult)
├── route_annotation_scanner.dart (NEW — parse-only @Route scanner)
├── route_validator.dart          (NEW — FR-006 validation engine)
├── route_config_generator.dart   (NEW — zfa_router.g.dart + deep-link emitter)
└── route_annotation_compiler.dart(NEW — scan→validate→generate orchestration)

lib/src/commands/build_command.dart (EXTENDED — pre-build route compile step)
lib/zuraffa.dart                   (EXTENDED — routing exports)
```

```text
test/routing/
├── route_annotation_scanner_test.dart  (NEW)
├── route_validator_test.dart           (NEW)
├── route_config_generator_test.dart    (NEW)
├── route_annotation_compiler_test.dart (NEW — e2e incl. idempotency + <2s/100 views)
├── route_params_test.dart              (NEW — FR-003/FR-004 extraction)
└── route_guard_test.dart               (NEW — FR-008 guard semantics)

test/commands/
└── build_route_step_test.dart          (NEW — zfa build pre-step wiring)
```

## Goals & Strategy

### Primary goal

One `@Route` annotation on a View ⇒ a complete, valid route configuration
at `lib/src/routing/zfa_router.g.dart` (SC-001), with path/query parameter
extraction to controllers, redirects, nested shells, guards, deep links,
typed RouteParams, and build-time validation of every misconfiguration
class in FR-006 — no silent runtime failures (SC-003), compile-time safe
params (SC-004).

### Non-goals

- Replacing the v5 entity RouteBuilder (separate pipeline, untouched).
- Actual Flutter navigation runtime behavior (go_router executes the
  generated config inside the target Flutter project; this repo validates
  generated source + pure-Dart support classes).
- DI-based guard resolution plumbing beyond the documented
  constructor-instantiation convention (guards are instantiated directly
  in generated code; a future DI pass can swap the factory).

### Strategy (MVP-first)

1. **P1 core**: annotation classes + scanner + basic validation (non-View
   strictness, duplicates) + config generation for flat routes + RouteParams
   (SC-001, US-1).
2. **P1 params**: typed parse helpers + ZfaRouteParams holder + fromMaps
   emission (US-2, US-7, SC-004).
3. **P2**: redirects (US-3), nested shells (US-4), guards (US-5).
4. **P3**: deep-link side files (US-6), `zfa build` wiring, idempotency +
   performance (SC-002), empty-config edge case.

## Risks

- **Annotation arg parsing from source strings** — mitigated by strict,
  unit-tested decoders (quotes, lists, maps, RouteRedirect(...)) with
  actionable errors for malformed values.
- **`zfa build` integration touching the zuraffa repo itself during its
   own tests** — mitigated by the only-compile-when-annotations-exist
   guard documented above.
- **Generated-code validity without go_router in this package** —
   mitigated by parse-back syntax validation of the emitted file in tests.

## Deferred / Future Work

- DI-container guard resolution (generated factory hook).
- Deep-link config templating per-platform flavor (team prefix, app IDs).
- Route-level transition/builder customization options.
