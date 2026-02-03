# Result Type & Error Handling

Zuraffa uses a functional programming-inspired `Result<T, F>` type for type-safe error handling. This approach eliminates exceptions as control flow and makes error handling explicit and exhaustive.

## Why Result Type?

### Problems with Exceptions

```dart
// Traditional exception-based code
Future<Product> getProduct(String id) async {
  try {
    return await api.getProduct(id);
  } on NotFoundException {
    throw Exception('Product not found');
  } on NetworkException {
    throw Exception('Network error');
  } on ServerException catch (e) {
    throw Exception('Server error: ${e.statusCode}');
  }
  // What about other exceptions? Easy to miss!
}

// Caller has no idea what can go wrong
final product = await getProduct('123'); // Might throw anything!
```

### Result Type Solution

```dart
// Result-based code
Future<Result<Product, AppFailure>> getProduct(String id) async {
  try {
    final product = await api.getProduct(id);
    return Result.success(product);
  } on NotFoundException {
    return Result.failure(NotFoundFailure(message: 'Product not found'));
  } on NetworkException {
    return Result.failure(NetworkFailure(message: 'Network error'));
  } on ServerException catch (e) {
    return Result.failure(ServerFailure(message: 'Server error: ${e.statusCode}'));
  }
}

// Caller knows exactly what can go wrong
final result = await getProduct('123');
result.fold(
  (product) => handleSuccess(product),
  (failure) => handleFailure(failure),
);
```

### Benefits

1. **Explicit errors**: All possible errors are part of the function signature
2. **Type safety**: Compiler ensures all error cases are handled
3. **No exceptions**: No unexpected crashes from unhandled exceptions
4. **Functional**: Composable error handling with methods like `map`, `flatMap`, `filter`

---

## Result Type

### Definition

```dart
sealed class Result<T, F extends AppFailure> {
  const Result();

  T get success => switch (this) {
    Success(:final value) => value,
    Failure _ => throw StateError('Result is failure, no success value'),
  };

  F get failure => switch (this) {
    Failure(:final error) => error,
    Success _ => throw StateError('Result is success, no failure value'),
  };

  bool get isSuccess => this is Success<T, F>;
  bool get isFailure => this is Failure<T, F>;

  // Pattern matching
  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(F failure) onFailure,
  }) =>
      switch (this) {
        Success(:final value) => onSuccess(value),
        Failure(:final error) => onFailure(error),
      };
}
```

### Success and Failure Classes

```dart
class Success<T, F extends AppFailure> extends Result<T, F> {
  final T value;
  const Success(this.value);
}

class Failure<T, F extends AppFailure> extends Result<T, F> {
  final F error;
  const Failure(this.error);
}
```

### Usage

```dart
// Creating results
final success = Result.success('Hello');
final failure = Result.failure(ServerFailure(message: 'Error'));

// Pattern matching
result.fold(
  onSuccess: (value) => print('Success: $value'),
  onFailure: (error) => print('Error: ${error.message}'),
);

// Switch expressions (Dart 3.0+)
final message = switch (result) {
  Success(:final value) => 'Got: $value',
  Failure(:final error) => 'Error: ${error.message}',
};
```

---

## AppFailure Hierarchy

Zuraffa provides a comprehensive sealed class hierarchy for different error types:

```
AppFailure
├── ServerFailure
├── NetworkFailure
├── ValidationFailure
├── NotFoundFailure
├── UnauthorizedFailure
├── ForbiddenFailure
├── TimeoutFailure
├── CacheFailure
├── ConflictFailure
├── CancellationFailure
├── UnknownFailure
└── PlatformFailure
```

### Server Failures

| Failure Type | When to Use | Example |
|--------------|-------------|---------|
| `ServerFailure` | HTTP 5xx errors | Server crashed, internal error |
| `NetworkFailure` | Connection issues | No internet, timeout |
| `ValidationFailure` | Input validation errors | Invalid email format |
| `NotFoundFailure` | HTTP 404 / resource not found | User doesn't exist |
| `UnauthorizedFailure` | HTTP 401 / authentication required | Invalid token |
| `ForbiddenFailure` | HTTP 403 / access denied | Insufficient permissions |
| `TimeoutFailure` | Request timeout | API took too long |
| `CacheFailure` | Local storage errors | Hive/SQFLite error |
| `ConflictFailure` | HTTP 409 / version conflicts | Concurrent updates |
| `CancellationFailure` | Operation cancelled | User cancelled |
| `UnknownFailure` | Catch-all for unclassified errors | Unexpected error |
| `PlatformFailure` | Platform-specific errors | iOS/Android specific |

### Creating Custom Failures

```dart
// Extend AppFailure for domain-specific errors
class InsufficientStockFailure extends AppFailure {
  final int requestedQuantity;
  final int availableQuantity;

  const InsufficientStockFailure({
    required this.requestedQuantity,
    required this.availableQuantity,
  });

  @override
  String get message => 'Requested $requestedQuantity, only $availableQuantity available';
}

// Use in your UseCase
class ProcessOrderUseCase extends UseCase<Order, OrderRequest> {
  @override
  Future<Order> execute(OrderRequest request, CancelToken? cancelToken) async {
    cancelToken?.throwIfCancelled();

    final inventory = await _inventoryRepository.get(request.productId);
    
    if (inventory.quantity < request.quantity) {
      return Result.failure(InsufficientStockFailure(
        requestedQuantity: request.quantity,
        availableQuantity: inventory.quantity,
      ));
    }

    // Process order...
    return order;
  }
}
```

---

## Error Handling Patterns

### 1. Repository Layer

Repositories should return `Result<T, AppFailure>`:

```dart
abstract class ProductRepository {
  Future<Result<Product, AppFailure>> get(String id);
  Future<Result<List<Product>, AppFailure>> getList();
}

class DataProductRepository implements ProductRepository {
  @override
  Future<Result<Product, AppFailure>> get(String id) async {
    try {
      final response = await _api.getProduct(id);
      return Result.success(Product.fromJson(response));
    } on ApiException catch (e) {
      return Result.failure(_mapApiException(e));
    } catch (e, stackTrace) {
      // Log error
      logError(e, stackTrace);
      return Result.failure(UnknownFailure(message: e.toString()));
    }
  }

  AppFailure _mapApiException(ApiException e) {
    return switch (e.statusCode) {
      401 => UnauthorizedFailure(message: e.message),
      403 => ForbiddenFailure(message: e.message),
      404 => NotFoundFailure(message: e.message),
      409 => ConflictFailure(message: e.message),
      422 => ValidationFailure(message: e.message),
      >= 500 => ServerFailure(message: e.message),
      _ => UnknownFailure(message: e.message),
    };
  }
}
```

### 2. UseCase Layer

UseCases handle errors from repositories and may add their own:

```dart
class GetProductUseCase extends UseCase<Product, String> {
  final ProductRepository _repository;

  GetProductUseCase(this._repository);

  @override
  Future<Product> execute(String id, CancelToken? cancelToken) async {
    cancelToken?.throwIfCancelled();

    final result = await _repository.get(id);

    return result.fold(
      (product) => product,
      (failure) => throw failure, // Let caller handle
    );
  }
}
```

### 3. Presentation Layer

Handle errors in the UI:

```dart
class ProductController extends Controller with StatefulController<ProductState> {
  final ProductPresenter _presenter;

  ProductController(this._presenter) : super();

  @override
  ProductState createInitialState() => const ProductState();

  Future<void> loadProduct(String id) async {
    updateState(viewState.copyWith(isLoading: true));

    final result = await _presenter.getProduct(id);

    result.fold(
      (product) => updateState(viewState.copyWith(
        isLoading: false,
        product: product,
      )),
      (failure) => updateState(viewState.copyWith(
        isLoading: false,
        error: failure,
      )),
    );
  }
}
```

---

## Functional Error Handling

### Map Operations

Transform success values:

```dart
final result = await getProductUseCase('123');

final withDiscount = result.map((product) => product.copyWith(
  price: product.price * 0.9, // 10% discount
));

// Only applies transformation if success
final transformed = switch (withDiscount) {
  Success(:final value) => 'Discounted: ${value.name} - \$${value.price}',
  Failure(:final error) => 'Error: ${error.message}',
};
```

### FlatMap Operations

Chain operations that may fail:

```dart
Future<Result<Order, AppFailure>> createOrderFromCart(String userId) async {
  // Get cart
  final cartResult = await getCartUseCase(userId);
  
  // Process if successful
  return cartResult.flatMap((cart) async {
    // Validate cart
    if (cart.items.isEmpty) {
      return Result.failure(ValidationFailure(message: 'Cart is empty'));
    }

    // Create order
    final order = Order.fromCart(cart);
    return await createOrderUseCase(order);
  });
}
```

### Filter Operations

Validate success values:

```dart
final result = await getProductUseCase('123');

final validResult = result.filter(
  (product) => product.isActive,
  onFalse: () => ValidationFailure(message: 'Product is not active'),
);

// Returns original success if predicate is true, otherwise new failure
```

---

## Cancellation Handling

All operations support cooperative cancellation:

```dart
class GetProductUseCase extends UseCase<Product, String> {
  @override
  Future<Product> execute(String id, CancelToken? cancelToken) async {
    // Check cancellation before expensive operations
    cancelToken?.throwIfCancelled();

    final product = await _repository.get(id);

    // Check again after operation
    cancelToken?.throwIfCancelled();

    return product;
  }
}

// Usage
final cancelToken = CancelToken();

// Start operation
final future = getProductUseCase('123', cancelToken: cancelToken);

// Cancel later
cancelToken.cancel('User navigated away');

// Will throw CancellationFailure
try {
  final result = await future;
} on CancellationFailure {
  // Handle cancellation
  print('Operation was cancelled');
}
```

---

## Error Logging

Zuraffa provides built-in error logging:

```dart
// Enable logging
Zuraffa.enableLogging();

// Errors are automatically logged
class GetProductUseCase extends UseCase<Product, String> {
  @override
  Future<Product> execute(String id, CancelToken? cancelToken) async {
    cancelToken?.throwIfCancelled();

    final result = await _repository.get(id);

    // Result is automatically logged if it's a failure
    return result.when(
      success: (product) => product,
      failure: (failure) {
        // Error is logged automatically
        throw failure;
      },
    );
  }
}
```

---

## Testing Error Cases

Generated tests include error scenarios:

```dart
// Generated test includes error handling
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
```

---

## Best Practices

### 1. Use Domain-Specific Failures

```dart
// Good: Domain-specific error
class InsufficientFundsFailure extends AppFailure {
  final double balance;
  final double amount;

  const InsufficientFundsFailure(this.balance, this.amount);

  @override
  String get message => 'Balance: \$${balance}, Amount: \$${amount}';
}

// Bad: Generic error
const ValidationFailure(message: 'Not enough money');
```

### 2. Handle All Cases Explicitly

```dart
// Good: Explicit handling
result.fold(
  onSuccess: (product) => showProduct(product),
  onFailure: (failure) => showError(failure),
);

// Bad: Partial handling
if (result.isSuccess) {
  showProduct(result.success);
} // Forgot to handle failure case!
```

### 3. Chain Operations Safely

```dart
// Good: Safe chaining
final result = await getUserUseCase(userId)
    .then((userResult) => userResult.flatMap((user) => 
      getProfileUseCase(user.profileId)));

// Bad: Risk of exception
final user = (await getUserUseCase(userId)).success; // May throw!
final profile = (await getProfileUseCase(user.profileId)).success; // May throw!
```

### 4. Preserve Error Context

```dart
// Good: Preserve original error
Future<Result<Data, AppFailure>> processWithErrorHandling() async {
  final result = await repository.getData();
  
  return result.mapError((failure) => 
    failure is NetworkFailure 
      ? failure 
      : UnknownFailure(cause: failure, message: 'Processing failed')
  );
}

// Bad: Lose error context
Future<Result<Data, AppFailure>> processWithGenericError() async {
  try {
    return await repository.getData();
  } catch (_) {
    return Result.failure(UnknownFailure(message: 'Something went wrong'));
  }
}
```

### 5. Use Pattern Matching

```dart
// Good: Exhaustive pattern matching
final message = switch (result) {
  Success(:final value) when value.isValid => 'Valid: $value',
  Success(:final value) => 'Invalid: $value',
  Failure(:final error) when error is NetworkFailure => 'Network issue',
  Failure(:final error) when error is ServerFailure => 'Server issue',
  Failure(:final error) => 'Other error: ${error.message}',
};

// Good: Fold for simple cases
result.fold(
  onSuccess: (data) => handleSuccess(data),
  onFailure: (error) => handleError(error),
);
```

---

## Migration from Exceptions

### Before (Exception-based)

```dart
// Repository
Future<Product> get(String id) async {
  final response = await api.get('/products/$id');
  if (response.statusCode == 404) throw NotFoundException();
  return Product.fromJson(response.body);
}

// UseCase
Future<Product> execute(String id) async {
  try {
    return await repository.get(id);
  } on NotFoundException {
    // Handle specific error
    throw CustomException('Product not found');
  }
}

// UI
try {
  final product = await usecase(id);
  showProduct(product);
} on CustomException catch (e) {
  showError(e.message);
} catch (e) {
  showError('Unknown error');
}
```

### After (Result-based)

```dart
// Repository
Future<Result<Product, AppFailure>> get(String id) async {
  final response = await api.get('/products/$id');
  if (response.statusCode == 404) {
    return Result.failure(NotFoundFailure(message: 'Product not found'));
  }
  return Result.success(Product.fromJson(response.body));
}

// UseCase
Future<Result<Product, AppFailure>> execute(String id) async {
  final result = await repository.get(id);
  
  return result.mapError((failure) => 
    failure is NotFoundFailure 
      ? NotFoundFailure(message: 'Product not found') 
      : failure
  );
}

// UI
final result = await usecase(id);
result.fold(
  onSuccess: (product) => showProduct(product),
  onFailure: (error) => showError(error.message),
);
```

---

## Next Steps

- [UseCase Types](./usecases) - Deep dive into each UseCase type and patterns
- [Architecture Overview](./overview) - Clean Architecture patterns
- [CLI Generation](../cli/commands) - Generate error handling automatically