# Cycle Log: bug #1031 — service-mode simulation binding shape

Append only. Newest last. Every entry's `red` block is the evidence that
the test existed and failed before the implementation.

## Baseline

- suite: full fast tier via `tools/run_tests_chunked.sh` (74 chunks,
  `--exclude-tags flutter`) -> all chunks passed, 0 failures at branch
  base `77e69f24`
- CI-scope analyze: `dart analyze lib test --no-fatal-warnings` -> exit 0
  (294 info / 20 warning / 0 errors)
- recorded: cycle 0, before any change

## Cycle 1: service-mode mock create emits the service shape (bug #1031)

- behavior: the mock plugin's simulation-binding call site branches on
  `config.hasService`; service mode emits the service-shaped binding
  (`register<Name>SimulationService` binding `<Name>Service` ->
  `<Name>MockProvider`) and never the datasource shape, mirroring how the
  datasource lane binds `<Entity>DataSource` -> `<Entity>MockDataSource`.
- tests (new group `Issue #1031: service-mode simulation binding shape`
  in `test/plugins/di/simulation_binding_test.dart`; B1/B2/B3 in
  `test-list.md`):
  - B1 pins file name, function name, flavor guard, interface-typed
    registration, mock provider construction, both resolving imports, the
    public simulation barrel, and the ABSENCE of the datasource-shaped file
  - B2 pins index discovery of the service-shaped function
  - B3 pins datasource-lane invariance (entity mode never emits the
    service shape)
- red (real, pre-fix):
  - CLI-level: the issue's verbatim repro run in a scratch project
    (`zfa service create Auth` → `zfa usecase create Login` →
    `zfa mock create --name Auth --service Auth --params AuthRequest
    --returns User --domain auth`) emitted
    `lib/src/di/simulation/auth_simulation_datasource_di.dart`;
    `dart analyze` reported the four binding errors
    (`uri_does_not_exist` x2 on `auth_datasource.dart` /
    `auth_mock_datasource.dart`, `non_type_as_type_argument` on
    `AuthDataSource`, `undefined_function` on `AuthMockDataSource`) —
    saved in `../red-evidence.md`
  - unit-level: `dart test test/plugins/di/simulation_binding_test.dart`
    -> exit 1, `+8 -2: Some tests failed.` (B1 and B2 red; B3 green by
    construction — the datasource lane was never broken)
- green:
  - fix: `SimulationBindingBuilder.buildServiceBindingFile` +
    `SimulationBindingEmitter.emitServiceBinding` (shared flavor-guarded
    `_registrationFunction` body) and the `config.hasService` branch at
    the mock plugin call site with `_generateServiceDI`-mirroring import
    resolution
  - unit re-run: `dart test test/plugins/di/simulation_binding_test.dart`
    -> `+10: All tests passed!`
  - CLI re-run: the verbatim repro now emits
    `lib/src/di/simulation/auth_simulation_service_di.dart` with EXACTLY
    the issue's expected body
    (`registerAuthSimulationService` →
    `getIt.registerLazySingleton<AuthService>(() => AuthMockProvider())`
    behind `if (!kSimulationMode) return;`), the index registers
    `registerAuthSimulationService(getIt);`, and `dart analyze` reports
    ZERO errors under `di/simulation/`
  - full fast tier: 74/74 chunks passed, 0 failures (no new failures)
  - CI-scope analyze: exit 0, identical counts to baseline
    (294 info / 20 warning / 0 errors)
- refactor: none required (per the remediation plan). Structural note:
  the datasource and service builders share one private
  `_registrationFunction` / `_simulationDirectives` / `_wrapBinding`
  helper set, so the two shapes cannot drift on the flavor-switch body.
- deliberate mutant (mutation sampling; no mutation tool in profile):
  the bug was replayed by stashing the two lib changes while keeping the
  new tests — `dart test test/plugins/di/simulation_binding_test.dart`
  -> exit 1, B1+B2 red again (the tests detect the original bug);
  restoring the fix returned `+10: All tests passed!`. 1 mutant, 1 caught.
- commit: (this commit)
