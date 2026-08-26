# TDD Test List: Plugin System & UseCase Abstraction Layer (Feature 013)

**Feature**: 013-plugin-usecase-abstraction  
**Spec**: specs/013-plugin-usecase-abstraction/spec.md  
**Plan**: specs/013-plugin-usecase-abstraction/plan.md  
**Planned at**: 614e648  

---

## Acceptance Behaviors (Outer Loop)

| ID | Behavior | Source | Status | Test Name & Path |
|----|----------|--------|--------|------------------|
| A1 | `ZuraffaDIContainer` registration methods (`registerLazySingleton`, `registerFactory`, `registerSingleton`, `registerInstance`) support `override` parameter | spec.md AC1 | DONE | `override parameter` in `test/core/module/di_container_override_test.dart` |
| A2 | `InterceptorRegistry` chains interceptors by type, runs in registration order | spec.md AC2 | DONE | `InterceptorRegistry` tests in `test/core/module/interceptor_registry_test.dart` |
| A3 | `InterceptableUseCase` integrates the interceptor pipeline (runs interceptors before executeCall) | spec.md AC3 | DONE | `InterceptableUseCase` tests in `test/core/usecase_interceptor/interceptable_usecase_test.dart` |
| A4 | `Zuraffa` facade exposes `registerInterceptor` and `clearInterceptors` | spec.md AC4 | DONE | Covered by `interceptorRegistry` group in `test/core/module/di_container_override_test.dart` |
| A5 | `UseCaseContractFactory` generates contract/impl pairs | spec.md AC5 | DONE | `UseCaseContractFactory` tests in `test/core/builder/factories/usecase_contract_factory_test.dart` |
| A6 | `zfa plugin add <package>` added to `PluginCommand` | spec.md AC6 | DONE | `PluginCommand.execute add` in `test/commands/plugin_command_add_test.dart` |
| A7 | Example plugin demonstrates DI override and interceptor | spec.md AC7 | PENDING | No integration test found for example plugin |
| A8 | Tests for all new features | spec.md AC8 | DONE | All core features have tests |

---

## Unit Behaviors (Inner Loop)

### Phase 1: DI Override (from plan.md)

| ID | Behavior | Status | Test Name & Path |
|----|----------|--------|------------------|
| U1 | `registerLazySingleton` throws `StateError` when duplicate registration without `override: true` | DONE | `registerLazySingleton throws when duplicate without override` in `test/core/module/di_container_override_test.dart` |
| U2 | `registerLazySingleton` replaces existing registration when `override: true` | DONE | `registerLazySingleton replaces with override: true` in `test/core/module/di_container_override_test.dart` |
| U3 | `registerFactory` throws `StateError` when duplicate registration without `override: true` | DONE | `registerFactory throws when duplicate without override` in `test/core/module/di_container_override_test.dart` |
| U4 | `registerFactory` replaces existing registration when `override: true` | DONE | `registerFactory replaces with override: true` in `test/core/module/di_container_override_test.dart` |
| U5 | `registerSingleton` throws `StateError` when duplicate registration without `override: true` | DONE | `registerSingleton throws when duplicate without override` in `test/core/module/di_container_override_test.dart` |
| U6 | `registerSingleton` replaces existing registration when `override: true` | DONE | `registerSingleton replaces with override: true` in `test/core/module/di_container_override_test.dart` |
| U7 | `registerInstance` throws `StateError` when duplicate registration without `override: true` | DONE | `registerInstance throws when duplicate without override` in `test/core/module/di_container_override_test.dart` |
| U8 | `registerInstance` replaces existing registration when `override: true` | DONE | `registerInstance replaces with override: true` in `test/core/module/di_container_override_test.dart` |
| U9 | `override: true` with `instanceName` does not affect unnamed registration | DONE | `override with instanceName does not affect unnamed` in `test/core/module/di_container_override_test.dart` |
| U10 | Error message mentions the type and "override" keyword | DONE | `error message mentions the type` in `test/core/module/di_container_override_test.dart` |

### Phase 2: Interceptor Pipeline

| ID | Behavior | Status | Test Name & Path |
|----|----------|--------|------------------|
| U11 | `InterceptorRegistry.isEmpty` is true when no interceptors registered | DONE | `isEmpty is true when no interceptors registered` in `test/core/module/interceptor_registry_test.dart` |
| U12 | `InterceptorRegistry.entriesFor` returns empty list when none registered | DONE | `entriesFor returns empty list when none registered` in `test/core/module/interceptor_registry_test.dart` |
| U13 | `InterceptorRegistry.register` adds entry for the correct type | DONE | `register adds entry for the correct type` in `test/core/module/interceptor_registry_test.dart` |
| U14 | `InterceptorRegistry.entriesFor` returns empty for wrong type | DONE | `entriesFor returns empty for wrong type` in `test/core/module/interceptor_registry_test.dart` |
| U15 | `InterceptorRegistry.chain` returns tail when no interceptors | DONE | `chain returns tail when no interceptors` in `test/core/module/interceptor_registry_test.dart` |
| U16 | `InterceptorRegistry.chain` runs single interceptor before tail | DONE | `chain runs single interceptor before tail` in `test/core/module/interceptor_registry_test.dart` |
| U17 | `InterceptorRegistry.chain` runs interceptors in registration order | DONE | `chain runs interceptors in registration order` in `test/core/module/interceptor_registry_test.dart` |
| U18 | `InterceptorRegistry.chain` allows interceptor to short-circuit (skip tail) | DONE | `chain allows interceptor to short-circuit` in `test/core/module/interceptor_registry_test.dart` |
| U19 | `InterceptorRegistry.chain` allows interceptor to transform result via `map` | DONE | `chain allows interceptor to transform result` in `test/core/module/interceptor_registry_test.dart` |
| U20 | `InterceptorRegistry.clear` removes all interceptors | DONE | `clear removes all interceptors` in `test/core/module/interceptor_registry_test.dart` |

### Phase 2b: InterceptableUseCase

| ID | Behavior | Status | Test Name & Path |
|----|----------|--------|------------------|
| U21 | `InterceptableUseCase` calls `executeCall` when no interceptors | DONE | `calls executeCall when no interceptors` in `test/core/usecase_interceptor/interceptable_usecase_test.dart` |
| U22 | `InterceptableUseCase` calls `executeCall` when null registry | DONE | `calls executeCall when null registry` in `test/core/usecase_interceptor/interceptable_usecase_test.dart` |
| U23 | `InterceptableUseCase` runs interceptor before `executeCall` | DONE | `runs interceptor before executeCall` in `test/core/usecase_interceptor/interceptable_usecase_test.dart` |
| U24 | `InterceptableUseCase` interceptor can short-circuit (prevent executeCall) | DONE | `interceptor can short-circuit` in `test/core/usecase_interceptor/interceptable_usecase_test.dart` |
| U25 | `InterceptableUseCase` multiple interceptors run in order | DONE | `multiple interceptors run in order` in `test/core/usecase_interceptor/interceptable_usecase_test.dart` |
| U26 | `InterceptableUseCase` interceptor can observe without modifying via `onSuccess` | DONE | `interceptor can observe without modifying` in `test/core/usecase_interceptor/interceptable_usecase_test.dart` |

### Phase 2c: ZuraffaDIContainer Interceptor Integration

| ID | Behavior | Status | Test Name & Path |
|----|----------|--------|------------------|
| U27 | `ZuraffaDIContainer` creates its own `InterceptorRegistry` by default | DONE | `container creates its own registry by default` in `test/core/module/di_container_override_test.dart` |
| U28 | `ZuraffaDIContainer.registerInterceptor` delegates to the registry | DONE | `registerInterceptor delegates to the registry` in `test/core/module/di_container_override_test.dart` |
| U29 | `ZuraffaDIContainer.reset` clears both registrations and interceptors | DONE | `reset clears both registrations and interceptors` in `test/core/module/di_container_override_test.dart` |

### Phase 3: UseCase Contract Codegen

| ID | Behavior | Status | Test Name & Path |
|----|----------|--------|------------------|
| U30 | `UseCaseContractFactory.buildContract` generates abstract contract class extending base class | DONE | `generates abstract contract class extending base class` in `test/core/builder/factories/usecase_contract_factory_test.dart` |
| U31 | `UseCaseContractFactory.buildContract` includes imports from config | DONE | `includes imports from config` in `test/core/builder/factories/usecase_contract_factory_test.dart` |
| U32 | `UseCaseContractFactory.buildImpl` generates concrete implementation class extending contract | DONE | `generates concrete implementation class extending contract` in `test/core/builder/factories/usecase_contract_factory_test.dart` |
| U33 | `UseCaseContractFactory.buildImpl` generates constructor with repository field and optional interceptorRegistry | DONE | `generates constructor with repository field` in `test/core/builder/factories/usecase_contract_factory_test.dart` |
| U34 | `UseCaseContractFactory.buildImpl` generates `executeCall` method when base is `InterceptableUseCase` | DONE | `generates executeCall method when base is InterceptableUseCase` in `test/core/builder/factories/usecase_contract_factory_test.dart` |
| U35 | `UseCaseContractFactory.buildImpl` generates `execute` method when base is `ZuraffaUseCase` | DONE | `generates execute method when base is ZuraffaUseCase` in `test/core/builder/factories/usecase_contract_factory_test.dart` |
| U36 | `UseCaseContractFactory.buildImpl` includes async body and proper return type | DONE | `includes async body and proper return type` in `test/core/builder/factories/usecase_contract_factory_test.dart` |

### Phase 4: CLI Plugin Add

| ID | Behavior | Status | Test Name & Path |
|----|----------|--------|------------------|
| U37 | `PluginCommand.add` adds import for plugin package | DONE | `adds zuraffa_feature_example plugin to main.dart` in `test/commands/plugin_command_add_test.dart` |
| U38 | `PluginCommand.add` adds registration to cascade chain (`..register(PluginClass())`) | DONE | `adds plugin to existing cascade chain` in `test/commands/plugin_command_add_test.dart` |
| U39 | `PluginCommand.add` does not duplicate already imported package | DONE | `does not duplicate already imported package` in `test/commands/plugin_command_add_test.dart` |
| U40 | `PluginCommand.add` derives correct PascalCase plugin class name from package (strips `zuraffa_`, appends `Plugin`) | DONE | Implicit in above tests |

---

## Summary

- **Total behaviors**: 40
- **DONE**: 39 (A1-A6, A8, U1-U36, U37-U40)
- **PENDING**: 1 (A7)

### Blocked Behaviors
- None currently blocked. The only pending item is A7 (example plugin integration test), which requires the `zuraffa_feature_example` package to exist in the repo.

---

## Notes

- The baseline test suite has 1 pre-existing failure in `test/plugins/mcp/mcp_sse_server_test.dart` (timeout) — unrelated to this feature.
- All new tests for this feature pass.
- The `UseCaseContractFactory` now has full unit test coverage (11 tests).
- The `zuraffa_feature_example` package referenced in tests doesn't exist in the repo root (may be in a different location or not committed).