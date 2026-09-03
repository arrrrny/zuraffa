# Tasks: 893-simulation-di-binding

- **Spec ID**: 893-simulation-di-binding
- **Created**: 2026-09-03

## T001: Simulation flavor detection
- Parse the compile-time `SIMULATION` value once at DI registration: `true` selects mock DI; `false` or absence selects production DI; malformed values fail startup before either graph is registered
- Ignore persisted `ZfaConfig.mockByDefault` for runtime selection; it remains a generation-time default only
- Tests: `simulation_flavor_detection_test.dart`

## T002: Generated simulation DI
- `zfa make --di` / `zfa mock create` generates DI registration code for mocks
- Flavor switch single `--dart-define`, not hand-wired config
- Generated code registers mock datasources under simulation flavor
- Preserve at least one static-discovery contract in every output: `package:zuraffa/mock.dart`, `zuraffaMockLibrary`, or the canonical `.zfa.json` `mocking` block
- Tests: `simulation_di_generator_test.dart`

## T003: Fixture data wiring
- Each mock datasource loads committed fixtures from `specs/<feature>/tdd/fixtures/`
- Reuse #832 fixture registry for fixture loading
- No real network calls — all data from fixture files
- Tests: `fixture_wiring_test.dart`

## T004: Isolation guard
- Simulation mode never opens real sockets; there are no allowlisted lanes
- Guard asserts no network access at runtime
- Violations surface as runtime errors with clear messaging
- Tests: `isolation_guard_test.dart` covers blocked external and loopback socket attempts plus unaffected non-network work

## T005: Demoability proof
- Any feature reaching `complete(mocked)` is immediately DEMOABLE
- `flutter run --dart-define=SIMULATION=true` boots app on mocks
- No real adapter required
- Tests: `demo_boot_test.dart`

## T006: End-to-end verification
- Run `/speckit.tdd.verify` against the full spec
- Verify simulation boot + isolation guard + fixture wiring work together
- Generate `tdd/verification.md` from real run
- Commit and open PR
