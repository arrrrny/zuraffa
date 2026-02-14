# Architecture Overview

Zuraffa v3 follows Clean Architecture with a feature-first layout. Each feature gets a consistent slice: domain, data, and presentation. The CLI enforces the structure so teams stay aligned.

## Layers at a glance

- Domain: entities, use cases, repository interfaces
- Data: data sources and repository implementations
- Presentation: view, presenter, controller, state

## What Zuraffa generates

For an entity like `Product`, a single command can generate:

- Domain use cases for the chosen methods
- Repository interface
- Data repository + data source interfaces
- Presentation page with controller, presenter, and state
- DI setup and tests

## Why this works

Zuraffa keeps the domain pure and pushes side effects to the data layer. Presentation depends on domain abstractions, not concrete implementations. That separation makes testing simple and refactoring safe.

Next: [UseCase Types](./usecases)
