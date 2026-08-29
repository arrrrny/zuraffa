# TDD Verification — 033 @Route Decorator for Auto-Generated Navigation Configuration

**Spec**: `specs/033-route-decorator-nav/spec.md`
**Verified**: 2026-08-29, branch `033-route-decorator-nav`

## Summary

All 4 success criteria are PROVED by mechanical tests (red evidence in
`tdd/red/01-all-behaviors.md`, cycles in `tdd/cycle-log.md`):

| SC | Claim | Proof | Verdict |
|----|-------|-------|---------|
| SC-001 | A single `@Route` on a View defines the complete route — no manual config | `route_build_stage_test.dart::writes router file with route, name, view class and import` (A1): one annotation → complete `zfa_router.g.dart` with route, derived name, view class, correct package import. Multi-View single-file + idempotency covered by sibling tests. | **PROVED** |
| SC-002 | `zfa build` route compilation < 2s for ≤100 Views | `route_perf_test.dart::100 annotated Views compile into one config in under 2 seconds` (A2): wall-clock assertion over a 100-View temp project; observed ~0.4s. | **PROVED** |
| SC-003 | All misconfigs caught at build time with clear, actionable errors | `route_validator_test.dart` (13 tests, A3) — one per FR-006 category (duplicate path naming BOTH classes, duplicate name, missing parent naming parent+child, parent-not-shell, non-View target with file:line, unsupported param type naming the allowed set, dangling redirect target, go_router missing with install hint) + `route_build_stage_test.dart::validation fails the stage` (no file written) + subprocess test asserting `zfa build --dda-routes-only` exits 1 and prints the error. | **PROVED** |
| SC-004 | Generated RouteParams are compile-time safe (typed, not stringly-typed) | `route_build_stage_test.dart::typed path param / typed query params / mixed params` (A4): `final int id` with `int.parse(state.pathParameters['id']!)`, typed query fields with absence-safe defaults; unsupported types are build errors (validator test). | **PROVED** |

## FR coverage

| FR | Status | Behavior / test |
|----|--------|-----------------|
| FR-001 @Route annotation (path, deepLinkAware, isShell, parent, middleware, redirect) | DONE | `route_annotation.dart` extended (`isShell`, `parent`, `pathParameters`); scanner literal tests U1–U7; both `@Route`/`@ZfaRoute` spellings (U12) |
| FR-002 zfa build scans + compiles single config file | DONE | `RouteBuildStage` wired into `zfa build` (runs first); subprocess wiring tests U34–U36; empty-project skip/stale-regenerate edge cases U21–U23 |
| FR-003 path params to controller | DONE | `RouteParams` classes with typed path params passed to the View at construction (U17, U19); controller receives them through the View per v6 convention (plan §decisions 8) |
| FR-004 query params to controller | DONE | typed query fields with safe defaults (U18, U19) |
| FR-005 redirect rules | DONE | `@ZfaRoute.redirect` / `@Route.redirect` constructor form (U13), legacy `redirectFrom`/`redirectTo` form, router-level redirect callback |
| FR-006 build-time errors (5 categories) | DONE | `RouteValidator` — 8 codes; all categories tested (U25–U33) |
| FR-007 nested routes via parent | DONE | `isShell` + `parent` by name (U14) or path (U15); children nest under shell with absolute paths; shell View renders around children |
| FR-008 guards invoked before activation | DONE | async guard redirect block with `canActivate`/`onRejected` (U16) |

## User story acceptance scenarios

- **US1** (P1): scenarios 1–4 — A1 + idempotency + multi-route tests. DONE.
- **US2** (P1): typed path + query extraction, mixed params — U17–U19. DONE.
- **US3** (P2): redirect rules incl. constructor form — U13. DONE.
- **US4** (P2): shell nesting with shell View rendering around child — U14/U15. DONE.
- **US5** (P2): guard intercept before activation — U16. DONE.
- **US6** (P3): deep-link marker for `deepLinkAware` routes (marker emission;
  platform manifest files remain owned by the imperative deep-link plugin —
  documented Out of scope). DONE (marker scope).
- **US7** (P3): typed `RouteParams` (`final int id`) — U17. DONE.

## Edge cases (spec)

- Duplicate paths → error naming both classes — U25. DONE.
- Missing parent → error naming parent + child — U27. DONE.
- Non-View class annotation → error with class + location — U29. DONE.
- No annotations → no failure; stale file → valid empty config — U21/U22. DONE.
- Unsupported param type → error naming type + allowed set — U30. DONE.
- Redirect target undefined → error — U31. DONE.

## Suite state

- `dart analyze` root package (lib/ + test/): **0 errors** (112 infos/warnings,
  all pre-existing).
- `dart test` full fast tier (directory-chunked to fit the sandbox disk):
  **2576 passed, 0 failed**, including the 45 new spec-033 tests
  (test/dda/: 80 total, 35 pre-existing goldens still green).
- Pre-existing, unrelated failures: NONE in the fast tier.
  - `dart analyze` reports 23 errors in `examples/mcp_demo/` and
    `zikzak_session/` sub-packages — verified identical on unmodified
    master (git stash check); these sub-packages need their own generation
    run before their tests apply.
  - `test/benchmark`, `test/integration`, `test/property` are tagged `slow`
    and excluded from the default run by `dart_test.yaml`.
- The first full-suite attempt in this environment failed with
  `No space left on device` while compiling the combined test kernel
  (~8 GB in the shared sandbox `/tmp`) — an environment constraint, not a
  code failure; re-running directory-by-directory resolved it and is how
  the 2576-pass figure was obtained.

## Deviations from the spec text (documented in plan.md)

1. Guards are constructed directly (`AuthGuard()`), not DI-resolved —
   matches the existing golden shapes; guards may pull DI inside
   `canActivate` (plan §decisions 7).
2. "Empty config" = regenerate-stale-file-as-empty; a project that never
   used `@Route` gets no file (avoids breaking pure-Dart projects with a
   Flutter-importing file) (plan §decisions 1).
3. Deep links emit marker comments; platform manifest emission stays with
   the imperative deep-link routes plugin (Non-goals).
