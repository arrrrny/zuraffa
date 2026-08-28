# TDD Test List — `zfa test` fake generation degrades gracefully (#533 / #534 / #536)

## Acceptance behaviors (outer)

- **A1** — `zfa test <Name>` for a custom use case with a repository dependency
  succeeds (`result.success == true`) even when the repository source file is
  absent on disk, and emits a `Fake*` stub for the repository.
  - Tests: `test/commands/test_command_test.dart`
    - `generates custom test with repository dependency` (#533)
  - Traced acceptance criterion: generation must not abort when a dependency
    source is missing.

- **A2** — `zfa test <Name>` for a stream use case with a service dependency
  succeeds and emits a `Fake*` stub for the service.
  - Tests: `test/commands/test_command_test.dart`
    - `generates stream test with service dependency` (#534)

- **A3** — `zfa test <Name>` for an orchestrator use case with composed child
  use cases succeeds and emits a `Fake*` stub for each composed use case.
  - Tests: `test/commands/test_command_test.dart`
    - `generates orchestrator test with composed usecases` (#536)

## Inner unit behaviors

- **U1** — `_requireFakeClassForDependency` returns a `Fake{Name} implements
  {Interface}` placeholder (not a throw) when `filePath` is `null`.
- **U2** — `_requireFakeClassForDependency` returns a placeholder when the
  interface is not declared in the source file.

All three acceptance tests are currently green after the fix.
