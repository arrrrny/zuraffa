# TDD Cycle Log: 1198-template-self-hosting

## RED (reproduction) — 2026-09-06

The bug is a coverage/correctness-debt bug: the referee did not exist. RED
evidence gathered on the fix branch BEFORE the loop was built:

1. **Absence proof (repo evidence, master @ caf52b66):**
   - `test/plugins/{mock,di,route}/` carried NO `*_compile_test.dart` and no
     template-level loop suite; the trust-tier suites that existed
     (spec-1003 view/controller/presenter/usecase/service/repository/
     datasource/state) were scattered, not driven by a shared fixture
     entity, and none covered the full structural+compile+behavioral bar
     per template.
   - `grep -rln "byte-stable|determinism receipt|diff guard" test/ lib/` →
     no diff guard anywhere; no determinism receipt schema existed.
   - No downstream-compile gate: the only Flutter-package compile fixture
     (flutter_cluster_fixture, spec 1003) covered view+controller+presenter
     only — no route template, no shared fixture entity, no go_router/graph.
   - No publish gate: release.yml built binaries with no template loop in
     front of it; ci.yaml had no template-referee job.

2. **Loop-catchable debt reproduced while building the loop (real failures
   on master templates):**
   - `dart test test/templates/self_hosting --exclude-tags flutter`
     (first full RED run): 11 failures. Diagnosis:
     - **route template (REAL template defect, GREEN-fixed in
       lib/src/plugins/route/builders/route_builder.dart):** the
       downstream-compile gate failed with
       `error • The named parameter 'productRepository' is required, but
       there's no corresponding argument • product_routes.dart` — the route
       template never satisfied the generated view's required repository
       arg. Root cause: `_resolveDependencyInfo` always returned
       `_DependencyInfo.empty()` (viewParam == ''), making the
       `viewParam.isNotEmpty` emission branch DEAD; had it ever fired, it
       would have emitted `getIt<...>()` — and get_it 9 (resolved version)
       REMOVED the global `getIt`, so the dead branch also hid a latent
       broken-symbol defect. Previously only catchable at app level (the
       exact #1116-class debt this bug targets).
     - fixture-setup mismatches (test-side, corrected during the loop):
       get_it async `reset()` timing; mixin-member obligations of
       `with Loggable, FailureHandler` interfaces; `ProductFields`
       descriptor surface (mirror of zorphy output) required by generated
       presenters; package-name embedding in the generated route-table test
       (an input — the guard now pins identical inputs).
   - Master templates otherwise held the bar: after the referee existed,
     all nine templates pass structural + compile + behavioral + diff guard
     — the debt was the missing referee, plus the one live route-template
     defect above.

## GREEN — 2026-09-06

- Route template fix (lib change):
  `_buildViewBuilderExpr` now emits
  `GetIt.instance<ProductRepository>()` when the view on disk accepts the
  `productRepository` param (or when no view file exists yet — historical
  entity-view contract), guarded by `!config.isCustomUseCase &&
  !config.generateDi`; `_generateEntityRoutes` imports the repository
  interface when the arg is emitted. Custom-usecase views keep the
  zero-arg contract (route_builder_test `generates standalone custom
  route` stays green).
- 45/45 template self-hosting tests pass (44 pure-Dart + 1 flutter-lane
  downstream gate). See verification.md for the full battery.
