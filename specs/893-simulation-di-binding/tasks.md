# Tasks: Simulation-Mode DI Binding (spec 893)

> Derived from `spec.md` (sole input) and the approved T001–T006 table;
> `tasks.md` was not present in the committed spec directory.

## Phase 1: Flavor detection (T001)

- [ ] T001 (RED first) `lib/src/simulation/simulation_flavor.dart`:
      `kSimulationMode` / `kRealBackendMode` build-time defines,
      `SimulationFlagConflict`, `SimulationFlavor.checkFlagConflicts()`
      (FR-001, FR-012). Test detects `--dart-define=SIMULATION=true` and
      routes to the simulation binding; conflict surface covered.

## Phase 2: Generated simulation DI (T002)

- [ ] T002 (GREEN) Simulation binding builder + emission from BOTH
      `zfa make --di` and `zfa mock create`; single `--dart-define` flavor
      switch in generated code; `di/simulation/` markers for
      distinguishability (FR-002, FR-003, FR-011, FR-013, SC-003, SC-004,
      SC-006). Real datasource DI files skip registration under the
      simulation flavor (edge case: real adapters never interfere).

## Phase 3: Fixture wiring (T003)

- [ ] T003 (GREEN) `zfa mock create --fixtures-dir` writes committed
      per-entity fixture JSON under `specs/<feature>/tdd/fixtures/`,
      re-certified through the #832 `FixtureRegistry` (manifest + hash-
      chained cycle evidence). No real network calls (FR-003, SC-005 prep).

## Phase 4: Isolation guard whitelist (T004)

- [ ] T004 (GREEN) `SocketLane` whitelist on `NetworkIsolationGuard` +
      project-level config loader (`.zfa.json` → `simulation.whitelist`).
      Non-whitelisted sockets blocked with a clear diagnostic; whitelisted
      lanes permitted and logged as approved exceptions; guard inert in
      normal mode (FR-005, FR-006, FR-007, FR-008).

## Phase 5: Demoability (T005)

- [ ] T005 (GREEN) `SimulationBoot.runApp`: conflict gate, guard install,
      entity fixture fail-fast (FR-009), manifest verification, zero-
      mocked-feature warning (FR-010), `SimulationWorld.bindTo`. Scenario
      test proves the mock graph boots end-to-end with fixture data, guard
      active, zero sockets (SC-001, SC-002).

## Phase 6: Refactor + verify (T006)

- [ ] T006 (REFACTOR) Formatter/analyzer cleanup via tooling; chunked fast
      suite with NO NEW failures; `/speckit.tdd.verify` run for real →
      `tdd/verification.md` committed from this session.
