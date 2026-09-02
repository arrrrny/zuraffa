# Bug Assessment: route-table testing — generated routes must be proven by generated tests

- **Slug**: tdd-route-table-testing
- **Created**: 2026-09-02
- **Source**: https://github.com/arrrrny/zuraffa/issues/842
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

Specs 003 (27 route files), 057/058 (deep links) rely on zfa route generation. No TDD surface asserts the route table today. Generated routes are never tested — no proof that routes resolve to builders, deep links parse params, or unknown paths hit 404. https://github.com/arrrrny/zuraffa/issues/842

## Symptom

`zfa make --route` generates route files but no route-table test. No assertion that every declared route resolves to a builder, unknown paths hit 404, or deep-link patterns parse into typed params. Platform-divergence (macOS sidebar vs mobile bottom nav) is not asserted.

## Reproduction

1. Run `zfa make --route` for a routed feature
2. Route files generated — no route-table test emitted
3. Deep-link behaviors (057/058) have no test using routeInformationProvider
4. Platform-divergence (003 US3) has no layout-target matrix assertion

## Suspected Code Paths

- `zfa make --route` — emits routes but no test
- No route-table test template exists
- No deep-link test generation with routeInformationProvider
- No platform-divergence assertion infrastructure

## Root Cause Hypothesis

High confidence: the route generation pipeline was designed to emit route files only, never route-table tests. There is no test template for route verification, no deep-link test generation, and no platform-divergence assertion.

## Proposed Remediation

**Preferred**: (1) `zfa make --route` emits route-table test: every declared route resolves to builder, unknown paths hit 404, deep-link patterns parse typed params. (2) Deep-link behaviors generate tests using routeInformationProvider with URI fixtures (deterministic, no platform channel). (3) Platform-divergence assertion via adaptive layout manifest data + widget-level presence checks from #830.

**Alternatives** (optional):
- Manual route testing — doesn't scale; 27 route files in spec 003 alone.

**Files likely to change**:
- Route generation command (emit test alongside routes)
- Route-table test template
- Deep-link test generation (routeInformationProvider)
- Platform-divergence assertion (layout manifest)

**Tests to add or update**:
- Route-table test: every route resolves to builder
- Unknown path → 404 handler
- Deep-link URI fixtures → destination + params
- Platform-divergence: macOS sidebar vs mobile bottom nav

## Risks & Considerations

- routeInformationProvider tests must be deterministic (no platform channel)
- Platform-divergence assertions depend on adaptive layout manifest
- ~100 routed specs affected (indirectly)
- Depends on #830 (widget-test subject kind) for widget-level checks
- Depends on #831 (if deep-link cold-start is separate)

## Open Questions

- [NEEDS CLARIFICATION: Does `zfa make --route` already exist, or is this `zfa route`?]
- [NEEDS CLARIFICATION: What is the adaptive layout manifest format?]
