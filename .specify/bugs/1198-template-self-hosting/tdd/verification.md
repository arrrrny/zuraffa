# TDD Verification: 1198-template-self-hosting (template self-hosting)

**Verdict: PROVEN.** Every requirement of the bug brief is implemented,
executed, and green on the fix branch. ACTUAL pass/fail counts below; each
success criterion states what was PROVED and how.

feature: 1198-template-self-hosting (bug #1198, part of #908 P0)
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
verified_at: fix/1198-template-self-hosting (working tree)
behaviors: 5
proven: 5
likely: 0
no_test: 0
suite: template self-hosting 44/44 pure-Dart + 1/1 flutter-lane gate; chunked fast suite 3301 passed / 0 failed (78 executable chunks PASS, 6 slow-tier-only folders SKIP by design); flutter-tagged suite 31 passed / 0 failed / 1 skipped; analyzer 0 errors/0 warnings; dart format drift 0
---

## Requirements → evidence

### 1. Every template has a TDD-loop test suite (structural + compile + behavioral) against a fixture entity — PROVED

Shared harness `test/helpers/template_self_hosting.dart` (fixture entity
`Product` with `id/name/price/createdAt` — the DateTime field is deliberate:
it is the field class whose value historically leaked wall-clock time in
mock output). Nine per-template suites under `test/templates/self_hosting/`:

| Template | Structural | Compile | Behavioral |
| -------- | ---------- | ------- | ---------- |
| usecase | 2 tests | pure-Dart fixture `dart analyze` clean | **executed**: `GetProductUseCase` runs against a stub repo and returns the fixture entity (`dart run tool/behavior_check.dart` exit 0) |
| service | 2 | clean | **executed**: generated `ProductService` contract implemented + called |
| repository | 2 | clean | **executed**: `DataProductRepository` over a stub datasource returns the fixture entity |
| datasource | 2 | clean | **executed**: generated `ProductDataSource` contract implemented + called |
| mock | 2 | clean | **executed**: `ProductMockDataSource().get/getList` returns fixture data (mock-first bar) |
| di | 1 | clean | **executed**: generated `setupDependencies(GetIt.instance)` registers + resolves + is #1102-idempotent + `resetDependencies` unregisters |
| view/skin | 2 | downstream gate | downstream gate (Flutter) |
| state | 2 | clean | **executed**: state machine transitions (initial → loading → loaded) |
| route | 2 | downstream gate | downstream gate (Flutter) |

Result: `dart test test/templates/self_hosting --exclude-tags flutter` →
**44 passed, 0 failed**.

### 2. Diff guard — regenerated output is byte-stable (determinism receipt) — PROVED

Each per-template suite carries a `diff guard` group: the generator runs
TWICE with identical inputs (same pubspec name, same fixture entity, same
config; fresh throwaway dirs), all emitted artifacts are SHA-256
fingerprinted (root-relative paths), and drift must be empty. On success the
harness writes a **determinism receipt** (schema `template.determinism.v1`,
no wall-clock fields, refs → #1198/#908) into the fixture's `.zfa/` home.
9/9 templates byte-stable. Scope note: the guard fingerprints the plugin's
declared generated artifacts (not `.zfa/` receipts, which legitimately carry
wall-clock provenance); the unseeded mock-JSON meta stamp remains a
documented Spec-1001 seeded-replay surface, not a template-artifact drift.

### 3. Downstream-compile gate (minimal Flutter package) — PROVED

`downstream_compile_gate_test.dart` (`@Tags(['flutter'])`) builds a minimal
Flutter consumer (flutter SDK + go_router ^17.2.3 + zuraffa_flutter ^6.1.0;
THIS CHECKOUT wired via a fixture-level `dependency_overrides` — never the
repo's own pubspec), emits ALL nine templates plus the presenter/controller
cluster for the fixture entity, runs `flutter pub get`, and asserts
`flutter analyze lib test` exits 0 with no analyzer errors.

**The gate caught a real defect (RED → GREEN at template level):** the
emitted route did not satisfy the generated view's required
`productRepository` constructor arg — `_resolveDependencyInfo` always
returned empty (dead emission branch; and the branch's `getIt` symbol no
longer exists in get_it 9). Fix in
`lib/src/plugins/route/builders/route_builder.dart`: emit
`GetIt.instance<ProductRepository>()` driven by the view-on-disk contract
(#341 doctrine) + repository-interface import, with custom-usecase and
DI-mode guards. Existing route suites re-run green (97/97 in
test/plugins/route incl. the #912 dry-run pins and the custom-route
zero-arg contract).

Result: **1 passed, 0 failed** (flutter lane). Full `flutter test --tags
flutter --no-pub`: **31 passed, 0 failed, 1 skipped**.

### 4. Templates that fail the loop BLOCK publish — PROVED

- `tools/template_publish_gate.sh` (executable): runs the pure-Dart lane
  (`dart test test/templates/self_hosting --exclude-tags flutter`) and the
  flutter lane (`flutter test ... --tags flutter`); `set -euo pipefail` —
  any loop failure exits non-zero.
- `publish_gate_test.dart` pins: script exists + executable + valid bash +
  drives both lanes + fails closed; CI (`.github/workflows/ci.yaml`) has a
  `template_publish_gate` job invoking it; release
  (`.github/workflows/release.yml`) runs the gate BEFORE `Build MCP
  Server`/`Build CLI` (index-asserted).
- Executed for real: `SKIP_FLUTTER_LANE=1 bash
  tools/template_publish_gate.sh` → exit 0, "every template passed the
  loop"; the flutter lane was executed separately (31/0/1) and runs in CI's
  existing flutter `test` job (`flutter test --tags flutter`) plus the
  release gate.

### 5. RED → GREEN honesty — PROVED

`tdd/cycle-log.md` records the RED evidence: absence proofs (no loop suite,
no diff guard, no downstream gate, no publish gate on master) + the first
full RED run (11 failures) and its diagnosis, including the real
route-template defect the loop caught and the fixture-contract corrections
(get_it async reset, mixin-member obligations, zorphy-surface mirror,
package-name input pinning). The only lib/ change on this branch is the
route-template fix the loop forced.

## Verification battery (ACTUAL results)

| Step (per the brief) | Result |
| -------------------- | ------ |
| `dart analyze lib test` | 0 errors, 0 warnings (104 pre-existing infos — identical to master baseline; CI runs `--no-fatal-warnings`) |
| `tools/run_tests_chunked.sh` semantics, chunk-by-chunk (kernel caches cleaned per chunk, `--exclude-tags flutter`) | **3301 passed, 0 failed**; 78 executable chunks PASS; 6 slow-tier-only folders report "No tests ran" = designed fast-tier skips per dart_test.yaml (benchmark, core/dependencies, core/proof, integration, plugins/tdd/scenarios, tdd/077 — the 077 suite is `@Tags(['slow'])`-deferred by e726bcdb) |
| `dart format .` then `git diff --stat` | zero formatting drift (`dart format --set-exit-if-changed lib test` → 0 changed, exit 0) |
| `dart test test/templates/self_hosting --exclude-tags flutter` | 44 passed, 0 failed |
| `flutter test test/templates/self_hosting --tags flutter --no-pub` | passed (downstream gate) |
| `flutter test --tags flutter --no-pub` (full CI test-job parity) | 31 passed, 0 failed, 1 skipped |
| `SKIP_FLUTTER_LANE=1 bash tools/template_publish_gate.sh` | exit 0 |

## What was not proven / notes

- The determinism receipts are written into each throwaway fixture's `.zfa/`
  (per-run artifacts, not committed); the receipt schema itself is pinned by
  the harness contract (no wall-clock fields) so receipts are comparable
  across runs.
- Flutter toolchain used locally: Flutter 3.41.0 stable (bundles Dart
  3.11.0) for the flutter lane + standalone Dart SDK 3.13.2 (CI `dart_core`
  parity) for analyze/format/pure lanes. CI's flutter `test`/`analyze` jobs
  run 3.47.x, where the fixture's `meta: ^1.18.3` override is a no-op
  (same documented workaround as `flutter_cluster_fixture.dart`).
- Mutation sampling was not re-run for the route-template fix; the fix is
  pinned end-to-end by the downstream gate (compile-level catch) and the
  route suite (contract-level).
