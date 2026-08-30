# Bug Issue: `zfa test` generation throws instead of degrading gracefully

- **Slug**: test-command-fakegen-graceful-degrade
- **Fetched**: 2026-08-30
- **Issues**: #533, #534, #536
- **URLs**:
  - https://github.com/arrrrny/zuraffa/issues/533
  - https://github.com/arrrrny/zuraffa/issues/534
  - https://github.com/arrrrny/zuraffa/issues/536
- **State**: open

## Body

Three `zfa test` generation scenarios fail with `expect(result.success, isTrue)` returning `false`:
- custom use case with a repository dependency (`FetchUserUseCase` → `UserRepository`)
- stream use case with a service dependency (`WatchOrdersUseCase` → `OrderService`)
- orchestrator with composed child use cases (`ProcessCheckoutUseCase` → `ValidateCartUseCase` + `CreateOrderUseCase`)

Root cause: Commit 5b2655bf (#524) replaced mocktail-based `Mock*` generation with AST-parsed native `Fake*` generation. The helper `_requireFakeClassForDependency` throws a `StateError` when a dependency's source file is not present on disk.
