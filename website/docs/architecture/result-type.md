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
// With Result type - errors are part of the type
Future<Result<Product, AppFailure>> getProduct(String id) async {
  return await api.getProduct(id);
}

// Caller MUST handle both cases
final result = await getProduct('123');
result.fold(
  (product) => showProduct(product),
  (failure) => showError(failure),
);
```

## Result Type API

```dart
sealed class Result<S, F> {
  // Creation
  const factory Result.success(S value) = Success<S, F>;
  const factory Result.failure(F error) = Failure<S, F>;
  
  // Queries
  bool get isSuccess;
  bool get isFailure;
  
  // Transformation
  T fold<T>(T Function(S) onSuccess, T Function(F) onFailure);
  Result<T, F> map<T>(T Function(S) transform);
  Result<S, T> mapFailure<T>(T Function(F) transform);
  Result<T, F> flatMap<T>(Result<T, F> Function(S) transform);
  
  // Value extraction
  S getOrElse(S Function() defaultValue);
  S? getOrNull();
  S getOrThrow();
  F? getFailureOrNull();
  
  // Side effects
  Result<S, F> onSuccess(void Function(S) action);
  Result<S, F> onFailure(void Function(F) action);
}
```

## Handling Results

### Pattern Matching (Recommended)

```dart
final result = await getProductUseCase('product-123');

switch (result) {
  case Success(:final value):
    displayProduct(value);
  case Failure(:final error):
    displayError(error);
}
```

### Using fold

```dart
final result = await getProductUseCase('product-123');

final message = result.fold(
  (product) => 'Product: ${product.name}',
  (failure) => 'Error: ${failure.message}',
);
```

### Async fold

```dart
final result = await getProductUseCase('product-123');

await result.foldAsync(
  (product) async => await cacheProduct(product),
  (failure) async => await logError(failure),
);
```

### Side Effects

```dart
final result = await getProductUseCase('product-123');

result
  .onSuccess((product) => analytics.track('product_viewed', product.id))
  .onFailure((failure) => logger.error('Failed to load product', failure));
```

## AppFailure Hierarchy

Zuraffa provides a comprehensive sealed class hierarchy for error classification:

```dart
sealed class AppFailure implements Exception {
  final String message;
  final StackTrace? stackTrace;
  final Object? cause;
}
```

### Failure Types

| Failure Type | Use Case | Properties |
|--------------|----------|------------|
| `ServerFailure` | HTTP 5xx errors | `int? statusCode` |
| `NetworkFailure` | No connection, DNS errors | - |
| `ValidationFailure` | Invalid input | `Map<String, List<String>>? fieldErrors` |
| `NotFoundFailure` | HTTP 404, missing resources | `String? resourceId`, `String? resourceType` |
| `UnauthorizedFailure` | HTTP 401, not authenticated | - |
| `ForbiddenFailure` | HTTP 403, no permission | `String? requiredPermission` |
| `TimeoutFailure` | Request timeout | `Duration? timeout` |
| `CacheFailure` | Local storage errors | - |
| `ConflictFailure` | HTTP 409, version conflicts | `String? conflictType` |
| `CancellationFailure` | Operation cancelled | - |
| `StateFailure` | Invalid state | - |
| `PlatformFailure` | Platform-specific errors | - |
| `UnknownFailure` | Unclassified errors | - |

### Creating Failures

```dart
// Using factory constructors
throw ServerFailure('Internal server error', statusCode: 500);
throw NetworkFailure('No internet connection');
throw ValidationFailure('Invalid input', fieldErrors: {
  'email': ['Invalid format'],
  'password': ['Too short'],
});
throw NotFoundFailure('Product not found', resourceId: '123', resourceType: 'Product');

// Using AppFailure factory (auto-classifies)
final failure = AppFailure.from(exception, stackTrace);
```

### Exhaustive Error Handling

```dart
void handleFailure(AppFailure failure) {
  switch (failure) {
    case ServerFailure(:final statusCode):
      if (statusCode == 503) {
        showMaintenanceMode();
      } else {
        showServerError();
      }
      
    case NetworkFailure():
      showOfflineMessage();
      
    case ValidationFailure(:final fieldErrors):
      showFormErrors(fieldErrors);
      
    case NotFoundFailure(:final resourceType):
      showNotFound(resourceType);
      
    case UnauthorizedFailure():
      navigateToLogin();
      
    case ForbiddenFailure(:final requiredPermission):
      showAccessDenied(requiredPermission);
      
    case TimeoutFailure():
      showTimeoutMessage();
      
    case CacheFailure():
      // Silently ignore or show subtle indicator
      break;
      
    case ConflictFailure(:final conflictType):
      showConflictDialog(conflictType);
      
    case CancellationFailure():
      // Usually ignore - user initiated
      break;
      
    case StateFailure():
    case PlatformFailure():
    case UnknownFailure():
      showGenericError();
      logError(failure);
  }
}
```

## Chaining Operations

### map

Transform the success value:

```dart
final result = await getProductUseCase('123');

final nameResult = result.map((product) => product.name);
// Result<String, AppFailure>
```

### flatMap

Chain operations that return Results:

```dart
Future<Result<Order, AppFailure>> placeOrder(String productId) async {
  final productResult = await getProductUseCase(productId);
  
  return productResult.flatMap((product) async {
    return await createOrderUseCase(product);
  });
}
```

### mapFailure

Transform the failure:

```dart
final result = await getProductUseCase('123');

final uiResult = result.mapFailure((failure) => 
  UiError(failure.message, failure is NetworkFailure),
);
```

## Real-World Examples

### Form Submission

```dart
Future<void> submitForm() async {
  final result = await createAccountUseCase(
    CreateAccountRequest(
      email: emailController.text,
      password: passwordController.text,
    ),
  );
  
  result.fold(
    (account) {
      showSuccess('Account created!');
      navigateToHome();
    },
    (failure) => switch (failure) {
      ValidationFailure(:final fieldErrors) => 
        showFormErrors(fieldErrors),
      ConflictFailure() => 
        showError('Email already exists'),
      NetworkFailure() => 
        showError('Please check your connection'),
      _ => 
        showError('Something went wrong'),
    },
  );
}
```

### Retry with Exponential Backoff

```dart
Future<Result<T, AppFailure>> retryWithBackoff<T>(
  Future<Result<T, AppFailure>> Function() operation, {
  int maxAttempts = 3,
}) async {
  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    final result = await operation();
    
    if (result.isSuccess) return result;
    
    // Only retry on network/server errors
    if (result case Failure(error: NetworkFailure() || ServerFailure())) {
      if (attempt < maxAttempts) {
        await Future.delayed(Duration(seconds: attempt * 2));
        continue;
      }
    }
    
    return result;
  }
  
  throw StateError('Unreachable');
}
```

### Caching Strategy

```dart
Future<Result<Product, AppFailure>> getProductWithCache(String id) async {
  // Try cache first
  final cached = await cache.get(id);
  if (cached != null) {
    return Result.success(cached);
  }
  
  // Fetch from network
  final result = await getProductUseCase(id);
  
  // Cache on success
  return result.onSuccess((product) => cache.set(id, product));
}
```

## Testing with Results

### Testing Success

```dart
test('returns product when found', () async {
  when(() => mockRepository.get(any())).thenAnswer(
    (_) async => testProduct,
  );
  
  final result = await getProductUseCase('123');
  
  expect(result.isSuccess, true);
  expect(result.getOrNull(), equals(testProduct));
});
```

### Testing Failure

```dart
test('returns NotFoundFailure when product missing', () async {
  when(() => mockRepository.get(any())).thenThrow(
    NotFoundFailure('Not found'),
  );
  
  final result = await getProductUseCase('123');
  
  expect(result.isFailure, true);
  expect(result.getFailureOrNull(), isA<NotFoundFailure>());
});
```

### Testing with fold

```dart
test('handles all failure types', () async {
  final result = await getProductUseCase('123');
  
  result.fold(
    (product) => fail('Should have failed'),
    (failure) {
      expect(failure, isA<AppFailure>());
      expect(failure.message, isNotEmpty);
    },
  );
});
```

## Best Practices

### 1. Always Handle Both Cases

```dart
// Bad: Ignoring failure
final result = await useCase();
if (result.isSuccess) {
  final value = (result as Success).value; // Don't do this
}

// Good: Explicit handling
final result = await useCase();
result.fold(
  (value) => handleSuccess(value),
  (failure) => handleFailure(failure),
);
```

### 2. Use Pattern Matching for Exhaustiveness

```dart
// Good: Compiler ensures all cases handled
switch (result) {
  case Success(:final value):
    handleSuccess(value);
  case Failure(:final error):
    handleFailure(error);
}

// Also good: fold handles both
result.fold(handleSuccess, handleFailure);
```

### 3. Don't Over-Map

```dart
// Bad: Unnecessary mapping
final result = await useCase();
final mapped = result.map((v) => v).map((v) => v);

// Good: Direct usage
final result = await useCase();
result.fold(...);
```

### 4. Log at Appropriate Levels

```dart
result
  .onSuccess((value) => logger.fine('Operation succeeded: $value'))
  .onFailure((failure) {
    switch (failure) {
      case NetworkFailure():
        logger.warning('Network issue', failure);
      case ServerFailure():
        logger.severe('Server error', failure);
      default:
        logger.info('Operation failed', failure);
    }
  });
```

### 5. Convert Exceptions Early

```dart
// Good: Convert at the boundary
Future<Result<Data, AppFailure>> fetchData() async {
  try {
    final data = await httpClient.get('/data');
    return Result.success(data);
  } on SocketException catch (e) {
    return Result.failure(NetworkFailure('No connection', cause: e));
  } on TimeoutException catch (e) {
    return Result.failure(TimeoutFailure('Request timed out', cause: e));
  } catch (e, st) {
    return Result.failure(AppFailure.from(e, st));
  }
}
```

## Migration from Exceptions

### Before

```dart
class ProductRepository {
  Future<Product> get(String id) async {
    final response = await http.get('/products/$id');
    if (response.statusCode == 404) {
      throw NotFoundException();
    }
    if (response.statusCode >= 500) {
      throw ServerException(response.statusCode);
    }
    return Product.fromJson(response.body);
  }
}
```

### After

```dart
class ProductRepository {
  Future<Result<Product, AppFailure>> get(String id) async {
    try {
      final response = await http.get('/products/$id');
      
      if (response.statusCode == 404) {
        return Result.failure(NotFoundFailure('Product not found'));
      }
      if (response.statusCode >= 500) {
        return Result.failure(
          ServerFailure('Server error', statusCode: response.statusCode),
        );
      }
      
      return Result.success(Product.fromJson(response.body));
    } on SocketException catch (e, st) {
      return Result.failure(NetworkFailure('No connection', cause: e, stackTrace: st));
    }
  }
}
```

---

## Next Steps

- [UseCase Types](./usecases) - How UseCases return Results
- [VPC Pattern](./vpc-pattern) - Handling Results in UI
- [Testing](../guides/testing) - Testing Result-based code