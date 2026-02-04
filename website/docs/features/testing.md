# Testing

Zuraffa provides comprehensive testing capabilities with automated test generation. The `--test` flag generates complete unit tests for your UseCases with proper mock setup and test scenarios.

## Overview

Testing in Zuraffa follows these principles:

1. **Automated generation**: Tests generated for all UseCases
2. **Proper mocking**: Automatic mock repository generation
3. **Comprehensive scenarios**: Success and failure cases
4. **Clean Architecture**: Test each layer independently

## Basic Test Generation

### 1. Generate with Tests

```bash
zfa generate Product \
  --methods=get,getList,create,update,delete \
  --data \
  --test
```

This generates:
- Test files for each UseCase
- Mock repository setup
- Success and failure test scenarios
- Comprehensive test coverage

### 2. Run Tests

```bash
# Run all tests
flutter test

# Run specific test
flutter test test/domain/usecases/product/get_product_usecase_test.dart

# Run with coverage
flutter test --coverage
```

## Generated Test Structure

### UseCase Test Example

```dart
// test/domain/usecases/product/get_product_usecase_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zuraffa/zuraffa.dart';
import '../../../lib/domain/entities/product/product.dart';
import '../../../lib/domain/repositories/product_repository.dart';
import '../../../lib/domain/usecases/product/get_product_usecase.dart';

class MockProductRepository extends Mock implements ProductRepository {}

void main() {
  late GetProductUseCase usecase;
  late MockProductRepository mockRepository;

  setUp(() {
    mockRepository = MockProductRepository();
    usecase = GetProductUseCase(mockRepository);
  });

  const tId = '1';
  final tProduct = Product(
    id: '1',
    name: 'Test Product',
    description: 'Test Description',
    price: 10.0,
    category: 'Test Category',
    isActive: true,
    createdAt: DateTime.now(),
  );

  test('should get product from repository when call executes', () async {
    // arrange
    when(() => mockRepository.get(tId)).thenAnswer((_) async => tProduct);

    // act
    final result = await usecase.call(tId);

    // assert
    expect(result, Result.success(tProduct));
    verify(() => mockRepository.get(tId)).called(1);
    verifyNoMoreInteractions(mockRepository);
  });

  test('should return server failure when repository throws server error', () async {
    // arrange
    when(() => mockRepository.get(tId)).thenThrow(
      const ServerException(message: 'Server error'),
    );

    // act
    final result = await usecase.call(tId);

    // assert
    expect(result, const Result.failure(ServerFailure(message: 'Server error')));
    verify(() => mockRepository.get(tId)).called(1);
    verifyNoMoreInteractions(mockRepository);
  });
}
```

## Test Scenarios

Zuraffa generates tests for all common scenarios:

### Success Cases
- Happy path execution
- Correct parameter passing
- Expected return values
- Repository method calls

### Failure Cases
- Server errors (HTTP 5xx)
- Network errors
- Validation errors
- Not found errors
- Unauthorized access
- Forbidden access
- Timeout errors
- Cache errors
- Conflict errors
- Unknown errors

## ZFA  Patterns and Testing

### Entity-Based Pattern

Comprehensive testing for CRUD operations:

```bash
zfa generate Product \
  --methods=get,getList,create,update,delete,watch,watchList \
  --data \
  --test
```

### Single Repository Pattern

Testing for custom UseCases:

```bash
zfa generate ProcessCheckout \
  --domain=checkout \
  --repo=Checkout \
  --params=CheckoutRequest \
  --returns=OrderConfirmation \
  --test
```

### Orchestrator Pattern

Testing for composed UseCases:

```bash
zfa generate ProcessCheckout \
  --domain=checkout \
  --usecases=ValidateCart,CreateOrder,ProcessPayment \
  --params=CheckoutRequest \
  --returns=Order \
  --test
```

### Polymorphic Pattern

Testing for multiple implementations:

```bash
zfa generate SparkSearch \
  --domain=search \
  --variants=Barcode,Url,Text \
  --params=Spark \
  --returns=Listing \
  --test
```

## Stream UseCase Testing

For `watch` and `watchList` methods, Zuraffa generates stream-specific tests:

```dart
// Stream UseCase test example
test('should emit product when repository stream emits data', () async {
  // arrange
  final streamController = StreamController<Product>();
  when(() => mockRepository.watch(tId)).thenAnswer((_) => streamController.stream);

  // act
  final stream = usecase.call(tId);
  final result = stream.first;

  // emit data
  streamController.add(tProduct);
  streamController.close();

  // assert
  expect(await result, Result.success(tProduct));
});
```

## Background UseCase Testing

For CPU-intensive operations:

```dart
test('should process data in background and return result', () async {
  // arrange
  final params = ImageBatch(images: [rawImage]);

  // act
  final stream = usecase.call(params);
  final result = stream.first;

  // simulate background processing
  // (implementation depends on your background task)

  // assert
  expect(await result, Result.success(expectedProcessedImages));
});
```

## Test Organization

Generated tests follow the same domain organization:

```
test/
├── domain/
│   ├── entities/
│   ├── repositories/
│   └── usecases/
│       ├── product/
│       │   ├── get_product_usecase_test.dart
│       │   ├── get_product_list_usecase_test.dart
│       │   ├── create_product_usecase_test.dart
│       │   └── update_product_usecase_test.dart
│       └── checkout/
│           └── process_checkout_usecase_test.dart
├── data/
│   ├── data_sources/
│   └── repositories/
└── presentation/
    └── pages/
        └── product/
            └── product_controller_test.dart
```

## Advanced Testing Features

### Cancellation Testing

Tests include cancellation scenarios:

```dart
test('should throw cancellation failure when token is cancelled', () async {
  // arrange
  final cancelToken = CancelToken();
  when(() => mockRepository.get(tId)).thenAnswer((_) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return tProduct;
  });

  // act
  final future = usecase.call(tId, cancelToken: cancelToken);
  cancelToken.cancel();
  final result = await future;

  // assert
  expect(result, const Result.failure(CancellationFailure()));
});
```

### Multiple Parameter Testing

For complex parameter types:

```dart
test('should handle all parameter fields correctly', () async {
  // arrange
  final params = UpdateParams<Product>(
    id: '1',
    data: tProduct.copyWith(name: 'Updated Name'),
  );
  when(() => mockRepository.update(params)).thenAnswer((_) async => tProduct);

  // act
  final result = await usecase.call(params);

  // assert
  expect(result, Result.success(tProduct));
  verify(() => mockRepository.update(params)).called(1);
});
```

## Combining with Other Features

### Test + Mock Data

```bash
zfa generate Product \
  --methods=get,getList,create,update,delete \
  --data \
  --mock \
  --test
```

Generates tests using mock data for realistic test scenarios.

### Test + Caching

```bash
zfa generate Product \
  --methods=get,getList \
  --data \
  --cache \
  --test
```

Tests for cached repository behavior.

### Test + VPC

```bash
zfa generate Product \
  --methods=get,getList \
  --data \
  --vpc \
  --test
```

Includes presentation layer tests.

## Testing Best Practices

### 1. Comprehensive Coverage

```bash
# Generate tests for complete feature
zfa generate Product \
  --methods=get,getList,create,update,delete,watch,watchList \
  --data \
  --vpc \
  --state \
  --test
```

### 2. Domain-Specific Testing

```bash
# Test custom business logic
zfa generate ProcessCheckout \
  --domain=checkout \
  --repo=Checkout \
  --params=CheckoutRequest \
  --returns=OrderConfirmation \
  --test
```

### 3. Integration Testing

Combine with mock data for integration tests:

```bash
zfa generate Product \
  --methods=get,getList \
  --data \
  --mock \
  --test
```

## Migration from 1.x

### Before (1.x)
```bash
# Basic test generation
zfa generate Product --test
```

### After (2.0.0)
```bash
# More comprehensive testing with domain organization
zfa generate ProcessCheckout --domain=checkout --repo=Checkout --test

# Orchestrator pattern testing
zfa generate ProcessCheckout --usecases=ValidateCart,CreateOrder --test

# Polymorphic pattern testing
zfa generate SparkSearch --variants=Barcode,Url,Text --test
```

## Troubleshooting

### Mocktail Import Issues

If getting import errors, ensure you have mocktail in your dev dependencies:

```yaml
dev_dependencies:
  mocktail: ^1.0.4
```

### Test Failures

- Check that your entity fields match the test data types
- Ensure repository methods are properly mocked
- Verify parameter types match between UseCase and Repository

### Missing Test Files

If test files aren't generated, ensure:
- You're using the `--test` flag
- The entity file exists at the expected location
- You have proper directory structure

## Running Tests Effectively

### 1. Watch Mode

```bash
# Run tests in watch mode
flutter test --watch
```

### 2. Coverage Reports

```bash
# Generate coverage report
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

### 3. Specific Test Runs

```bash
# Run tests for specific entity
flutter test test/domain/usecases/product/

# Run tests with specific tags
flutter test --tags slow
```

## Next Steps

- [Mock Data](./mock-data) - Use mock data in tests for realistic scenarios
- [Caching](./caching) - Test cached repository behavior
- [CLI Reference](../cli/commands) - Complete testing flag documentation
