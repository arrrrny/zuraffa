# Implementation Plan: Plugin System & UseCase Abstraction Layer

**Branch**: `feat/plugin-usecase-abstraction` | **Date**: 2026-08-04 | **Spec**: [specs/013-plugin-usecase-abstraction/spec.md](spec.md)

**Input**: Feature specification from `/specs/013-plugin-usecase-abstraction/spec.md`

## Summary

Implement DI override support, a UseCase interceptor pipeline, UseCase contract codegen, and `zfa plugin add` CLI action. The interceptor pipeline is a separate chained system from the observer-only Hook system (ADR 006).

## Technical Context

**Language/Version**: Dart ^3.11.0, Flutter >=3.41.0

**Primary Dependencies**:

- `get_it: ^7.0.0` (existing — DI container backend)
- `code_builder: ^4.10.0` (existing — contract codegen)
- `dart_style: ^2.3.0` (existing — code formatting)
- `logging: ^1.3.0` (existing)

**Testing**: `flutter_test` with direct generator usage. Tests in `test/core/module/` and `test/core/usecase_interceptor/`.

**Target Platform**: All platforms supported by Zuraffa (pure Dart framework code).

## Implementation Details

### 1. DI Override (`ZuraffaDIContainer`)

Add `bool override = false` to `registerLazySingleton`, `registerFactory`, `registerSingleton`, and `registerInstance`. When `override: true`, call `getIt.unregister<T>()` before re-registering. When `false` and already registered, throw `StateError`.

### 2. Interceptor Pipeline

- `InterceptorFunction<In, Out>` typedef: `(In request, SignalResult<Out> Function(In) next) => SignalResult<Out>`
- `InterceptorEntry<In, Out>` wraps a function with a name for debugging.
- `InterceptorRegistry` keyed by `Type` (the input type), with `chain<In, Out>(tail)` that builds the pipeline.
- `InterceptableUseCase<In, Out>` extends `ZuraffaUseCase`, wraps `call()` with the chain.
- Facade methods on `Zuraffa` static class.

### 3. UseCase Contract Codegen

- `UseCaseContractFactory` with `buildContract(config)` and `buildImpl(config)`.
- Config specifies contract class, impl class, base class, repository type, method body.
- Supports both `ZuraffaUseCase` and `InterceptableUseCase` as base classes.

### 4. CLI `zfa plugin add`

- New `add` case in `PluginCommand.execute` switch.
- Adds import after last import line.
- Derives plugin class name from package name (strips `zuraffa_` prefix, PascalCase, appends `Plugin`).
- Inserts `..register(PluginClass())` into the cascade chain or before `bootstrap()`.

### 5. Reference Example

- Updated `ExampleFeaturePlugin` with contract/impl split.
- `GetTodosUseCase` (abstract contract) + `DefaultGetTodosUseCase` (impl).
- `loggingInterceptor` demonstrating observer pattern.

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `lib/src/core/module/di_container.dart` | Modified | Added `override` param, `registerInterceptor`, `interceptorRegistry` |
| `lib/src/core/module/interceptor.dart` | New | `InterceptorFunction`, `InterceptorEntry`, `InterceptorRegistry` |
| `lib/src/core/module/contracts.dart` | Modified | Added export of `interceptor.dart` |
| `lib/src/core/usecase_interceptor/interceptable_usecase.dart` | New | `InterceptableUseCase` base class |
| `lib/src/core/usecase_interceptor/usecase_interceptor_contract.dart` | New | Barrel export |
| `lib/src/core/builder/factories/usecase_contract_factory.dart` | New | Contract/impl codegen |
| `lib/src/commands/plugin_command.dart` | Modified | Added `add` action |
| `lib/zuraffa.dart` | Modified | Added interceptor facade methods |
| `zuraffa_feature_example/lib/src/` | Modified | Updated with contract/impl + interceptor demo |
| `test/core/module/di_container_override_test.dart` | New | 12 tests for override + interceptor |
| `test/core/module/interceptor_registry_test.dart` | New | 8 tests for registry |
| `test/core/usecase_interceptor/interceptable_usecase_test.dart` | New | 5 tests for pipeline |
| `test/src/commands/plugin_command_add_test.dart` | New | 4 tests for CLI |

## Risks

- `SignalResult` interception wraps signal creation, not signal resolution. Interceptors cannot `await` the async result. This is an inherent design constraint of the synchronous-return model.
- The `zfa plugin add` command uses regex-based file manipulation, which is fragile for unusual formatting.
