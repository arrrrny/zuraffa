# Tasks: Plugin System & UseCase Abstraction Layer

## Phase 1: DI Override

- [x] [U1,U2] Add `bool override = false` to `registerLazySingleton`
- [x] [U3,U4] Add `bool override = false` to `registerFactory`
- [x] [U5,U6] Add `bool override = false` to `registerSingleton`
- [x] [U7,U8] Add `bool override = false` to `registerInstance`
- [x] [U9] Fail-fast with `StateError` when `override: false` and type registered
- [x] [U1-U10] Tests for all four registration methods + override

## Phase 2: Interceptor Pipeline

- [x] [U11-U20] Create `InterceptorFunction<In, Out>` typedef
- [x] [U11-U20] Create `InterceptorEntry<In, Out>` class
- [x] [U11-U20] Create `InterceptorRegistry` with `register`, `entriesFor`, `chain`, `clear`
- [x] [U21-U26] Create `InterceptableUseCase<In, Out>` base class
- [x] Create barrel export `usecase_interceptor_contract.dart`
- [x] [U27-U29] Add `registerInterceptor` and `interceptorRegistry` to `ZuraffaDIContainer`
- [x] [A4] Add facade methods to `Zuraffa` static class
- [x] Export from `contracts.dart`
- [x] [U11-U20] Tests for registry chaining, short-circuit, transform
- [x] [U21-U26] Tests for InterceptableUseCase integration

## Phase 3: UseCase Contract Codegen

- [x] Create `UseCaseContractSpecConfig`
- [x] [U30,U31] Create `UseCaseContractFactory.buildContract()`
- [x] [U32-U36] Create `UseCaseContractFactory.buildImpl()` with InterceptableUseCase support
- [x] Verify against dart analyze
- [x] [U30-U36] Write unit tests for UseCaseContractFactory (buildContract, buildImpl for both bases) - 11 tests in test/core/builder/factories/usecase_contract_factory_test.dart

## Phase 4: CLI

- [x] [U37-U40] Add `add` case to `PluginCommand`
- [x] [U37] Import insertion logic
- [x] [U40] Class name derivation (strip `zuraffa_`, PascalCase, append `Plugin`)
- [x] [U38] Registration insertion (cascade chain or before bootstrap)
- [x] [U37-U40] Tests for name derivation and add command

## Phase 5: Reference Example

- [x] [A5] Create `GetTodosUseCase` abstract contract
- [x] [A5] Create `DefaultGetTodosUseCase` implementation
- [x] [A7] Create `loggingInterceptor` example
- [x] [A7] Update `ExampleFeaturePlugin` with contract/impl + interceptor
- [ ] [A7] Write integration test for example plugin demonstrating DI override and interceptor

## Phase 6: Documentation

- [x] Create `specs/013-plugin-usecase-abstraction/` with spec, plan, tasks
- [x] Create `specs/013-plugin-usecase-abstraction/contracts/interceptor-api.md`
- [x] Update AGENTS.md speckit pointer
- [x] Update CLAUDE.md with feature 013
