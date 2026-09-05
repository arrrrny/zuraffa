# TDD Verification — Dedicated test dirs for trust-tier generators (feature 1003)

**Date**: 2026-09-05
**Suite baseline**: per-directory `dart test` on the seven trust-tier scopes
(chunked runner `tools/run_tests_chunked.sh`, the disk-safe equivalent of
`dart test test/plugins/` mandated by dart_test.yaml for small agents) plus
`flutter test --tags flutter` for the Flutter-lane compile gates.
**Result**: feature scope **105 tests pass, 0 fail** across the seven trust
tiers (`cache` +8, `controller` +5, `mock` +62, `presenter` +3,
`repository` +16, `state` +7, `view` +4 — includes pre-existing tests in
those directories). Full repository fast suite: **77/77 chunks green,
failed_chunks=0** (no regressions). Flutter lane: **3/3 compile gates green**
(`view_compile`, `controller_compile`, `presenter_compile` — excluded from
the chunked run by tag, run explicitly under Flutter 3.41.0/Dart 3.11.0).

## Red → green evidence (1003 cycle)

- **Red** (structural tier, first run):
  `dart test test/plugins/{view,controller,presenter}_structural_test.dart`
  → **+10 / −2**: two signature assertions failed against real generator
  output (the formatter wraps long signatures, so single-line expected
  strings never matched — see honesty log #1).
- **Red** (compile tier): the first run of
  `state_compile` / `cache_compile` / `repository_compile` /
  `mock_compile` and all three `flutter test` compile gates failed with
  analyzer/compile errors. Every failure below was observed, then driven
  green by fixing the fixture (never the test's intent, never the
  generator's behavior):

| # | Defect caught by a red test | Resolution |
|---|---|---|
| 1 | Presenter/controller signature assertions matched a single formatted line; generated output wraps signatures across lines | Assert stable fragments (return type + method name + parameter lines) instead of whole formatted signatures |
| 2 | Fixture stub writes used `File.writeAsString` without creating parent directories (`PathNotFoundException`) | Create parents recursively before every stub write |
| 3 | Entity stub `final String id` failed `dart analyze` (`missing_default_value_for_parameter`, exit 3) | Stub entity field made nullable (`String? id`) |
| 4 | Cache plugin side-writes `cache/hive_registrar.dart` whose `part 'hive_registrar.g.dart'` does not exist until the documented `build_runner build` step (`uri_has_not_been_generated`) | Fixture emits the post-build adapter part (simulates `zfa entity create --build` output) so the full cache set can be gated without build_runner |
| 5 | Synced variant: fixture declared `SyncMetadataStore`, colliding with the real export from `package:zuraffa/zuraffa.dart` (`ambiguous_import`) | Metadata-store backing file made empty; type resolves via the zuraffa core export |
| 6 | Cached variant: fixture `ProductLocalDataSource` lacked `save`/`saveAll` the generated cache-aware bodies call (`undefined_method`) | Stub extended with the two methods |
| 7 | **Latent generator wart (documented, not changed):** `EntityUtils.extractEntityTypes('QueryParams<Product>')` flattens generics to `QueryParamsProduct`, so the mock provider emits imports for a phantom `query_params_product` entity + mock data (`uri_does_not_exist`) | Spec 1003 gates behavior, it does not change it — fixture backs the two phantom imports with stubs; flagged here as follow-up material for the mock plugin owners |
| 8 | Flutter helper: `library;` placed after imports (`The library directive must appear before all other directives`) | Directive moved to the top of the file |
| 9 | Flutter lane: `flutter pub get` in the temp project failed — Flutter SDK pins `meta 1.17.0` while zuraffa 6.1.0's exact `analyzer: 14.1.0` pin requires `meta ^1.18.3` | Fixture pubspec documents and applies the `dependency_overrides: meta: ^1.18.3` workaround (resolution-only; does not affect generated code) |
| 10 | Presenter compile gate: stub `ProductFields.id` was `String`, but `Eq(...)` expects zorphy's `Field<Product, String>` (`argument_type_not_assignable`) | Entity stub mirrors the real zorphy shape: `static const Field<Product, String> id = Field<Product, String>('id');` |

- **Green**: same scopes re-run → all green (`cache` +8, `controller` +5,
  `mock` +62, `presenter` +3, `repository` +16, `state` +7, `view` +4) and
  the three Flutter compile gates pass under `flutter test --tags flutter`.

## 1. Coverage — deliverable vs. evidence (issue #1003 exit criterion)

Every trust-tier generator now has a dedicated `test/plugins/<name>/` home
with ≥ 2 dedicated tests: a **structural** tier (file count + class name +
imports + method signatures + stub bodies, generated into a throwaway temp
dir) and a **compile** tier (generated output written to disk inside a
self-contained package, `dart pub get`/`flutter pub get` resolved, analyzer
must exit 0 and emit no ` error - ` lines).

| Generator | Dedicated test dir | Structural tests | Compile gate | Gate command |
|---|---|---|---|---|
| view | `test/plugins/view/` (new) | `view_structural_test.dart` — 4 (master-detail pair, get-only single file, generated markers + createState wiring, pure-Dart flavor skip #420) | `view_compile_test.dart` — 1 | `flutter analyze --no-fatal-warnings` on the generated cluster |
| controller | `test/plugins/controller/` (new) | `controller_structural_test.dart` — 5 (canonical path + GENERATED markers, class/imports/presenter wiring, per-method signatures + fold stubs, onDisposed dispose, pure-Dart skip) | `controller_compile_test.dart` — 1 | `flutter analyze` (cluster incl. presenter) |
| presenter | `test/plugins/presenter/` (new) | `presenter_structural_test.dart` — 3 (canonical path, class/imports/ctor, registerUseCase + typed signature + Eq query body) | `presenter_compile_test.dart` — 1 | `flutter analyze` |
| state | `test/plugins/state/` (existing dir) | `state_structural_test.dart` — 4 new (canonical path, loading flags, copyWith/getters/equality stubs, #512 flavor import switch) on top of existing `state_builder_test.dart` | `state_compile_test.dart` — 1 | `dart analyze --no-fatal-warnings` in a pure-Dart temp package (path dep on this repo) |
| cache | `test/plugins/cache/` (existing dir) | `cache_structural_test.dart` — 4 new (3-file set, entity box init stub, policy + timestamp stubs, non-hive no-op) | `cache_compile_test.dart` — 1 | `dart analyze` (full Hive cache set incl. registrar) |
| repository | `test/plugins/repository/` (existing dir) | `repository_trust_tier_test.dart` — 4 new (simple 3-file set, synced interface+strategy wiring, append preserves + appends, append emits no augment files) covering the **simple / synced / append** variants | `repository_compile_test.dart` — 1 (analyzes simple + synced + cached + append roots together) | `dart analyze` |
| mock (provider_builder) | `test/plugins/mock/mock_provider_builder_test.dart` | +5 new structural (canonical path, class/mixins/contract, imports, get signature + delayed-sample stub, delay ctor) + 2 pre-existing useZorphy tests | +1 compile gate (dart analyze over provider + entity/service/mock-data stubs) → **9 dedicated provider-builder tests** (was 2) | `dart analyze --no-fatal-warnings` |

Shared infrastructure: `test/plugins/helpers/flutter_cluster_fixture.dart`
(Flutter project scaffold + FLUTTER_ROOT-aware executable resolution,
mirroring sc_003's `_dartExecutable` strategy), reused by all three
Flutter-lane compile gates.

## 2. Mutation

No mutation audit was run in this PR. Precedent: feature 042 documented the
same honest gap — the `mutation_test` AOT harness requires per-mutant
full-scope runs and several GB of RAM/disk that this 2-core, 10 GB sandbox
cannot fit (the single-invocation kernel cache alone exhausted the disk
before the chunked runner was adopted, matching the constraint documented in
dart_test.yaml). Test strength is evidenced by the red→green cycle above and
by the compile gates actually catching ten real defects. Follow-up: scope a
`mutation-test.xml` section for the trust-tier builders in a dedicated chore.

## 3. Success criteria — issue #1003

| Criterion | Status | Evidence |
|---|---|---|
| `test/plugins/<name>/` exists for every trust-tier generator | **PROVED** | New dirs: view, controller, presenter; existing dirs extended: state, cache, repository, mock (file inventory in §1) |
| Structural test per variant (temp dir generation; file count + class name + imports + signatures + stub body) | **PROVED** | 25 new structural tests across the seven tiers; repository covers all three variants (simple/synced/append) plus cached compile coverage; mock provider_builder grew from 2 to 9 dedicated tests |
| Compile test per generator (`dart analyze`, or `flutter analyze` for Flutter generators), assert exit 0 | **PROVED** | 7 compile gates green: state/cache/repository/mock under `dart analyze`; view/controller/presenter under `flutter analyze` (real `flutter pub get` + `flutter analyze`, Flutter 3.41.0) — all exit 0 with no ` error - ` lines |
| `dart test test/plugins/` passes with zero regressions | **PROVED** | `tools/run_tests_chunked.sh` (the dart_test.yaml-sanctioned disk-safe form of the full fast suite): 77/77 chunks, `failed_chunks=0`; trust-tier scopes green with their pre-existing tests included (cache +8, controller +5, mock +62, presenter +3, repository +16, state +7, view +4) |
| All deliverables in a single PR; one PR for the spec | **PROVED** | Branch `spec/1003-trust-tier-test-dirs` carries the tests, the shared fixture, and this verification record in one commit series |

## 4. Environment record (this run)

- Dart SDK 3.13.2 (stable) — pure-Dart tier, `dart test`/`dart analyze`
- Flutter 3.41.0 stable (Dart 3.11.0) — Flutter tier,
  `flutter pub get` + `flutter test --tags flutter` + `flutter analyze`
- Repo package config restored to pure-Dart resolution
  (`dart pub get --no-example`) after the Flutter lane, matching the
  `dart_core` CI job
- Temp fixtures under `$TMPDIR` cleaned after each phase (disk housekeeping
  obligation); no source files touched outside the working clone
