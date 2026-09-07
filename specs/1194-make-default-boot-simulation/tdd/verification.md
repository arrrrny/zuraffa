feature: 1194-make-default-boot-simulation
verdict: PASS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
verified_at: 7b383faa
behaviors: 9
proven: 9
likely: 0
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 3
criteria_covered: 3
mutation_score: null # no mutation tool wired; 6 deliberate mutants, 6 caught, 0 survived
mutants_survived: 0
suite: 7 passed, 0 failed (make_default_tier_plan_test.dart, fast tier) + 3 passed, 0 failed (make_mock_default_e2e_test.dart, slow e2e incl. the simulation-boot proof) + full fast suite green (tools/run_tests_chunked.sh, 92 chunks, 0 failures) + targeted slow-tier green (make_command_test 17/17, issue_348 3/3, make_receipt+xray 5/5, regression cli/323 18/18)
---

# TDD Verification: spec 1194 — make-default boots in simulation mode

**Verdict: PASS — all 9 behaviors are PROVEN test-first (RED observed
before implementation, GREEN after, same commits); no `HIGH` smells,
every acceptance criterion of issue #1194 is covered end to end
(including a real `dart run -DSIMULATION=true` boot proof of a fresh
`zfa make Inventory --preset=crud` slice), and all six deliberate
mutants were caught.**

Audit run by the same session that wrote the tests (stated per the TDD
extension's Hard Rule 2): every artifact referenced below was re-run
for this report — the RED counts, the GREEN runs, the mutation kills,
and the final restore-verification — rather than recited from memory.

## RED-phase evidence (observed before any implementation)

The RED state was recorded twice, independently:

1. **Manual reproduction** (`scripts/red_repro.sh`, pre-change AOT
   binary): `zfa make Product --preset=crud` in a fresh workspace exits 0
   (compile-green) with `MISSING` for every mocked-tier artifact —
   `product_mock_datasource.dart`, `product_mock_data.dart`,
   `di/simulation/product_simulation_datasource_di.dart`,
   `di/simulation/index.dart` — and `registerSimulationBindings` ABSENT
   from `di/index.dart`; the proof.v1 receipt input has no `tier` key.
   That is issue #1194's exact complaint: compile-green, not demo-green.
2. **Test RED** (new tests, pre-implementation): 
   `make_default_tier_plan_test.dart` → **2 passed / 5 failed** (the two
   passing tests are intentional guards: `--without=mock` exclusion and
   engine-preset-keeps-mock — they assert machinery that already
   existed). Failing: crud resolves the mocked tier; read-only parity;
   `--compile-only` opt-out (flag did not exist — usage error);
   `--compile-only` wins over `--mock`; engine token + `--compile-only`.
   `make_mock_default_e2e_test.dart` → **0 passed / 3 failed** (mocked
   tier files missing; opt-out flag unknown; simulation binding absent
   in the boot-proof workspace).

## Test-first evidence

| Behavior | Class | Evidence |
| -------- | ----- | -------- |
| B1 crud preset bundles `mock` | PROVEN | RED: plan test failed (plugin_ids without `mock`) + manual repro; GREEN: `make_default_tier_plan_test.dart` "crud preset resolves the mocked tier"; pinned further by `preset_registry_test` (#1194 group), `engine_preset_test`, updated `make_engine_plan_test` exact list |
| B2 read-only parity | PROVEN | RED: plan test failed; GREEN: "read-only preset resolves the mocked tier" |
| B3 mocked-tier artifacts emitted (mock datasource + seeds + binding + index) | PROVEN | RED: 4× MISSING in manual repro + e2e failure; GREEN: e2e test 1 asserts all four files + binding content (`if (!kSimulationMode) return;`, `registerLazySingleton<ProductDataSource>(() => ProductMockDataSource())`) + seeded `Product(id: 'id 1')` |
| B4 `di/index.dart` wires `registerSimulationBindings` (no hand wiring) | PROVEN | RED: ABSENT in manual repro; GREEN: e2e test 1 asserts `registerSimulationBindings(getIt);` in the generated composition root |
| B5 receipt records MOCKED as the tier | PROVEN | RED: no `tier` key in receipt input (manual repro); GREEN: e2e test 1 asserts proof.v1 `input.tier == "MOCKED"` and digest-binds the mocked-tier files |
| B6 certified mocks by default | PROVEN | RED: no `.zfa/receipts/mock-product.json`; GREEN: e2e test 1 asserts the certification receipt with `mock-cert:product@…` registry id (AST conformance + fixture digests) |
| B7 `--compile-only` opt-out | PROVEN | RED: flag unknown (usage error, exit != 0) in 3 plan tests + e2e; GREEN: `--compile-only` drops mock across crud/engine, overrides `--mock`, e2e test 2 asserts no mocked-tier files, no simulation wiring, receipt `tier == "COMPILE-ONLY"` |
| B8 fresh slice boots in simulation mode | PROVEN | RED: simulation binding missing in the boot workspace; GREEN: e2e test 3 — `zfa make Inventory --preset=crud` → `zfa build` → `dart run -DSIMULATION=true tool/boot_check.dart` exits 0 with `getIt<InventoryDataSource>()` resolving `InventoryMockDataSource` and serving seeded data |
| B9 mocked-tier make run never breaks existing flows (transaction safety) | PROVEN | discovered during GREEN: crud + `--use-mock` hit the di+mock double-binding transaction conflict; fixed by the DiPlugin co-active guard; pinned by the pre-existing `#346 — with di --use-mock` slow test (17/17 green after fix) |

## Strength evidence

### Mutation sampling (no mutation tool wired; 6 deliberate mutants, 6 caught, 0 survived)

Six deliberate mutants were applied one at a time to the
highest-risk behaviors, each restored via `git checkout -- <file>`
and verified green afterwards (scoped fast suite 66/66 + e2e 3/3 +
analyze clean on the changed files):

| Mutant | Behavior | Survived | Judgment |
| ------ | -------- | -------- | -------- |
| `preset_registry.dart`: crud drops `mock` | B1 | No | 3 tests failed (crud plan, engine_preset non-disturbance, plan_resolver exact list) |
| `plan_resolver.dart`: `--compile-only` exclusion disabled | B7 | No | 3 tests failed (all three compile-only plan tests) |
| `make_command.dart`: tier label mutated (`MOCKED` → `MOCKED-X`) | B5 | No | e2e receipt-tier assertion failed |
| `make_command.dart`: certification post-pass forced off | B6 | No | e2e certification-receipt assertion failed |
| `di_plugin.dart`: mock co-active guard forced false | B9 | No | `#346 --use-mock` make run exits 1 (the double-binding transaction conflict resurfaces) |
| `di_plugin.dart`: default methods regain stale `toggle` | B8 (compile leg) | No | boot proof fails — `toggle_inventory_usecase_di.dart` references a usecase class never generated |

Sample: 6 mutants across B1, B5, B6, B7, B8, B9 — the
highest-risk subset, not the full behavior set. Restore verified by a
final scoped run: 66 fast + 3 e2e passed, 0 failed, and
`dart analyze` on the three changed lib files reports no new issues
(the single `prefer_collection_literals` info pre-exists on master).

## Acceptance-criteria coverage (issue #1194)

| Criterion | Covering tests | Status |
| --------- | -------------- | ------ |
| A fresh `zfa make` slice runs the app immediately in simulation mode (no hand wiring) | e2e test 3 (boot proof: setupDependencies + `getIt<InventoryDataSource>()` → mock, seeded record served, exit 0 under `-DSIMULATION=true`); e2e test 1 (binding content + composition-root wiring) | PROVED |
| The receipt/ladder records MOCKED as the tier (swapping to REAL is `zfa tdd realize`'s job) | e2e test 1 (`input.tier == "MOCKED"`, digest-bound mocked-tier files); e2e test 2 (`tier == "COMPILE-ONLY"` opt-out); run output + JSON summary name the tier and the swap command | PROVED |
| Opt-out flag for teams who want compile-only slices | `--compile-only`: 3 fast plan tests (crud, engine token, wins-over-`--mock`) + plan_resolver unit test (warning text) + e2e test 2 (no mocked-tier files, no simulation wiring) | PROVED |

Also covered (issue's "what to build" body): the DI registers the
certified mock datasource behind the real interface (e2e test 1 binding
content assertions) and mock data seeds exist (e2e test 1 seed
assertions). "Bootable on certified mocks" is proven by the
certification receipt (B6) plus the boot proof (B8) — the mock that
serves the boot is the mock the run certified.

## Suite state (final, restored tree)

- `dart test test/commands/make_default_tier_plan_test.dart` — 7/7.
- `dart test test/commands/make_mock_default_e2e_test.dart --preset=all` — 3/3.
- `tools/run_tests_chunked.sh` (the mandated fast-suite runner): 92
  chunks — 87 executed green (0 failures; the first pass covered 61
  chunks before a session window interrupted it, the remainder were
  re-run with the runner's exact semantics — `--exclude-tags flutter`,
  "No tests ran" = SKIP), 5 folders are slow-only by design (benchmark,
  core/dependencies, core/proof, integration, plugins/tdd/scenarios —
  dart_test.yaml excludes `slow` from the default tier).
- Targeted slow-tier reruns on the changed surface:
  `make_command_test.dart` 17/17, `issue_348` 3/3,
  `make_receipt_test.dart` + `make_command_xray_default_test.dart` 5/5,
  `regression/cli_command_test.dart` + `issue_323` 18/18.
- `dart analyze`: 135 issues on this branch == 135 on master
  (identical baseline; the 31 errors are the pre-existing un-generated
  `examples/todo_tdd` artifacts) — zero new issues introduced.
- `dart format .`: idempotent — second run reports 0 changed;
  `git diff --stat` shows only the intended files.

### Known pre-existing failures (NOT introduced by this branch — both
verified failing identically on a stashed master tree in this
environment; they are environment/infra-dependent, not regressions)

- `make_engine_command_test.dart` "spec 1110 criterion 2": the
  generated contract-test workspace's pubspec carries no `test`
  package, so the engine check's `dart analyze` leg reports
  unresolvable `package:test` imports in this offline environment.
- `toggle_method_test.dart` "#289": the CodeGenerator fixture never
  generates the mock datasource the test builder looks for in this
  environment.
