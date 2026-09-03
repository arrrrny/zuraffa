---
feature: 893-simulation-di-binding
loop: outside-in
profile: .specify/memory/tdd-profile.md
spec_criteria: 6
planned_at: 893-simulation-di-binding
updated_at: 893-simulation-di-binding
suite_baseline: green
---

# Test List: Simulation-Mode DI Binding (spec 893)

Baseline: `dart analyze lib test` green before cycle A1/U1 (1 pre-existing
unrelated warning: `unused_import` in `test/commands/entity_help_test.dart`).
Fast suite baseline via `tools/run_tests_chunked.sh` — green.

## Outer loop: acceptance behaviors

| id | behavior | traces | kind | state | test |
|----|----------|--------|------|-------|------|
| A1 | SIMULATION=true routes the composition root to simulation bindings while the default boot keeps real bindings | US1/US2; FR-001, FR-013 | acceptance | DONE | test/simulation/simulation_flavor_test.dart::U1: SIMULATION define routes kSimulationMode to true |
| A2 | generated simulation DI binds every mock datasource under its production interface with a single --dart-define switch, with zero manual registration | US2; FR-002, FR-003, SC-003, SC-004 | acceptance | DONE | test/plugins/di/simulation_binding_test.dart::A2: zfa mock create and zfa make --di generate the simulation binding without manual wiring |
| A3 | simulation-generated bindings are distinguishable from hand-written bindings | US2; FR-011, SC-006 | acceptance | DONE | test/plugins/di/simulation_binding_test.dart::A3: simulation bindings are distinguishable by location and generated markers |
| A4 | isolation guard blocks non-whitelisted sockets and permits whitelisted lanes in simulation mode | US3; FR-005, FR-006, FR-007 | acceptance | DONE | test/simulation/network_isolation_guard_whitelist_test.dart::A4: guard permits whitelisted lanes and blocks every other socket |
| A5 | simulation vs real-backend flag conflict resolves explicitly, never silently | FR-012; edge cases | acceptance | DONE | test/simulation/simulation_flavor_test.dart::A5: conflicting SIMULATION and REAL_BACKEND defines produce an explicit conflict error |
| A6 | boot on certified mocks fails fast naming the entity when fixtures are missing or corrupt, warns on zero mocked features, and runs the mock graph end-to-end with zero sockets | US1; FR-004, FR-009, FR-010, SC-001, SC-002, SC-005 | acceptance | DONE | test/simulation/simulation_boot_test.dart::A6: simulation boot validates entity fixtures, warns on zero features, and runs the mock graph on fixture data |

## Inner loop: unit behaviors

### `lib/src/simulation/simulation_flavor.dart` (flavor detection + conflicts)

| id | behavior | traces | kind | state | test |
|----|----------|--------|------|-------|------|
| U1 | kSimulationMode is a compile-time const detecting the SIMULATION dart-define (default false) | FR-001, FR-013 | unit | DONE | test/simulation/simulation_flavor_test.dart::U1: SIMULATION define routes kSimulationMode to true |
| U2 | checkFlagConflicts throws SimulationFlagConflict only when both defines are set | FR-012 | unit | DONE | test/simulation/simulation_flavor_test.dart::A5: conflicting SIMULATION and REAL_BACKEND defines produce an explicit conflict error |

### `lib/src/plugins/di/builders/simulation_binding_builder.dart` (generated bindings)

| id | behavior | traces | kind | state | test |
|----|----------|--------|------|-------|------|
| U3 | binding file registers the mock under the production datasource interface guarded by kSimulationMode | FR-002, FR-003, FR-013 | unit | DONE | test/plugins/di/simulation_binding_test.dart::U3: generated binding registers the mock under the interface behind the flavor guard |
| U4 | simulation index exposes registerSimulationBindings running the conflict gate first | FR-012, FR-002 | unit | DONE | test/plugins/di/simulation_binding_test.dart::U4: simulation index runs the flag-conflict gate before registering bindings |
| U5 | real datasource DI files skip registration when the simulation flavor is active | edge cases; FR-003 | unit | DONE | test/plugins/di/simulation_binding_test.dart::U5: real datasource registration is guarded against the simulation flavor |
| U6 | main di index calls registerSimulationBindings when a simulation index exists | FR-002, SC-004 | unit | DONE | test/plugins/di/simulation_binding_test.dart::U6: main di index wires registerSimulationBindings into setupDependencies |

### `lib/src/simulation/network_isolation_guard.dart` (whitelist lanes)

| id | behavior | traces | kind | state | test |
|----|----------|--------|------|-------|------|
| U7 | SocketLane matches exact hosts, wildcard subdomains, and optional ports | FR-006 | unit | DONE | test/simulation/network_isolation_guard_whitelist_test.dart::U7: socket lane matching covers exact hosts, wildcard subdomains and ports |
| U8 | whitelisted connects delegate to the pre-install overrides and are recorded as approved exceptions | US3; FR-006, FR-007 | unit | DONE | test/simulation/network_isolation_guard_whitelist_test.dart::A4: guard permits whitelisted lanes and blocks every other socket |
| U9 | default install keeps blocking everything (empty whitelist is the safest default) | edge cases; FR-005 | unit | DONE | test/simulation/network_isolation_guard_test.dart (existing #832 suite stays green) |

### `lib/src/simulation/simulation_whitelist.dart` (config)

| id | behavior | traces | kind | state | test |
|----|----------|--------|------|-------|------|
| U10 | whitelist config loads SocketLanes from the project-level config file (string or object form) | FR-006 | unit | DONE | test/simulation/simulation_whitelist_test.dart::U10: whitelist config parses lanes from the project config file |

### `lib/src/simulation/entity_fixture.dart` (fixture validation)

| id | behavior | traces | kind | state | test |
|----|----------|--------|------|-------|------|
| U11 | entity fixture validation fails fast naming the entity for missing and corrupt fixtures | FR-009, SC-005 | unit | DONE | test/simulation/simulation_boot_test.dart::U11: entity fixture validation names the failing entity |

### `lib/src/simulation/simulation_boot.dart` (demo boot)

| id | behavior | traces | kind | state | test |
|----|----------|--------|------|-------|------|
| U12 | boot installs the guard, verifies the #832 manifest, and binds the world to the container | FR-004, FR-005; SC-002 | unit | DONE | test/simulation/simulation_boot_test.dart::A6: simulation boot validates entity fixtures, warns on zero features, and runs the mock graph on fixture data |
| U13 | boot warns when zero complete(mocked) features are available | FR-010; edge cases | unit | DONE | test/simulation/simulation_boot_test.dart::A6: simulation boot validates entity fixtures, warns on zero features, and runs the mock graph on fixture data |

### `lib/src/plugins/mock/builders/simulation_fixture_writer.dart` (committed fixtures)

| id | behavior | traces | kind | state | test |
|----|----------|--------|------|-------|------|
| U14 | `zfa mock create --fixtures-dir` commits `<entity>_fixtures.json` and re-certifies the #832 manifest + cycle evidence | FR-003; #832 req 3 | unit | DONE | test/plugins/mock/simulation_fixture_writer_test.dart::U14: mock create commits per-entity fixtures through the fixture registry |
