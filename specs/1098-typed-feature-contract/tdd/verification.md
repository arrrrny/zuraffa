# tdd/verification.md — spec 1098: Typed FeatureContract

Branch: `spec/1098-typed-feature-contract` (master @ 512a8189)
Date: 2026-09-05
Runner: Dart SDK 3.13.3 (stable), linux_x64. Suite runner: `tools/run_tests_chunked.sh`
(fast tier, chunked, kernel caches cleared between chunks).

This file records ACTUAL gate outputs. Every number below was produced by
running the command on this branch; pre-existing failures are labeled as such
and were proven pre-existing by re-running the same commands on clean master
(`git stash` → run → `git stash pop`).

## Gates

### 1. `dart analyze lib test --no-fatal-warnings` (CI dart_core form)

Result: **2 errors, both pre-existing on master; 0 attributable to this
branch.**

```
error - lib/src/domain/services/barcode_service.dart:4:8 - Target of URI
        doesn't exist: '../entities/barcode/barcode.dart'
error - lib/src/domain/services/barcode_service.dart:8:10 - The name 'Barcode'
        isn't a type
```

Pre-existing proof: `git stash` (clean master @ 512a8189) →
`dart analyze lib/src/domain/services/barcode_service.dart` → same 2 errors;
`git log --all -- lib/src/domain/entities/barcode*` is empty (the import
target never existed in git history). Out of scope for spec 1098 — not fixed
here to keep the diff scoped to one spec.

Full run: 303 issues (the rest are pre-existing infos, e.g.
`avoid_relative_lib_imports` under `test/tdd/`). Zero errors/warnings introduced
by the 26 files of this change set.

### 2. `tools/run_tests_chunked.sh` (fast suite, chunked)

Result: **79 chunks — 78 passed, 1 chunk failed (test/plugins/cache); the 2
failing tests fail identically on clean master.**

- Failing tests:
  - `test/plugins/cache/cache_adapter_receipt_test.dart` — expects receipt
    capability `'cache-adapter'`, actual `'cache adapter'`.
  - `test/plugins/cache/cache_compile_test.dart` — one "generated cache files
    pass dart analyze (exit 0)" instance fails.
- Pre-existing proof: clean master (stash) →
  `dart test test/plugins/cache/cache_compile_test.dart test/plugins/cache/cache_adapter_receipt_test.dart`
  → `+5 -2: Some tests failed` (identical). Branch → same `+5 -2`.
- New spec tests inside the run: **66/66 pass** (see coverage below).

### 3. `dart format .`

Result: **clean.** After formatting, `dart format --output=none
--set-exit-if-changed .` → `Formatted 2216 files (0 changed)`, exit 0.

### 4. `git diff --stat` (zero remaining formatting diffs)

Result: **clean.** 26 files changed, 2864 insertions(+), 11 deletions(-); a
subsequent `dart format` run produces no changes (verified above).

## TDD cycle (red → green)

Red evidence (all failed before implementation — missing API):

```
00:00 +0 -8: Some tests failed.   (8 test files failed to load against the
                                   untyped codebase)
```

Green evidence (same files after implementation):

```
00:01 +62: All tests passed!      (domain/core/engine/xray/slice/feature suites)
00:00 +4: All tests passed!      (xray deck --feature CLI suite)
```

## Success criteria — PROVED vs NOT

| Criterion | Status |
| --- | --- |
| Typed `FeatureContract` entity with Zorphy codegen (id, displayName, entities, boundary, routes, xrayLayer, argSchema) | PROVED (tests + generated `feature_contract.zorphy.dart` committed) |
| `CoreConfig.feature` / `buildContext(feature: …)` — contract (not string) reaches plugins | PROVED |
| Feature-scoped plugin loading via opt-in `FeatureScopedCapability` protocol | PROVED (unscoped default keeps all existing behavior) |
| Engine receipts gain `featureId` + per-feature grouping (`loadForFeature` / `groupByFeature`) | PROVED |
| FeaturePlugin scaffold validates `name` against known contracts (off when project declares none) | PROVED |
| Decorators: `@FeatureOwned`/`@FeatureContract` emitted (sandbox harness, xray deck) and readable back by scan | PROVED |
| `zfa slice compose <id>` resolves contract → SliceBoundary plan | PROVED |
| `zfa xray deck --feature <id>` stamps decorator + records feature in proof receipt; unknown id fails with known ids | PROVED |
| `XRayNode.featureId` (file→feature) JSON round-trip | PROVED |
| Suite 100% green | NOT PROVED — 2 pre-existing cache failures (proven identical on clean master) + 2 pre-existing `barcode_service` analyze errors on master; both out of scope |
