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
│   ├── test/             # Test plugin suite (spec 980): builders,
│   │                     # dispatch, self-certification, receipts,
│   │                     # analyzer parsing, openwiki doc markers
│   └── method_append/
├── commands/             # CLI command tests
│   ├── capability_test.dart
│   ├── feature_test.dart
│   ├── make_test.dart
│   └── generate_test.dart
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

Zuraffa itself is a pure-Dart package — run its suite with `dart test`
(the slow tiers are excluded by default, see `dart_test.yaml`):

```bash
# Run the fast suite
dart test

# Run specific test file
dart test test/core/result_test.dart

# Run integration tests only (slow tier)
dart test --preset=integration

# Run plugin tests for a specific plugin
dart test test/plugins/di/

# Run with coverage
dart test --coverage
```

## Generated Test Files

When using `zfa make --test` (or `zfa test create --name <Entity>`), the `test` plugin generates unit tests:

```bash
zfa make Product --preset=crud --test
```

Generated test structure (one file per use case method, under the entity folder):

```
test/
└── domain/
    └── usecases/
        └── product/
            ├── get_product_usecase_test.dart
            ├── create_product_usecase_test.dart
            ├── update_product_usecase_test.dart
            └── delete_product_usecase_test.dart
```

### Flavor detection (#354)

The generated test imports depend on the target project's flavor, detected
from its `pubspec.yaml`: when the dependencies declare `flutter:
sdk: flutter` the project is a Flutter app, otherwise it is pure Dart.

| Project flavor | Test framework import | Zuraffa core import |
|---|---|---|
| Pure Dart (`zfa setup --dart`) | `package:test/test.dart` | `package:zuraffa/mock.dart` |
| Flutter (`flutter: sdk: flutter`) | `package:flutter_test/flutter_test.dart` | `package:zuraffa/mock.dart` |

A missing or unreadable `pubspec.yaml` conservatively defaults to pure
Dart. The zuraffa core import is `package:zuraffa/mock.dart` for every
flavor — the canonical marker that re-exports the full zuraffa core
surface (Result, the params family, Loggable, FailureHandler, ...) plus
the `zuraffaMockLibrary` constant.

### Native mocks — no mocktail

Generated tests use **native zuraffa mocks**, never a third-party mocking
library: a `Throwing{Entity}DataSource` (every datasource method throws)
plus a wired `Data{Entity}Repository` backed by the generated
`{Entity}MockDataSource` from `zfa make <Entity> --mock`. This lets a
zuraffa app run end-to-end on full mock infrastructure without
`package:mocktail`.

Each generated test follows this structure (real output of
`zfa test create --name Product`, `get` method):

```dart
// GENERATED - DO NOT EDIT
import 'package:my_app/src/data/datasources/product/product_datasource.dart';
import 'package:my_app/src/data/datasources/product/product_mock_datasource.dart';
import 'package:my_app/src/data/mock/product_mock_data.dart';
import 'package:my_app/src/domain/entities/product/product.dart';
import 'package:my_app/src/domain/repositories/data_product_repository.dart';
import 'package:my_app/src/domain/repositories/product_repository.dart';
import 'package:my_app/src/domain/usecases/product/get_product_usecase.dart';
import 'package:test/test.dart';
import 'package:zuraffa/mock.dart';

class ThrowingProductDataSource
    with Loggable, FailureHandler
    implements ProductDataSource {
  @override
  Future<Product> get(QueryParams<Product> params) {
    throw (Exception('ThrowingProductDataSource.get'));
  }

  // ... the other seven canonical datasource methods, all throwing ...
}

void main() {
  late GetProductUseCase useCase;
  late GetProductUseCase throwingUseCase;
  late DataProductRepository repository;
  late DataProductRepository throwingRepository;
  late ProductMockDataSource mockDataSource;
  late ThrowingProductDataSource throwingDataSource;
  setUp(() {
    mockDataSource = ProductMockDataSource();
    throwingDataSource = ThrowingProductDataSource();
    repository = DataProductRepository(mockDataSource);
    throwingRepository = DataProductRepository(throwingDataSource);
    useCase = GetProductUseCase(repository);
    throwingUseCase = GetProductUseCase(throwingRepository);
  });
  group('GetProductUseCase', () {
    final tProduct = ProductMockData.sampleProduct;
    test('should call repository.get and return result', () async {
      final result = await useCase.call(
        QueryParams<Product>(filter: Eq(ProductFields.id, tProduct.id)),
      );
      expect(result.isSuccess, true);
    });
    test('should return Failure when repository throws', () async {
      final result = await throwingUseCase.call(
        QueryParams<Product>(filter: Eq(ProductFields.id, tProduct.id)),
      );
      expect(result.isFailure, true);
    });
  });
}

// END GENERATED
```

### Self-certification (compile verdict)

The test plugin never emits a test it has not proven compiles. After
writing each test file it runs a scoped `dart analyze` on that file and
prints a machine verdict line in the format
`test: entity=<X> tests=<N> compile=pass|fail --> fix: <first error>`:

```
test: entity=Product tests=2 compile=pass
test: entity=Broken tests=2 compile=fail --> fix: <first error>
```

Non-compiling output fails the command with a non-zero exit — never a
silent success. `zfa test create --name <Entity>` and the direct
`zfa test <Entity>` grammar both gate on this verdict; with `--json` the
direct grammar prints a single parseable envelope:

```json
{"entity": "Product", "tests": 2, "compile": "pass", "errors": [], "schema": 1}
```

### Per-method test receipts (`.zfa/receipts/test-<entity>.json`)

Every generation writes a `test.v1` receipt mapping each generated test
to its use case method, its covered acceptance path (`success` /
`failure`), and the SHA-256 digests of the test file and the usecase
source it was generated against:

```json
{
  "schema": "test.v1",
  "entity": "Product",
  "command": "zfa test create --name Product",
  "tests": [
    {
      "name": "should call repository.get and return result",
      "test_path": "test/domain/usecases/product/get_product_usecase_test.dart",
      "method": "get",
      "acceptance_path": "success",
      "test_sha256": "…",
      "usecase_path": "lib/src/domain/usecases/product/get_product_usecase.dart",
      "usecase_sha256": "…"
    },
    {
      "name": "should return Failure when repository throws",
      "test_path": "test/domain/usecases/product/get_product_usecase_test.dart",
      "method": "get",
      "acceptance_path": "failure",
      "test_sha256": "…",
      "usecase_path": "lib/src/domain/usecases/product/get_product_usecase.dart",
      "usecase_sha256": "…"
    }
  ]
}
```

`zfa proof check` re-derives every digest and fails with a
`stale_usecase` finding when the usecase source drifted after the tests
were generated (usecase/test drift) — the signal to regenerate:

```bash
zfa proof check   # flags usecase/test drift, tampered or deleted tests
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

## Change Guidance

- **Changing the Result type:** Update `test/core/result_test.dart` and the custom matchers in `test/test_matchers.dart`.
- **Adding a new plugin:** Create a `test/plugins/<plugin_name>/` directory with generation output tests.
- **Adding a new CLI command:** Create tests in `test/commands/` and add integration tests in `test/integration/`.
- **Adding a new cache policy:** Add tests in `test/plugins/cache/`.
- **When modifying core generation:** Run `test/integration/` and `test/regression/` tests to check for regressions.
