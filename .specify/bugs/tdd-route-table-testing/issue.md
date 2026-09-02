# Bug Issue: [TDD-120] Route-table testing: generated routes must be proven by generated tests (go_router)

- **Slug**: tdd-route-table-testing
- **Fetched**: 2026-09-02
- **Issue**: 842
- **URL**: https://github.com/arrrrny/zuraffa/issues/842
- **State**: open
- **Severity**: high
- **Author**: arrrrny (Ahmet TOK)
- **Labels**: bug

## Body

Context: Specs 003 (27 route files), 057/058 (deep links) rely on zfa route generation. No TDD surface asserts the route table today.

Required (system fix):
1. `zfa make --route` (or `zfa route`) emits, alongside routes, a route-table test: every declared route resolves to a builder, unknown paths hit the 404 handler, deep-link patterns parse into typed params.
2. Deep-link behaviors (057/058) generate tests using go_router's routeInformationProvider with URI fixtures (barcode path, URL-encoded query) asserting destination + params — deterministic, no platform channel needed.
3. Platform-divergence assertion (003 US3): layout-target matrix (macOS sidebar vs mobile bottom nav) asserted via the adaptive layout manifest as data, plus widget-level presence checks from #830.

## Comments

None.
