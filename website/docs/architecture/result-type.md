# Result and Failure Types

**Zuraffa** uses a robust `Result<T, AppFailure>` type to make failures explicit across all layers of your application. By eliminating hidden exceptions, Zuraffa ensures that your code is predictable, type-safe, and AI-friendly.

---

## 🦄 Why Results?

*   **Pattern Matching**: Use Dart's powerful `switch` or `fold` to handle every possible outcome.
*   **Compile-time Safety**: The compiler forces you to acknowledge potential failures before accessing data.
*   **AI-Native Error Handling**: AI agents can reason about your error states more effectively when they are explicitly modeled as types.
*   **Clean UI Logic**: Decouple your presentation layer from the complexities of exception handling.

---

## 🚀 Basic Usage

Every UseCase in Zuraffa returns a `Result`. You can handle the outcome using the `.fold()` method:

```dart
final result = await getProductUseCase(params);

result.fold(
  (product) => showProduct(product), // Success path
  (failure) => showError(failure.message), // Failure path
);
```

---

## 🛡️ Failure Types

Zuraffa provides a hierarchy of sealed `AppFailure` classes covering common scenarios:

| Failure Type | Description |
| :--- | :--- |
| `ServerFailure` | Remote API or server-side errors. |
| `CacheFailure` | Errors related to local storage or Hive. |
| `NetworkFailure` | Connection issues or timeouts. |
| `ValidationFailure` | Input validation or business rule violations. |
| `AuthFailure` | Authentication or authorization errors. |
| `UnknownFailure` | Fallback for unhandled exceptions. |

---

## 🧠 Pattern Matching

For more granular control, use Dart's exhaustive pattern matching:

```dart
final result = await updateProfileUseCase(params);

if (result.isFailure) {
  final message = switch (result.failure) {
    ValidationFailure f => 'Please check your input: ${f.message}',
    AuthFailure() => 'Session expired. Please log in again.',
    _ => 'Something went wrong.',
  };
  showSnackBar(message);
}
```
