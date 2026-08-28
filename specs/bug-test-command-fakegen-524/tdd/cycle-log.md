# TDD Cycle Log — `zfa test` fake generation degrades gracefully

## RED (before fix)

All three acceptance tests failed with `Expected: true, Actual: <false>` on
`expect(result.success, isTrue)`:

```
00:00 +0: TestCommand generates custom test with repository dependency
  ... Expected: true
       Actual: <false>
```

**Root cause (verified by reading the code):** `_requireFakeClassForDependency`
in `lib/src/plugins/test/builders/test_builder_helpers.dart` threw:

```dart
throw StateError('Cannot generate $className: source for $interfaceName was not found.');
```

with the message:
`Cannot generate FakeUserRepository: source for UserRepository was not found.`

`TestCommand.execute` (`lib/src/commands/test_command.dart`, ~lines 134-152)
catches the throw and returns `GeneratorResult(success: false)`. The tests only
write the use case file (`*_usecase.dart`) into a temp workspace, never the
dependency sources (`user_repository.dart`, `orders_service.dart`,
`validate_cart_usecase.dart`, `create_order_usecase.dart`), so `filePath` is
`null` and the helper threw for every scenario. Additionally, the assertions
still expected the pre-#524 `Mock*` names, which the generator no longer emits.

## GREEN (after fix)

1. `_requireFakeClassForDependency` no longer throws; it prints a warning and
   returns a `_placeholderFakeClass(className, interfaceName)` =
   `class Fake{Name} implements {Interface} {}` when the source is missing or
   the interface is undeclared. Generation now succeeds and emits the `Fake*`
   stub the test file expects.
2. Stale `Mock*` assertions in `test/commands/test_command_test.dart` updated to
   `Fake*` (no weakening of `expect(result.success, isTrue)` or meaningful
   content assertions).

**Run output (`dart test test/commands/test_command_test.dart`):**

```
00:00 +0: TestCommand generates custom test with repository dependency
  ⚠️  Generating placeholder FakeUserRepository for UserRepository: source file not found on disk.
00:00 +1: TestCommand generates stream test with service dependency
  ⚠️  Generating placeholder FakeOrderService for OrderService: source file not found on disk.
00:00 +2: TestCommand generates orchestrator test with composed usecases
  ⚠️  Generating placeholder FakeValidateCartUseCase for ValidateCartUseCase: source file not found on disk.
  ⚠️  Generating placeholder FakeCreateOrderUseCase for CreateOrderUseCase: source file not found on disk.
00:00 +3: All tests passed!
```

`dart analyze lib/src/plugins/test lib/src/commands` → `No issues found!`
