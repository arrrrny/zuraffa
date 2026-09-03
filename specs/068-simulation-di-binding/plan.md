# Plan: Simulation-Mode DI Binding (spec 893)

**Branch**: `spec/893-simulation-di-binding` · **Parent epic**: #908 (Mock-First Realization) · **Closes**: #914 · **References**: #832 (simulate adapters + isolation guard), #807 (proof-carrying)

> Note: `plan.md` and `tasks.md` were not present in the committed spec
> directory (`specs/893-simulation-di-binding/` shipped with `spec.md` and
> `checklists/requirements.md` only). This plan and the companion
> `tasks.md` are derived from `spec.md` (sole input) and the approved
> T001–T006 task table; no re-triage was performed.

## Command contract

1. Generated DI: the simulation binding is generated, not hand-wired; the
   flavor switch is a single `--dart-define=SIMULATION=true`.
2. Fixture data: every mock datasource uses committed fixtures from
   `specs/<feature>/tdd/fixtures/` (extends #832 simulate adapters).
3. Isolation guard: simulation mode never opens real sockets except through
   explicitly whitelisted lanes (landed with #832, extended here with the
   lane whitelist API).
4. Feature completeness: any feature reaching `complete(mocked)` is
   immediately DEMOABLE — no real adapter required.

## Architecture

### T001 — Simulation flavor detection (runtime, `lib/src/simulation/`)

- `simulation_flavor.dart`: `const bool kSimulationMode =
  bool.fromEnvironment('SIMULATION', defaultValue: false)` (repo precedent:
  `core/api_bridge.dart` `dart.vm.product`), plus
  `kRealBackendMode = bool.fromEnvironment('REAL_BACKEND', …)`.
- `SimulationFlavor.checkFlagConflicts()` throws `SimulationFlagConflict`
  when both defines are set (FR-012: explicit conflict, never silent
  fall-through).
- Public barrel `lib/simulation.dart` (mirrors `lib/mock.dart` precedent)
  exporting flavor, guard, world, registry, boot pieces.

### T002 — Generated simulation DI (generator, `lib/src/plugins/di/` + mock plugin)

- New builder `plugins/di/builders/simulation_binding_builder.dart` emits
  `di/simulation/<entity>_simulation_datasource_di.dart`
  (`registerLazySingleton<<Entity>DataSource>(() => <Entity>MockDataSource())`)
  guarded by `if (!kSimulationMode) return;` — generated, not hand-wired.
- `di/simulation/index.dart` → `registerSimulationBindings(GetIt)` calls
  `SimulationFlavor.checkFlagConflicts()` first, then every entity binding.
- Both `zfa make --di` (DiPlugin when mock-DI ran) and `zfa mock create`
  (MockPlugin when a mock datasource was generated) invoke the shared
  emitter — zero manual steps (FR-002, SC-003).
- `di/index.dart` `setupDependencies` gains
  `registerSimulationBindings(getIt);` through the existing index-merge
  machinery (`AppendExecutor`) when the simulation index is present.
- Real datasource DI files (remote/local/sqlite) gain
  `if (kSimulationMode) return;` so simulation mode exclusively uses mocks
  (edge case: real adapters must not interfere).
- Distinguishability (FR-011): dedicated `di/simulation/` location +
  `SIMULATION BINDING` generated-file markers.

### T003 — Fixture data wiring (generator + runtime)

- `zfa mock create <entity> --fixtures-dir <dir>` writes
  `<entity>_fixtures.json` (schema-1, per-entity records derived from the
  analyzed entity fields) into `specs/<feature>/tdd/fixtures/` and
  re-certifies via #832 `FixtureRegistry.writeManifest` +
  `appendCycleEvidence` (hash-chained, kind `fixtures`).
- Runtime `lib/src/simulation/entity_fixture.dart` validates entity fixture
  files at boot (FR-009: fail fast naming the entity on missing/corrupt
  fixtures).

### T004 — Isolation guard whitelist (runtime, extends #832 guard)

- `NetworkIsolationGuard.install({whitelist})` gains `SocketLane` entries
  (host + optional port; wildcard subdomain via leading dot). Whitelisted
  connects are permitted (delegating to pre-install overrides) and logged
  as approved exceptions; everything else still throws
  `NetworkIsolationViolation` before dial/DNS.
- `SimulationWhitelistConfig` loads lanes from a project-level config file
  (`.zfa.json` → `simulation.whitelist`). Empty whitelist = block all
  (safest default, existing behavior unchanged).
- FR-008: guard stays inert in normal (non-simulation) mode.

### T005 — Demoability proof (runtime)

- `SimulationBoot.runApp(container:, featureDir:, entities:, whitelist:)`:
  conflict gate → guard install → entity fixture validation (FR-009) →
  manifest verification (#832 reuse) → zero-`complete(mocked)` warning
  (FR-010) → `SimulationWorld.load` + `bindTo(container)`.
- Scenario test proves the generated-style mock graph (mock datasource →
  repository → use case) boots and serves fixture data through the DI
  container with the guard active and zero sockets.

## Verification strategy

- `dart analyze lib test --no-fatal-warnings` (CI gate).
- Fast suite via `tools/run_tests_chunked.sh` (cloud disk safety; the
  single-invocation kernel cache can overflow a ~10 GB disk).
- `dart format .` before delivery (CI format gate).
- `/speckit.tdd.verify` audit → `specs/893-simulation-di-binding/tdd/verification.md`
  generated fresh from the real run.
