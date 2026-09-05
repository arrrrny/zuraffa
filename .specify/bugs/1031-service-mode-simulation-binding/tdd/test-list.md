# Test List: bug #1031 — service-mode simulation binding shape

Traces: GitHub issue #1031 · assessment in this directory · hard
constraints: service mode must emit service-shaped bindings (not
datasource-shaped); datasource lane unchanged; one PR for this bug only.

- feature: 1031-service-mode-simulation-binding
- source: issue.md (Expected section) + red-evidence.md
- suite tier: fast (`dart test test/plugins/di/simulation_binding_test.dart`)

## Behaviors

| id | behavior | serves | test | state |
| -- | -------- | ------ | ---- | ----- |
| B1 | Service-mode mock create emits `di/simulation/<name>_simulation_service_di.dart` — `register<Name>SimulationService(GetIt)` binds `<Name>Service` -> `<Name>MockProvider()` behind `if (!kSimulationMode) return;`, importing the service interface and mock provider files the service lane actually generated; the datasource-shaped binding file is NOT emitted | issue Expected section; root-cause remediation (branch on `config.hasService`) | `test/plugins/di/simulation_binding_test.dart` → `#1031: service-mode mock create emits the service-shaped simulation binding, not the datasource shape` | green |
| B2 | The regenerated `di/simulation/index.dart` discovers and registers the service-shaped function (`registerAuthSimulationService(getIt);` + file import) via the same RegistrationDetector contract as the datasource lane | FR-002 continuity (index stays in sync for both shapes) | same file → `#1031: simulation index registers the service-shaped binding` | green |
| B3 | Datasource lane unchanged: entity-mode mock create still emits `<entity>_simulation_datasource_di.dart` and never the service shape | hard constraint "datasource lane unchanged" | same file → `#1031: datasource lane unchanged — entity-mode mock create never emits the service shape` | green |

## Regression surface guarded by pre-existing tests

- spec 893 suite (`test/plugins/di/simulation_binding_test.dart` groups A2/A3/U3/U4/U6 and `test/plugins/mock/mock_builder_test.dart` simulation entries) must stay green — they pin the datasource shape, the markers, the index contract and the flavor switch.
- `DiPlugin`'s datasource-lane call site (`emitSimulationBinding` block, guarded by `!config.hasService`) is untouched by the fix.
