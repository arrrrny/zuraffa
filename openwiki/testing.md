# Testing

Zuraffa uses a mix of unit tests for core infrastructure, per-plugin generation tests, integration tests for end-to-end workflows, and regression tests to catch breaking changes.

## Test Directory Structure

```
test/
├── core/                 # Core infrastructure tests
│   ├── result_test.dart
│   ├── failure_test.dart
│   ├── cancel_token_test.dart
│   ├── hook_registry_test.dart
│   ├── query_params_test.dart
│   └── ... (otel, failure reporting, config)
├── domain/               # Domain layer tests
│   ├── usecase_hook_test.dart
│   └── stream_usecase_hook_test.dart
├── presentation/         # Presentation layer tests
│   ├── stateful_controller_test.dart
│   └── platform_layout_resolver_test.dart
├── plugins/              # Per-plugin generation tests
│   ├── di/
│   ├── controller/
│   ├── presenter/
│   ├── view/
│   ├── datasource/
│   ├── repository/
│   ├── usecase/
│   ├── service/
│   ├── provider/
│   ├── route/
│   ├── state/
│   ├── sync/
│   ├── mock/
│   ├── shadcn/
│   └── method_append/
├── commands/             # CLI command tests
│   ├── capability_test.dart
│   ├── feature_test.dart
│   ├── make_test.dart
│   ├── generate_test.dart
│   └── test_command_test.dart
├── cli/                  # CLI edge case tests
├── integration/          # End-to-end workflow tests
│   ├── full_entity_workflow_test.dart
│   ├── caching_workflow_test.dart
│   ├── di_parsing_test.dart
│   ├── append_mode_test.dart
│   ├── multi_entity_test.dart
│   ├── orchestration_test.dart
│   ├── performance_test.dart
│   ├── platform_layouts_test.dart
│   ├── polymorphic_mocks_test.dart
│   └── sync_workflow_test.dart
│   └── ... (20+ integration test files)
├── regression/           # Regression tests
│   ├── regression_test_utils.dart
│   └── ... (CLI commands, DI registration, file structure, v5 pipeline)
├── fixtures/             # Baseline outputs for comparison
├── property/             # Property-based tests
├── benchmark/            # Performance benchmarks
├── graphql/              # GraphQL-related tests
└── test_matchers.dart    # Custom Result matchers
```

## Custom Matchers (`test/test_matchers.dart`)

Custom matchers for the `Result<S, F>` type, compatible with `test` and `flutter_test`:

```dart
import 'test_matchers.dart';

test('returns success', () async {
  final result = await myUseCase();
  expect(result, isSuccess());           // matches Result.success
  expect(result, isSuccess<User>());     // typed success matcher
});

test('returns failure', () async {
  final result = await myFailingUseCase();
  expect(result, isFailure());                          // matches any failure
  expect(result, isFailureOfType<NotFoundFailure>());   // specific failure type
  expect(result, failureMessageContains('not found'));  // failure message content
});
```

## Testing Patterns

### Plugin Generation Tests

Each plugin has dedicated tests that verify file generation output:

```dart
// Typical pattern from test/plugins/di/
test('generates repository and datasource registrations', () async {
  final plugin = DiPlugin(outputDir: outputDir, options: ...);
  await plugin.generate(GeneratorConfig(name: 'Product', methods: ['get'], ...));

  // Assert file exists
  expect(
    File('$outputDir/di/datasources/product_datasource_di.dart').existsSync(),
    isTrue,
  );

  // Assert file content
  final content = File(...).readAsStringSync();
  expect(content, contains('ProductRemoteDataSource'));
});
```

### Integration Tests (End-to-End)

Integration tests use the full pipeline: create workspace → write stubs → run generator → assert outputs.

Key files: `test/integration/*_test.dart`

### Regression Tests

The `RegressionWorkspace` utility (`test/regression/regression_test_utils.dart`) provides:

```dart
class RegressionWorkspace {
  static Future<String> createWorkspace(String prefix);
  static Future<void> disposeWorkspace(String workspace);
  static Future<void> writePubspec(String workspace);
  static Future<void> writeEntityStub(String workspace, String name, {String idType});
}
```

Usage pattern:

```dart
test('full pipeline generates expected output', () async {
  final workspace = await RegressionWorkspace.createWorkspace('test_');
  try {
    await RegressionWorkspace.writePubspec(workspace);
    await RegressionWorkspace.writeEntityStub(workspace, 'Product');

    // Run generator
    final plugin = SomePlugin(...);
    await plugin.generate(config);

    // Assert file structure
    expect(Directory('$workspace/lib/src/di').existsSync(), isTrue);
    // Compare against baseline fixture
  } finally {
    await RegressionWorkspace.disposeWorkspace(workspace);
  }
});
```

### Sandboxed File Operations

All generation tests create real files in `Directory.systemTemp.createTemp()` sandboxes, then clean up. This avoids polluting the real project directory and enables parallel test execution.

## Running Tests

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/core/result_test.dart

# Run integration tests only
flutter test test/integration/

# Run plugin tests for a specific plugin
flutter test test/plugins/di/

# Run with coverage
flutter test --coverage
```

## Generated Test Files

When using `zfa make --test`, the `test` plugin generates unit tests:

```bash
zfa make Product --preset=crud --test
```

Generated test structure:

```
test/
└── domain/
    └── usecases/
        ├── get_product_test.dart
        ├── get_products_test.dart
        ├── create_product_test.dart
        ├── update_product_test.dart
        └── delete_product_test.dart
```

Each generated test follows this structure (from `test_plugin.dart`):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
// ... imports ...

void main() {
  late MockProductRepository repository;
  late GetProductUseCase useCase;

  setUp(() {
    repository = MockProductRepository();
    useCase = GetProductUseCase(repository);
  });

  test('returns product when repository succeeds', () async { ... });
  test('returns failure when repository throws', () async { ... });
}
```

## Key Testing Files

| File | Purpose |
|---|---|
| `test/test_matchers.dart` | `isSuccess<T>()`, `isFailure()`, `isFailureOfType<T>()`, `failureMessageContains()` |
| `test/regression/regression_test_utils.dart` | `RegressionWorkspace` for sandboxed integration tests |
| `test/integration/full_entity_workflow_test.dart` | End-to-end entity → make → build test |
| `test/integration/caching_workflow_test.dart` | Cache policy integration test |
| `test/integration/di_parsing_test.dart` | DI dependency detection test |
| `test/core/result_test.dart` | Result type unit tests |
| `test/core/failure_test.dart` | AppFailure hierarchy tests |
| `test/domain/usecase_hook_test.dart` | UseCase hook dispatch tests |
| `test/presentation/stateful_controller_test.dart` | Controller state management tests |

## TDD Cycle

The `zfa tdd` plugin drives spec-driven test-first development end to
end — see [CLI](cli.md#zfa-tdd--tdd-loop-plugin) for the full command
table. The cycle flow:

1. **`zfa tdd plan <feature>`** reads `specs/<feature>/spec.md` and
   emits `tdd/test-list.md` (one behavior per FR/AC) plus
   `tdd/traceability.md` (the behavior ↔ requirement matrix with the
   spec-contract hash). A requirement statement with no behavior row
   fails the coverage gate — no artifacts are written.
2. **`zfa tdd gen <behavior-id>`** generates the failing test + compiling
   subject stub pair and registers both in `tdd/artifacts.json` with
   provenance headers and a `behavior_id` binding.
3. **`zfa tdd verify-red <behavior-id>`** runs the pair's test, proves
   the failure is an honest assertion failure, and appends the red
   evidence entry to `tdd/cycle-log.md`.
4. **`zfa tdd make <behavior-id>`** requires the certified red, plans the
   minimal generation through the zuraffa pipeline, runs the target test
   green, certifies the suite gained no NEW failures, and appends the
   green evidence to the cycle log.
5. **`zfa tdd refactor`** applies recorded refactors only under a green
   suite preflight.
6. **`zfa tdd verify --feature <feature>`** runs the mutation audit and
   writes `tdd/verification.md` from the REAL run. The audit is gated
   twice before it starts: the traceability hash must still match the
   spec (drift = exit 3, re-plan), and the feature's receipted artifacts
   must still match the bytes their generating verbs wrote (digest drift
   = `NOT_ASSESSED`, exit 3, re-run the cycle).

Every step writes machine-readable evidence: each verb emits the
versioned `verdict.v1` envelope as its final stdout line under `--json`
(`zfa tdd verdicts --schema` prints the diff-stable schema), and the
cycle's artifacts are digest-bound as proof.v1 receipts under
`.zfa/receipts/` — run `zfa proof check` to verify that every generated
artifact still proves where it came from. Hand-editing a generated
artifact is therefore always detected: the receipt digest drifts and
both `zfa proof check` (exit 1) and `zfa tdd verify`'s preflight
(NOT_ASSESSED) name it.

## Change Guidance

- **Changing the Result type:** Update `test/core/result_test.dart` and the custom matchers in `test/test_matchers.dart`.
- **Adding a new plugin:** Create a `test/plugins/<plugin_name>/` directory with generation output tests.
- **Adding a new CLI command:** Create tests in `test/commands/` and add integration tests in `test/integration/`.
- **Adding a new cache policy:** Add tests in `test/plugins/cache/`.
- **When modifying core generation:** Run `test/integration/` and `test/regression/` tests to check for regressions.
