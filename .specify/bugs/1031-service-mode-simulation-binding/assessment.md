# Bug Assessment: service-mode mock create emits datasource-shaped simulation binding referencing nonexistent classes

- **Slug**: 1031-service-mode-simulation-binding
- **Created**: 2026-09-04
- **Source**: https://github.com/arrrrny/zuraffa/issues/1031
- **Verdict**: valid
- **Severity**: medium

## Report (verbatim or summarized)

The service-mode `zfa mock create` emits `lib/src/di/simulation/auth_simulation_datasource_di.dart`
binding `AuthDataSource -> AuthMockDataSource`, but in service mode no
datasource pair is generated — the imports do not resolve
(`uri_does_not_exist`) and the binding binds interfaces that were never
generated. Expected: the simulation binding follows the service shape it
actually generated (`<Name>Service` -> `<Name>MockProvider`), mirroring how
the datasource lane binds `<Entity>DataSource` -> `<Entity>MockDataSource`.
Found while building the ZikZak login engine slice (#1008).

## Symptom

After `zfa mock create --name Auth --service Auth --params AuthRequest
--returns User --domain auth`, `dart analyze` fails on the emitted
simulation binding with four errors: `uri_does_not_exist` on
`../../data/datasources/auth/auth_datasource.dart` and
`../../data/datasources/auth/auth_mock_datasource.dart`,
`non_type_as_type_argument` on `AuthDataSource`, and
`undefined_function` on `AuthMockDataSource`. Every service-mode engine
slice hits the same debris.

## Reproduction

1. `zfa service create Auth --params AuthRequest --returns User`
2. `zfa usecase create Login --domain auth --service AuthService --params AuthRequest --returns User`
3. `zfa mock create --name Auth --service Auth --params AuthRequest --returns User --domain auth`
4. `dart analyze` -> binding errors under `lib/src/di/simulation/`

(Verified verbatim in a scratch project — see `red-evidence.md`.)

## Suspected Code Paths

- `SimulationBindingBuilder.buildBindingFile`
  (`lib/src/plugins/di/builders/simulation_binding_builder.dart`) —
  hardcoded to the datasource shape
  (`register<Entity>SimulationDataSource`,
  `<Entity>DataSource`/`<Entity>MockDataSource`)
- `MockPlugin.generate` simulation-binding block
  (`lib/src/plugins/mock/mock_plugin.dart`) — calls
  `SimulationBindingEmitter.emitBinding` unconditionally, without
  branching on `config.hasService`, even though the mock lane itself
  branches (`if (config.hasService) providerBuilder.generateMockProvider(...)`)
  and generates no datasource pair in service mode

## Root Cause Hypothesis

High confidence: `buildBindingFile` was written for the spec-893
datasource lane only; when service-mode mock creation adopted
`MockProviderBuilder` (#1027 lineage), the simulation-binding call site
was not updated to branch on `config.hasService`. The emitter therefore
binds a datasource pair that the service lane never generates.

## Proposed Remediation

Branch on `config.hasService` in the mock plugin's call site. Service
mode emits `di/simulation/<name>_simulation_service_di.dart` via a new
`buildServiceBindingFile`/`emitServiceBinding` pair
(`register<Name>SimulationService(GetIt)` binding
`<Name>Service` -> `<Name>MockProvider()` behind the same
`if (!kSimulationMode) return;` switch), with import resolution
mirroring `DiPlugin._generateServiceDI`. The datasource lane keeps the
existing shape unchanged.

**Files changed**:
- `lib/src/plugins/di/builders/simulation_binding_builder.dart`
  (new service-shape builder + emitter method, shared registration body)
- `lib/src/plugins/mock/mock_plugin.dart` (call-site branch on hasService)
- `test/plugins/di/simulation_binding_test.dart` (B1/B2/B3 pins)

**Tests added**:
- service-mode binding shape pin (file, function, guard, typed
  registration, resolving imports, absence of datasource shape)
- simulation-index discovery of the service-shaped function
- datasource-lane invariance (entity mode never emits the service shape)

## Risks & Considerations

- Pre-fix debris: trees that already carry a datasource-shaped binding
  from an earlier run keep it on disk (the fix does not purge); the
  issue's sandbox already deleted it manually, and clean trees never
  produce it again.
- A project legitimately holding BOTH an entity datasource lane and a
  service lane for the same name keeps both shapes — the fix keys each
  shape to its own file (`*_simulation_datasource_di.dart` vs
  `*_simulation_service_di.dart`), so no cross-lane deletion occurs.
- `DiPlugin`'s datasource-lane emission is guarded by `!config.hasService`
  and is untouched.

## Open Questions

None — the issue pins the exact expected emitted body.
