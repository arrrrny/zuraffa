# Result and Failure Types

Zuraffa uses `Result<T, AppFailure>` to make failures explicit. No hidden exceptions, no guessing which errors can happen.

## Why it matters

- You can pattern-match on failures
- UI logic stays clean and predictable
- Tests assert failures without try/catch

## Basic usage

```dart
final result = await getProductUseCase(params);

result.fold(
  (data) => showProduct(data),
  (failure) => showError(failure.message),
);
```

## Failure types

Zuraffa models common failures like validation, network, cancellation, and unknown errors. This keeps error handling consistent across layers.
