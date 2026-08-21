# Tasks: Plugin System & UseCase Abstraction Layer

## Phase 1: DI Override

- [x] Add `bool override = false` to `registerLazySingleton`
- [x] Add `bool override = false` to `registerFactory`
- [x] Add `bool override = false` to `registerSingleton`
- [x] Add `bool override = false` to `registerInstance`
- [x] Fail-fast with `StateError` when `override: false` and type registered
- [x] Tests for all four registration methods + override

## Phase 2: Interceptor Pipeline

- [x] Create `InterceptorFunction<In, Out>` typedef
- [x] Create `InterceptorEntry<In, Out>` class
- [x] Create `InterceptorRegistry` with `register`, `entriesFor`, `chain`, `clear`
- [x] Create `InterceptableUseCase<In, Out>` base class
- [x] Create barrel export `usecase_interceptor_contract.dart`
- [x] Add `registerInterceptor` and `interceptorRegistry` to `ZuraffaDIContainer`
- [x] Add facade methods to `Zuraffa` static class
- [x] Export from `contracts.dart`
- [x] Tests for registry chaining, short-circuit, transform
- [x] Tests for InterceptableUseCase integration

## Phase 3: UseCase Contract Codegen

- [x] Create `UseCaseContractSpecConfig`
- [x] Create `UseCaseContractFactory.buildContract()`
- [x] Create `UseCaseContractFactory.buildImpl()` with InterceptableUseCase support
- [x] Verify against dart analyze

## Phase 4: CLI

- [x] Add `add` case to `PluginCommand`
- [x] Import insertion logic
- [x] Class name derivation (strip `zuraffa_`, PascalCase, append `Plugin`)
- [x] Registration insertion (cascade chain or before bootstrap)
- [x] Tests for name derivation

## Phase 5: Reference Example

- [x] Create `GetTodosUseCase` abstract contract
- [x] Create `DefaultGetTodosUseCase` implementation
- [x] Create `loggingInterceptor` example
- [x] Update `ExampleFeaturePlugin` with contract/impl + interceptor

## Phase 6: Documentation

- [x] Create `specs/013-plugin-usecase-abstraction/` with spec, plan, tasks
- [x] Create `specs/013-plugin-usecase-abstraction/contracts/interceptor-api.md`
- [x] Update AGENTS.md speckit pointer
- [x] Update CLAUDE.md with feature 013
