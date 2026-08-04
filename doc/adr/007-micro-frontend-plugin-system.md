# ADR-007: Micro-Frontend Plugin System

## Status

Accepted

## Context

As Zuraffa scales, projects need a standardized way to package entire feature
slices (UseCases, DI, DataSources, State, and UI) into standalone, reusable
Dart/Flutter packages that a host app can orchestrate in a plug-and-play manner.

### Requirements

1. Feature packages must depend only on the `zuraffa` package (no direct
coupling between feature packages).
2. The host app must be able to register feature packages at bootstrap and
resolve a merged route table.
3. The existing generated DI code (which takes a raw `GetIt`) must continue
to work without modification.
4. The CLI must support scaffolding new feature packages.

## Decision

### Runtime Contracts (Phase 1)

Add five types to `lib/src/core/module/` inside the existing `zuraffa` package:

- **`ZuraffaDIContainer`** -- wraps `GetIt`, delegates registration and
  resolution, exposes the underlying `GetIt` for generated-code interop.
- **`ZuraffaRouteBuilder`** -- typedef `Widget Function(BuildContext, Object?)`.
- **`ZuraffaPlugin`** -- abstract class with `pluginId`,
  `registerDependencies(ZuraffaDIContainer)`, `routes`, and `onInit`.
- **`ZuraffaEngine`** -- orchestrator with `register()` (chaining),
  `bootstrap()` (two-phase: deps then init), `masterRouteMap` (unmodifiable),
  fail-fast on duplicate IDs.
- **`ZuraffaAppRunner`** -- minimal widget resolving routes from the engine.

### Naming

Per issue owner feedback, the runtime contract is named `ZuraffaPlugin`
(rather than `ZuraffaModule`). The `module` name is retained only for the
CLI preset/command and the generator plugin ID.

### PoC Package (Phase 2)

A standalone `zuraffa_feature_example/` package at the repo root with a
minimal Clean Architecture slice and an `ExampleFeaturePlugin` orchestrator.

### CLI (Phase 3)

- `module` preset in `GenerationPreset`.
- `ModuleGeneratorPlugin` in `lib/src/plugins/module/` generating the
  `<Feature>FeaturePlugin` orchestrator via `code_builder`.
- `zfa module <FeatureName>` command scaffolding a new feature package.

## Consequences

- Feature packages can be developed, tested, and shipped independently.
- The host app only depends on `zuraffa` + the feature packages it needs.
- No circular dependencies between feature packages.
- `go_router` integration is deferred to a follow-up issue.
- The existing `ZuraffaPlugin` interface (code generation plugin) and the
  new `ZuraffaPlugin` (micro-frontend runtime contract) share the same name
  but live in different files and serve different purposes. The barrel file
  exports both.
