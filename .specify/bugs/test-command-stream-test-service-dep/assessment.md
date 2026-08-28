# Bug Assessment: `zfa test` on a custom use case throws instead of generating/skipping

- **Slug**: test-command-stream-test-service-dep
- **Created**: 2026-08-28
- **Source**: pasted text (failing test report)
- **Verdict**: valid
- **Severity**: medium

## Report (verbatim or summarized)

Failing test (Linux): `test/commands/test_command_test.dart:117`
Test name: "TestCommand generates stream test with service dependency"
Assertion failure:
```
  Expected: true
    Actual: <false>
```
No extra output was captured in the run log. The test exercises the `zfa test` /
TestCommand generator and asserts a generated stream test (with service
dependency) is produced/valid. Read the test at
`test/commands/test_command_test.dart:117` to recover the exact expectation,
then locate the suspected generator code in `lib/src` (the test-command
implementation and the stream-test template/renderer it uses).
Environment: Linux x64, Dart SDK 3.13.1. Reference: macOS suite = 1640 pass /
1 skip / 9 fail; this Linux run = 1681 pass / 1 skip / 8 fail.

## Symptom

Running `zfa test WatchOrders --domain orders --dry-run` on a custom
`StreamUseCase` that depends on a `OrderService` returns
`GeneratorResult(success: false, files: [])` instead of a generated test file.
The test asserts `result.success == true` (line 117) and fails because the
command reported failure. The underlying error captured from the result is:
`Bad state: Cannot generate FakeOrderService: source for OrderService was not found.`

## Reproduction

Reproduced locally on Linux with a temporary harness inside the package:

1. Create a temp workspace with `pubspec.yaml` (`name: zuraffa_test`) and
   `lib/src/domain/usecases/orders/watch_orders_usecase.dart` containing a
   `WatchOrdersUseCase extends StreamUseCase<Order, NoParams>` whose ctor takes
   `final OrderService _service` (no `order_service.dart` is created).
2. Run `TestCommand(TestPlugin(outputDir: ..., options: ...)).execute(
   ['WatchOrders', '--output', outputDir, '--domain', 'orders', '--dry-run'],
   exitOnCompletion: false)`.
3. Observe `result.success == false`, `result.files.isEmpty`, and
   `result.errors == ['Bad state: Cannot generate FakeOrderService: source for OrderService was not found.']`.

The same throw also breaks the two sibling tests in the same file
("generates custom test with repository dependency" at line 75, and
"generates orchestrator test with composed usecases" at line 163), which fail
with the identical `success: false`.

## Suspected Code Paths

- `lib/src/commands/test_command.dart:134-152` — `execute()` wraps
  `plugin.generate(config)` in a try/catch; any thrown exception is converted to
  `GeneratorResult(success: false, errors: [e.toString()])`. This is why the
  assertion sees `false`.
- `lib/src/plugins/test/test_plugin.dart:188-192` — routing: because
  `buildConfigFromUseCase` leaves `methods` empty, `GeneratorConfig.isCustomUseCase`
  is `true`, so generation dispatches to `builder.generateCustom(config)`.
- `lib/src/plugins/test/test_plugin.dart:198-250` — `buildConfigFromUseCase`
  infers `service: 'OrderService'` from the usecase ctor but does NOT set
  `useService` and does NOT create the dependency source; it only records the name.
- `lib/src/plugins/test/builders/test_builder_custom.dart:102-124` — reads
  `config.effectiveService` => `'OrderService'` and
  `config.serviceSnake` => `'order'`, then
  `serviceFile = discovery.findFileSync('order_service.dart')`. The test fixture
  provides no such file, so `serviceFile == null`.
- `lib/src/plugins/test/builders/test_builder_custom.dart:114-123` — calls
  `_requireFakeClassForDependency(className: 'FakeOrderService', ..., filePath: serviceFile?.path)`
  with `filePath == null`.
- `lib/src/plugins/test/builders/test_builder_helpers.dart:112-124` — `_requireFakeClassForDependency`
  throws `StateError('Cannot generate $className: source for $interfaceName was not found.')`
  when `filePath == null`. **This is the throw that aborts generation.**
- `lib/src/plugins/test/builders/test_builder_entity.dart:123-142` — the
  contrast / intended convention: the entity test builder, when a required
  dependency source (native mock files) is missing, prints a warning and returns
  `GeneratedFile(... action: 'skipped')` instead of throwing. The custom/orchestrator
  builders were not aligned to this graceful-skip behavior.
- `lib/src/models/generator_config.dart:260-266` — `isEntityBased`,
  `isCustomUseCase`, `isOrchestrator`, `isPolymorphic` getters that decide which
  builder runs. `methods.isEmpty` => `isCustomUseCase == true`.

## Root Cause Hypothesis

`TestCommand`/`TestPlugin.generate` for custom-use-case and orchestrator use cases
unconditionally requires the dependency's *source file* (`*_repository.dart`,
`*_service.dart`, `*_usecase.dart`) to be discoverable so it can AST-parse method
signatures and emit a `Fake{Dependency}` class. When that source is absent,
`_requireFakeClassForDependency` throws a `StateError`, which `TestCommand.execute`
swallows into `success: false`. The sibling entity test builder already handles
missing sources by returning a `skipped` file, so the custom/orchestrator paths are
inconsistent with that established convention. Confidence: high (reproduced
verbatim; the captured error string matches the source exactly).

Additionally, the tests are **stale relative to the generator**: they assert the
generated content contains `class MockUserRepository` / `class MockOrderService` /
`class MockValidateCartUseCase` / `class MockCreateOrderUseCase`, but the generator
emits `Fake*` classes (the "native zuraffa mocks" strategy introduced in commit
`5b2655bf` "Remove mocktail; generate native zuraffa mocks in all tests (#524)").
The test file `test/commands/test_command_test.dart` was last touched in
`0755b1aa` and was not updated by #524. So even if the throw were removed, the
`contains('class Mock...')` assertions would still fail. There are two independent
defects behind the failing test.

## Proposed Remediation

**Preferred**: Make the custom-use-case and orchestrator test builders degrade
gracefully when a dependency source is absent, mirroring
`test_builder_entity.dart:123-142`:
- When `discovery.findFileSync('${depSnake}_service.dart')` (or `_repository.dart` /
  `_usecase.dart`) is null, either (a) synthesize a minimal `Fake{Dep}` from the
  dependency name only (no method bodies / `UnimplementedError` stubs) so the
  generated test still compiles, or (b) return a `GeneratedFile(..., action: 'skipped')`
  with a warning and let `success` stay `true`. Option (a) keeps the generator
  useful in fixture-light scenarios; option (b) matches the existing entity-builder
  convention and is the smallest change.
- Then update `test/commands/test_command_test.dart` to (1) provide the dependency
  source fixtures (`user_repository.dart`, `order_service.dart`, the composed
  `*_usecase.dart` files) so the analyzer can build real `Fake`s, and (2) change the
  `contains('class Mock...')` expectations to `contains('class Fake...')` to match
  the current native-mock output.

**Alternatives**:
- Only fix the test (provide fixtures + expect `Fake*`) and leave the generator
  throwing: keeps current generator semantics but a real `zfa test` invocation in a
  project missing a dependency source would still report `success: false` with an
  opaque `Bad state:` error — a genuine robustness gap worth closing regardless.
- Have `TestCommand.execute` surface the `StateError` message instead of a bare
  `success: false`, improving diagnosability while the real fix lands.

**Files likely to change**:
- `lib/src/plugins/test/builders/test_builder_custom.dart` (service/repo fake handling)
- `lib/src/plugins/test/builders/test_builder_orchestrator.dart` (composed-use-case fake handling)
- `lib/src/plugins/test/builders/test_builder_helpers.dart` (`_requireFakeClassForDependency` null-source policy)
- `test/commands/test_command_test.dart` (fixtures + `Mock*` -> `Fake*` expectations)

**Tests to add or update**:
- Update the three `TestCommand` tests to supply dependency source fixtures and
  assert `Fake*` naming.
- Add a unit test asserting `zfa test` on a custom use case whose dependency source
  is missing returns `success: true` (skipped file) rather than throwing, to lock in
  parity with the entity builder.

## Risks & Considerations

- Synthesizing `Fake*` classes without source risks emitting non-compiling stubs if
  the dependency has required method signatures the test relies on; the `skipped`
  approach avoids that but means no test file is produced.
- Changing assertion expectations in the test is a test-only change; it does not
  alter shipped generator output.
- The platform delta (macOS 9 fail vs Linux 8 fail) is likely unrelated to this
  specific test, which fails identically on both (no platform-specific code in the
  path); it should be triaged separately.

## Open Questions

- [NEEDS CLARIFICATION: intended behavior] Should `zfa test` on a custom use case
  with a missing dependency source (a) synthesize a best-effort `Fake`, (b) skip
  with a warning, or (c) hard-fail? The entity builder chose (b); the custom/
  orchestrator builders currently do (c).
- [NEEDS CLARIFICATION] Is the `Mock*` vs `Fake*` naming in `test_command_test.dart`
  a known stale test, or is the generator expected to emit mocktail-style `Mock`
  classes (it currently does not)?
