# Domain Layer

The domain layer contains enterprise business rules — entities, use cases, repositories interfaces, and core types. This is the innermost layer of Clean Architecture with zero Flutter or framework dependencies.

## Core Types

### `Result<S, F>` — `lib/src/core/result.dart`

A sealed class representing success or failure, inspired by functional programming's `Either` type.

```dart
// Creating results
Result.success(user)
Result.failure(NotFoundFailure('User not found'))

// Pattern matching
result.fold(
  (user) => print('Got user: ${user.name}'),
  (failure) => print('Error: ${failure.message}'),
);

// Chaining
result
  .map((user) => user.name)
  .flatMap((name) => validateName(name))
  .getOrElse(() => 'Unknown');
```

Key methods: `fold`, `foldAsync`, `map`, `mapFailure`, `flatMap`, `getOrElse`, `getOrNull`, `tryGet`, `mapError`, `onSuccess`, `onFailure`.

### `AppFailure` — `lib/src/core/failure.dart`

A sealed class hierarchy for all failure types. Enables exhaustive pattern matching.

```dart
sealed class AppFailure implements Exception {
  final String message;
  final StackTrace? stackTrace;
  final Object? cause;
}
```

| Failure Type | When |
|---|---|
| `ServerFailure` | Server returned error (includes `statusCode`) |
| `NetworkFailure` | Network connectivity issues |
| `ValidationFailure` | Input validation failed (includes `fieldErrors`) |
| `NotFoundFailure` | Resource not found |
| `UnauthorizedFailure` | Authentication required |
| `ForbiddenFailure` | Access denied |
| `CacheFailure` | Cache read/write errors |
| `TimeoutFailure` | Request timed out |
| `CancellationFailure` | Operation was cancelled |
| `ConflictFailure` | Resource conflict |
| `UnknownFailure` | Catch-all for unexpected errors |

The `AppFailure.from()` factory intelligently classifies any error by trying each type's factory in order of specificity.

## UseCase Hierarchy

Four base types in `lib/src/domain/`:

```
                    UseCase<T, Params>          # Single-shot async operations
                   /
ZuraffaPlugin ----+---- SyncUseCase<T, Params>   # Synchronous (no async)
                  |
                  +---- StreamUseCase<T, Params>  # Reactive / streaming
                  |
                  +---- BackgroundUseCase<T, Params>  # Isolate-based
```

### `UseCase<T, Params>` — `lib/src/domain/usecase.dart`

The primary type for single-shot async operations. Returns `Future<Result<T, AppFailure>>`.

**Features:**
- Built-in cancellation via `CancelToken`
- Automatic error wrapping (`AppFailure.from`)
- OpenTelemetry tracing (traceId, spanId)
- Hook system (pre-execution, success, failure hooks)
- Callable syntax: `await useCase(params)`

```dart
class GetUserUseCase extends UseCase<User, String> {
  final UserRepository _repository;

  GetUserUseCase(this._repository);

  @override
  Future<User> execute(String userId, CancelToken? cancelToken) async {
    return _repository.getUser(userId);
  }
}

// Usage
final result = await getUserUseCase('user-123');
result.fold(
  (user) => ...,
  (failure) => ...,
);
```

### `SyncUseCase<T, Params>` — `lib/src/domain/sync_usecase.dart`

For synchronous operations (validations, calculations, transformations). Returns `Result<T, AppFailure>` directly (no Future). No hooks, tracing, or cancellation.

```dart
class ValidateEmailUseCase extends SyncUseCase<bool, String> {
  @override
  Result<bool, AppFailure> execute(String email) {
    if (email.contains('@')) return Result.success(true);
    return Result.failure(ValidationFailure('Invalid email'));
  }
}
```

### `StreamUseCase<T, Params>` — `lib/src/domain/stream_usecase.dart`

For reactive operations — real-time updates, pagination, long-running processes. Returns `Stream<Result<T, AppFailure>>`.

```dart
class WatchUserUseCase extends StreamUseCase<User, String> {
  final UserRepository _repository;

  WatchUserUseCase(this._repository);

  @override
  Stream<User> execute(String userId, CancelToken? cancelToken) async* {
    yield* _repository.watchUser(userId);
  }
}

// Listen directly
final subscription = watchUserUseCase('user-123').listen((result) {
  result.fold(
    (user) => print('Updated: ${user.name}'),
    (failure) => print('Error: $failure'),
  );
});
```

### `BackgroundUseCase<T, Params>` — `lib/src/domain/background_usecase.dart`

For CPU-heavy work (image processing, encryption, large computations). Runs on a separate Dart Isolate using `SendPort`/`ReceivePort`. Returns `Stream<Result<T, AppFailure>>`. **Not supported on web.**

## Hook System

UseCases dispatch hooks at key lifecycle points, defined in `lib/src/core/hook.dart`:

```dart
enum HookPhase { pre, success, failure }

class HookContext {
  final String useCaseName;
  final Object? params;
  final Object? result;
  final AppFailure? failure;
  final Map<String, dynamic> metadata;
}
```

Hooks are registered globally via `HookRegistry` (`lib/src/core/hook_registry.dart`) and dispatched during UseCase execution:

```dart
HookRegistry.instance.dispatch(HookContext(
  useCaseName: 'GetUserUseCase',
  params: params,
  // ...
));
```

Use cases automatically:
1. Dispatch `pre` hooks before execution
2. Write result to `hookMetadata` for downstream hooks
3. Dispatch `success` or `failure` hooks after execution
4. Measure execution time (logged via `Loggable` mixin)

## Observers

`Observer<T>` (`lib/src/domain/observer.dart`) is a callback-based interface for consuming `StreamUseCase` emissions:

```dart
class Observer<T> {
  void onData(T data);
  void onError(AppFailure error);
  void onDone();
}
```

A `CallbackObserver<T>` utility provides inline construction. The modern approach uses Dart streams directly (`.listen()` or `await for`).

## Generated UseCase Patterns

When using `zfa make --preset=crud`, generated use cases for each method follow a consistent pattern:

```dart
// GetUseCase
class GetProductUseCase extends UseCase<Product, String> { ... }

// GetListUseCase
class GetProductsUseCase extends UseCase<List<Product>, ListQueryParams> { ... }

// CreateUseCase
class CreateProductUseCase extends UseCase<Product, CreateProductParams> { ... }

// UpdateUseCase
class UpdateProductUseCase extends UseCase<Product, UpdateProductParams> { ... }

// DeleteUseCase
class DeleteProductUseCase extends UseCase<void, String> { ... }
```

Each use case depends on a repository interface (injected via constructor), and the `di` plugin generates the `get_it` registration.

## Source Map

```
lib/src/domain/
├── usecase.dart               # UseCase<T, Params> base class
├── sync_usecase.dart          # SyncUseCase<T, Params> (synchronous)
├── stream_usecase.dart        # StreamUseCase<T, Params> (reactive)
├── background_usecase.dart    # BackgroundUseCase<T, Params> (isolate)
├── observer.dart              # Observer<T> callback interface
├── services/
│   └── cookie_service.dart    # Example domain service (stub)

lib/src/core/
├── result.dart                # Result<S, F> sealed class
├── failure.dart               # AppFailure sealed hierarchy
├── failure_handler.dart       # FailureHandler mixin for error recovery
├── hook.dart                  # HookContext, HookPhase
├── hook_registry.dart         # Global hook dispatch
├── cancel_token.dart          # CancelToken for operations
├── loggable.dart              # Loggable mixin with structured logging
```

## Change Guidance

- **Adding a new failure type:** Create a class extending `AppFailure` in `failure.dart` and add it to the `AppFailure.from()` factory chain.
- **Adding a new UseCase type:** Extend the `UseCase` base class; for streaming behavior use `StreamUseCase`.
- **Modifying UseCase execution:** The `call()` method in `usecase.dart` handles tracing, hook dispatch, and error wrapping — change with care.
- **Related tests:** `test/core/result_test.dart`, `test/core/failure_test.dart`, `test/domain/usecase_hook_test.dart`, `test/domain/stream_usecase_hook_test.dart`
