# Bug: `zfa test` generation throws instead of degrading gracefully (#533 / #534 / #536)

**Issues:** #533, #534, #536

**Symptom:** Three `zfa test` generation scenarios fail with
`expect(result.success, isTrue)` returning `false`:
- custom use case with a repository dependency (`FetchUserUseCase` → `UserRepository`)
- stream use case with a service dependency (`WatchOrdersUseCase` → `OrderService`)
- orchestrator with composed child use cases (`ProcessCheckoutUseCase` → `ValidateCartUseCase` + `CreateOrderUseCase`)

**Root cause:** Commit 5b2655bf (#524, "Remove mocktail; generate native zuraffa
mocks in all tests") replaced mocktail-based `Mock*` generation (which built
`extends Mock implements X` classes without needing the source file) with AST-parsed
native `Fake*` generation. The new helper `_requireFakeClassForDependency` in
`lib/src/plugins/test/builders/test_builder_helpers.dart` **throws a `StateError`**
whenever a dependency's source file (e.g. `*_repository.dart`, `*_service.dart`, a
child `*_usecase.dart`) is not present on disk. `TestCommand.execute` catches that and
returns `GeneratorResult(success: false)`, so the test sees `false`. The sibling
entity builder already degrades gracefully to a `skipped` file; the custom/orchestrator
paths did not.

**Fix:** `_requireFakeClassForDependency` no longer throws. When the dependency source
is missing (or the interface is not declared in it) it emits a graceful placeholder
`Fake{Name} implements {Interface}` stub and prints a warning, so generation succeeds
and produces a usable file. The stale `Mock*` assertions in
`test/commands/test_command_test.dart` were updated to the real `Fake*` output that
#524 deliberately introduced (the success assertion and the meaningful content
assertions are preserved, not weakened).
