# Bug Issue: test: fix pre-existing failing test suites (route/cache goldens, xray_control_deck, di_container_override)

- **Slug**: issue-256-test-fix-pre-existing-failing-test-suites-route-cache-golden
- **Fetched**: 2026-08-22T19:42:20.566186+00:00
- **Issue**: 256
- **URL**: https://github.com/arrrrny/zuraffa/issues/256
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug, task, critical, test, v6

## Body

## Summary

Multiple test suites are failing on the `development` branch after the pure-Dart split (#253 / PR #254). These failures are **pre-existing** — they exist on the PR head independently of the review fixes (PR #255). They block a green `dart test` / `flutter test` run and should be fixed.

## Failing suites

### 1. `test/dda/route_golden_test.dart` — RouteParams generator emits invalid Dart (5 tests)

```
Failing tests:
  Golden: Track 6.1 — @Route DDA Plugin acceptance: multiple routes produce complete GoRouter configuration
  Golden: Track 6.1 — @Route DDA Plugin generator: multiple path params generate all fields
  Golden: Track 6.1 — @Route DDA Plugin golden: path parameter :id generates RouteParams class
  Golden: Track 6.1 — @Route DDA Plugin golden: query parameters included in RouteParams
  Golden: Track 6.1 — @Route DDA Plugin golden: route name is preserved
```

**Root cause**: the generated `RouteParams` private constructor emits `required` modifiers inside a positional optional-parameter list:

```
ProductDetailViewRouteParams._([required this.id, required this.pathParameters, ...])
```

`required` is invalid in an optional positional parameter list (`[...]`) — the formatter rejects it ("Can't have modifier 'required' here"). The generator (`lib/src/dda/plugins/route/route_generator.dart`, `_routeParamsClass`) should use named parameters (`{...}`) or drop `required`.

### 2. `zuraffa_flutter/test/presentation/xray/xray_control_deck_test.dart` — widget test layout/assertion failures (7 tests)

```
Failing tests:
  XRayControlDeck Widget Tests color mapping for XRayMockType.error
  XRayControlDeck Widget Tests color mapping for XRayMockType.unknown
  XRayControlDeck Widget Tests color mapping for XRayMockType.valid
  XRayControlDeck Widget Tests empty state shows helpful message
  ... and 3 more
```

**Symptoms**: `tap()` derives an offset outside the render tree (`Offset(-76.1, -26.0)` vs root `Size(800.0, 600.0)`); `find.text("❌")` finds 0 widgets. Likely a test-layout/viewport issue in the control deck test harness (e.g. missing `Scaffold`/sizing, or a widget that renders off-screen at the default test size).

### 3. `test/core/module/di_container_override_test.dart` — `registerSingleton replaces with override: true` (1 test)

**Symptom**: `Error while creating double` from get_it / mocktail when `di.get()` resolves the overridden singleton. Likely a mocktail/get_it interaction or a registration-order issue in `ZuraffaDIContainer.registerSingleton(override: true)`.

### 4. `test/dda/cache_golden_test.dart` — Cacheable DDA generator (6 tests)

```
Failing tests:
  Golden: Track 6.2 — @Cacheable DDA Plugin acceptance: mixed @Cacheable + @CacheInvalidate produce complete file
  Golden: Track 6.2 — @Cacheable DDA Plugin generator: direct CacheGenerator produces valid output
  Golden: Track 6.2 — @Cacheable DDA Plugin golden: @Cacheable on method collects entry
  Golden: Track 6.2 — @Cacheable DDA Plugin golden: TTL check skips expired entries
  ... and 2 more
```

Same class of generator-golden failures as #1 — likely invalid generated Dart or changed template output.

## Acceptance criteria

- [ ] `dart test test/dda/route_golden_test.dart` passes (5/5)
- [ ] `dart test test/dda/cache_golden_test.dart` passes (6/6)
- [ ] `dart test test/core/module/di_container_override_test.dart` passes (1/1)
- [ ] `cd zuraffa_flutter && flutter test test/presentation/xray/xray_control_deck_test.dart` passes (7/7)
- [ ] Full `dart test` (core) + `flutter test` (zuraffa_flutter) are green

## Notes

- These are tracked separately from PR #255 (`fix: address review comments on #254`) which fixes the API-parity/regression review comments — it does not touch these failing suites.
- The `zuraffa_flutter` control-deck failures were previously unobservable: the package could not resolve dependencies on the PR head (`mata` pubspec typo + analyzer conflict), fixed in #255.


## Comments

**coderabbitai** (2026-08-04T20:21:22Z):

<!-- This is an auto-generated issue plan by CodeRabbit -->
<details>
<summary>🔗 Related PRs</summary>

arrrrny/zuraffa#196 - feat(state): Tracks 2.3 + 2.4 — Cache Sync + ControlledWidget Templates [merged]
arrrrny/zuraffa#207 - feat(xray): Track 4.1 — XRayScope & XRayNode deterministic widget ID infrastructure (`#182`) [merged]
arrrrny/zuraffa#208 - feat: X-Ray visual overlay with bounding boxes [merged]
arrrrny/zuraffa#209 - [v6] Track 4.3 — X-Ray Control Deck: `@XRayMock` Decorator & Synthetic Payload Injector [merged]
arrrrny/zuraffa#217 - [v6] Track 6.1 — `@Route` Decorator for Auto-Generated Navigation Configuration [merged]
</details>

---
<details>
<summary>📝 Issue Planner</summary>

<sub>Check the box below or use the `@coderabbitai plan` command to generate an implementation plan and prompts that you can use with your favorite coding assistant.</sub>

- [ ] <!-- {"checkboxId": "8d4f2b9c-3e1a-4f7c-a9b2-d5e8f1c4a7b9"} --> Create Plan
</details>


---
<details>
<summary> 🧪 Issue enrichment is currently in open beta.</summary>


You can configure auto-planning by selecting labels in the issue_enrichment configuration.

To disable automatic issue enrichment, add the following to your `.coderabbit.yaml`:
```yaml
issue_enrichment:
  auto_enrich:
    enabled: false
```
</details>

💬 Have feedback or questions? Drop into our [discord](https://discord.gg/coderabbit)!
