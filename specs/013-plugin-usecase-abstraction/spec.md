# Spec: Plugin System & UseCase Abstraction Layer

**Feature**: 013
**Issue**: [#203](https://github.com/arrrrny/zuraffa/issues/203)
**Status**: Implemented
**Branch**: `feat/plugin-usecase-abstraction`

## Summary

A Vendure-inspired plugin mechanism for Zuraffa that enables plugins to extend, intercept, or completely replace core UseCase/Repository behaviors without modifying core source. The architecture operates at the UseCase and Repository abstraction layer via DI overrides and a UseCase interceptor pipeline.

## Goals

1. **IoC via contract definitions** — core feature logic defined via abstract UseCase contracts; UI/state depend only on contracts.
2. **DI override engine** — plugin packages registered with the `ZuraffaEngine` can override previously registered default implementations in the DI container (`override: true`).
3. **Interceptors & event hooks** — a UseCase Interceptor pipeline for observing/augmenting UseCases without replacing them: `di.registerInterceptor<PurchaseUseCase>((request, next) { ... })`.

## Non-Goals

- Modifying the existing Hook system (observer-only, fire-and-forget per ADR 006).
- Creating a separate `zuraffa_core` package (stays within the existing `zuraffa` package).
- Full CLI scaffolding for plugin packages (only `zfa plugin add` wiring).

## Architecture

### DI Override

`ZuraffaDIContainer` registration methods now accept `bool override = false`. When `true`, existing registrations are replaced. When `false` and a registration exists, a `StateError` is thrown.

### Interceptor Pipeline

A new `InterceptorRegistry` (keyed by UseCase input type) chains `InterceptorEntry` instances. `InterceptableUseCase<In, Out>` extends `ZuraffaUseCase` and wraps `call()` with the interceptor chain. The `SignalResult` model means interception wraps the *creation* of the signal, not awaiting it.

### UseCase Contract Codegen

`UseCaseContractFactory` generates abstract contract classes and default implementations, mirroring the repository interface/impl split. Plugins override the DI binding at runtime.

### CLI

`zfa plugin add <package>` wires a plugin package into `main.dart` by adding the import and registration call.

## Acceptance Criteria

- [x] `ZuraffaDIContainer` registration methods support `override` parameter
- [x] `InterceptorRegistry` chains interceptors by type
- [x] `InterceptableUseCase` integrates the pipeline
- [x] `Zuraffa` facade exposes `registerInterceptor` and `clearInterceptors`
- [x] `UseCaseContractFactory` generates contract/impl pairs
- [x] `zfa plugin add <package>` added to `PluginCommand`
- [x] Example plugin demonstrates DI override and interceptor
- [x] Tests for all new features
- [x] Spec documentation in `specs/013/`
