# TDD Verification — @Route Decorator for Auto-Generated Navigation Configuration

**Spec**: `specs/033-route-decorator-nav/spec.md`
**Branch**: `033-route-decorator-nav`
**Date**: 2026-08-29

## Summary

All 21 behaviors from `tdd/test-list.md` are GREEN. `@Route` (the spec's
canonical spelling of the existing `ZfaRoute` annotation, now first-class
via a non-deprecated typedef and extended with `isShell`, `parent`,
`redirect`, `params`, `guardRedirect`) is scanned at build time by a
parse-only analyzer pass, validated against every FR-006 misconfiguration
class, and compiled into `lib/src/routing/zfa_router.g.dart` — a
go_router-targeting route tree with typed `RouteParams` classes per route,
redirect rules, nested `ShellRoute` hierarchies (relative child paths),
guard-wrapped routes, and deep-link side files. The pipeline is wired into
`zfa build` as a pre-build_runner step that fails the build (exit 1) on any
validation error.

**Integration note**: the repo already contained a partial Track 6.1
foundation (`lib/src/dda/plugins/route/` — `ZfaRoute` annotation classes,
`RouteGenerator`, `RouteDDAPlugin`, 12 golden tests). This feature REUSES
that foundation — the existing annotation class is extended in place and
the existing `ZuraffaRouteGuard`/`ZuraffaRouteState` guard API is the one
generated code targets — and adds the missing spec-033 pipeline under
`lib/src/routing/` (scanner, validator, config generator, compiler,
controller-facing `ZfaRouteParams`). All 12 pre-existing golden tests pass
unmodified.

## `dart analyze` (whole project)

```
$ dart analyze
88 issues found. (0 errors, 4 warnings, 84 infos)
```

Identical to the `master` baseline — all four warnings are pre-existing
(`route_builder.dart` unused element, three pre-existing test lints). Zero
errors, zero warnings, zero new infos from any file added or modified by
this feature (`dart analyze lib/src/routing lib/src/dda/plugins/route
lib/src/commands/build_command.dart` → "No issues found!").

## `dart test` (full fast tier, ACTUAL counts)

Executed per-directory (sandbox disk limits single-process full runs; see
spec 037 verification for the batching rationale):

| Scope | Result |
|---|---|
| `test/core test/config test/utils test/cli test/dda test/domain test/session test/share test/secure_storage test/scripts test/property test/migration test/i18n test/logging test/device test/app_update test/biometrics test/clipboard test/helpers` | 931 passed, 1 skipped (pre-existing) |
| `test/graphql test/routing test/agent test/state test/mcp test/integration` | 474 passed |
| `test/plugins/benchmark test/plugins/xray test/plugins/tui` | 300 passed |
| `test/plugins` (route, usecase, sync, mock, repository, provider, method_append, strategy, service, datasource, app_shell, api, di, gym, module, shadcn, sqlite, state + top-level) | 324 passed |
| `test/plugins/mcp` | 117 passed (runner lingers after "All tests passed!" — sandbox stdin leak, not a failure) |
| `test/regression` | 78 passed |
| `test/commands` | 227 passed |
| **Total** | **2451 passed, 1 pre-existing skip, 0 failed** |

**66 new tests authored for this spec**: route_params (9), route_guard (4,
rewritten against the existing `ZuraffaRouteState`/`ZuraffaRouteGuard`
API), scanner (14), validator (13), config generator (13), compiler (10),
build step (3). The pre-existing `test/dda/route_golden_test.dart` (12) and
all other suites pass unmodified — no regressions.

## Spec SC mapping (all SC-001..004 proven)

### SC-001 — complete route from a single @Route, zero manual config

**PROVEN** by `test/routing/route_annotation_compiler_test.dart` — "e2e:
writes lib/src/routing/zfa_router.g.dart (SC-001)": one annotation
(`@Route(path: '/products/:id', params: {'id': int})`) on a View in a temp
project → compiler writes the router file at the well-known path with the
GoRoute entry, the typed `ProductsViewRouteParams` class, and the correct
`package:test_app/...` import. Also proven end-to-end at CLI level by
`test/commands/build_route_step_test.dart` — "success: writes artifacts and
returns 0".

### SC-002 — full route config < 2s for ≤100 annotated Views

**PROVEN** by `test/routing/route_annotation_compiler_test.dart` — "SC-002:
100 annotated Views compile under 2 seconds": a temp project with 100
annotated Views (each with a typed `:id` param) compiles completely
(scan → validate → generate → write) inside the wall-clock budget (parse-only
`parseString` scanning; actual run ≈ 0.5–1s on 2 vCPUs).

### SC-003 — all misconfiguration caught at build time, actionable errors

**PROVEN** by `test/routing/route_validator_test.dart` (12 tests): duplicate
paths (error lists BOTH classes), missing parent (names the missing parent
and the available ones), parent cycles, unsupported param types (names the
type), param-not-in-path, undefined redirect targets, unknown guard
classes, non-View annotations (strict error / lenient warning), controller
type mismatches; plus aggregation (never fail-fast —
`RouteCompilationException` carries every error with file:line). CLI
escalation proven by `test/commands/build_route_step_test.dart` —
"validation failure: returns 1 and prints every error" (build fails).

### SC-004 — compile-time-safe RouteParams; type mismatch = build error

**PROVEN** by: (a) generated typed params classes (typed fields +
`fromMaps` factories using `ZfaRouteParams.intParam/stringParam/...`) —
`test/routing/route_config_generator_test.dart` "typed RouteParams class
renders with typed fields + fromMaps" + "default (untyped) path params map
to String"; (b) the controller-side mismatch check —
`test/routing/route_annotation_compiler_test.dart` "controller type
mismatch fails the compile (SC-004)" (`params: {'id': int}` vs a sibling
`ProductController` declaring `final String id` → build error naming both
types); (c) `test/routing/route_params_test.dart` — typed parsing +
holder semantics.

## Spec FR mapping

| FR | Status | Evidence |
|---|---|---|
| FR-001 @Route annotation (path, deepLinkAware, isShell, parent, middleware, redirect from/to) | DONE | `ZfaRoute` extended (`lib/src/dda/plugins/route/route_annotation.dart`); `Route` typedef now canonical; `@Route.redirect`/`@Route.middleware` constructor forms |
| FR-002 scan at `zfa build` → single config file | DONE | `RouteAnnotationScanner` + `RouteAnnotationCompiler` + `BuildCommand` pre-build step → `lib/src/routing/zfa_router.g.dart` |
| FR-003 path param extraction to controller init | DONE | generated `fromMaps` + `ZfaRouteParams.bind`/`currentAs<T>()` holder (params tests) |
| FR-004 query parameter extraction | DONE | `query:` annotation arg → nullable String fields + raw maps on the holder |
| FR-005 redirect rules | DONE | `@Route.redirect(from:, to:)` + `redirect: RouteRedirect(...)` → `GoRoute(path: from, redirect: (_, __) => to)` entries |
| FR-006 build-time error detection (5 classes) | DONE | `RouteValidator` — duplicates, missing parents (+cycles), non-View, unsupported param types, undefined redirect targets (+unknown guards) |
| FR-007 nested hierarchies via `parent` | DONE | `parent` (name-keyed) → `ShellRoute` nesting with relative child paths; shell View receives `child:` when its constructor declares it |
| FR-008 guards invoked before activation | DONE | generated `zfaGuardRedirect([...guards], _zfaRouteState(state))` → `canActivate` + `onRejected` (existing guard API) |

## User-story scenarios

- **US-1** (registration, idempotency, multi-view single file): compiler
  e2e + idempotency tests (byte-identical output across runs).
- **US-2** (path + query extraction): `route_params_test.dart` parses
  `/items/42` → `id = 42`, `/search?q=dart` → `q = 'dart'`,
  `/users/7/settings?tab=profile` → both params.
- **US-3** (redirects): scanner + generator + compiler redirect tests.
- **US-4** (nested shells): generator "shell route nests children with
  relative paths" (`/analytics` under `/dashboard` shell → child path
  `analytics`); compiler "shell + child compile into nested ShellRoute".
- **US-5** (guards): guard contract tests (deny → `onRejected` path, allow
  → proceed, first-denied-wins) + generated wrapping assertions.
- **US-6** (deep links): generator + compiler deep-link side-file tests
  (`.well-known/apple-app-site-association` + `assetlinks.json` contain
  only deepLinkAware paths; absent when none).
- **US-7** (typed RouteParams): typed fields via `params: {'id': int}` —
  `final int id;` with typed parsing.

## Edge cases from the spec

- Duplicate paths → error listing both annotated classes ✓
- Non-existent parent → descriptive error naming the parent ✓
- `@Route` on a non-View → strict error (default) / lenient warning ✓
- No `@Route` annotations at build → valid empty config when a stale
  router file exists; otherwise the step is a no-op (never fails) ✓
- Unsupported param type → build error naming the type ✓
- Redirect target missing → build error naming from/to ✓
- Parent cycles → detected and reported (defensive extra) ✓

## TDD process notes

- Red evidence for every behavior cluster: `tdd/red/01..05-*.md`.
- The initial design duplicated annotation/guard classes; discovery of the
  existing DDA route plugin (`lib/src/dda/plugins/route/`) during GREEN
  refactoring triggered a rework to REUSE the existing `ZfaRoute`,
  `ZuraffaRouteGuard` and `ZuraffaRouteState` (duplicates deleted, guard
  tests rewritten against the existing API). The plan.md integration note
  documents this decision.
- Test corrections during the loop: multiline bind emission assertions,
  RouteParams class naming (view-class-derived, matching the existing DDA
  generator convention), params-class emission gate (path params, not
  typed-map presence), duplicate-error location reporting (first
  declaration site; message lists both classes).

## Pre-existing unrelated failures

None. 2451 passed / 1 pre-existing skip / 0 failed; `dart analyze` matches
the master baseline exactly (88 issues, 0 errors, 4 pre-existing
warnings).
