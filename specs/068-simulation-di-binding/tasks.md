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

- [x] T006 (REFACTOR) Formatter/analyzer cleanup via tooling; chunked fast
      suite with NO NEW failures; `/speckit.tdd.verify` run for real →
      `tdd/verification.md` committed from this session.

## Phase 7: TDD remediation (from /speckit.tdd.verify — verdict PASS_WITH_GAPS)

Ordered by the verification's finding numbers; HIGH: none. Not blocking
delivery; each is a verifiable change with its proving command.

- [ ] R1 (finding 2, MED) Replace the real-DNS whitelist proof with a
      deterministic refused-loopback lane (`127.0.0.1` + guaranteed-refused
      port) so the test no longer depends on the resolver and never dials a
      real host. Prove: `dart test test/simulation/network_isolation_guard_whitelist_test.dart`
- [ ] R2 (finding 5, MED) Assert `report.fixtures, isEmpty` and the specific
      skip warning in the FR-008 no-op test so a mutant that loads fixtures
      outside the flavor fails. Prove: `dart test test/simulation/simulation_boot_test.dart --plain-name "no-op"`
- [ ] R3 (finding 6, MED) Mirror the missing-file test's `.having((e) => e.entity, 'entity', 'Todo')` chain onto the corrupt-fixture test.
      Prove: `dart test test/simulation/simulation_boot_test.dart --plain-name "corrupt"`
- [ ] R4 (finding 4, MED) Either assert the whitelisted HttpClient
      `connectionFactory` delegation reaches the socket path or correct the
      comment at network_isolation_guard_whitelist_test.dart:102-109. Prove:
      `dart test test/simulation/network_isolation_guard_whitelist_test.dart --plain-name "U8"`
- [ ] R5 (finding 1, MED) Compile or execute the generated simulation
      bindings in a temp package (subprocess probe or `dart analyze` of the
      emitted files) so generator output is verified behaviorally, not
      textually. Prove: `dart test test/plugins/di/simulation_binding_test.dart`
- [ ] R6 (findings 3, 8, 9, MED) Split eager tests (U8 into four; A2 make-di
      into its own test; U14 evidence-log assertions out) and deduplicate the
      default-flavor probe run. Prove: `dart test test/simulation test/plugins/di test/plugins/mock`
- [ ] R7 (findings 7, 10, LOW) Source the A6 demo graph shape from a real
      generation run (or assert generated-text compatibility); pin one
      concrete fixture record value; extract a shared entity/fixture seeding
      helper under `test/simulation/helpers/`; make the probe path
      CWD-independent; rename A6's name to what it asserts. Prove:
      `dart test test/simulation test/plugins/di test/plugins/mock`
