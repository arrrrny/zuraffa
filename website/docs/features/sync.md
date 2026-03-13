# SyncUseCase

**SyncUseCase** is a specialized base class in Zuraffa designed for business logic that executes immediately on the main thread without any asynchronous I/O. It provides the same type-safe `Result` wrapping as standard UseCases but without the overhead of `Future` or `Stream`.

---

## 🦄 Why SyncUseCase?

*   **Immediate Execution**: No `await` required. Ideal for UI-blocking validations or transformations.
*   **Zero Async Overhead**: Avoids the performance cost of the event loop for simple logic.
*   **Type Safe**: Returns a `Result<T, AppFailure>`, ensuring consistent error handling across your app.
*   **Pure Logic**: Perfect for keeping your business rules decoupled from Flutter and infrastructure.

---

## 🚀 Basic Usage

### 1. Generate a Sync UseCase
Use the `--type=sync` flag with `zfa make`:

```bash
zfa make ValidateEmail usecase \
  --domain=validation \
  --type=sync \
  --params=String \
  --returns=bool
```

### 2. Implementation
Zuraffa generates a class with a synchronous `execute` method:

```dart
// lib/src/domain/usecases/validation/validate_email_usecase.dart

class ValidateEmailUseCase extends SyncUseCase<bool, String> {
  @override
  bool execute(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }
}
```

### 3. Usage in a Controller
Since it's synchronous, you can call it directly within your state updates:

```dart
void onEmailChanged(String email) {
  final result = _validateEmail(email);
  
  result.fold(
    (isValid) => updateState(viewState.copyWith(isValid: isValid)),
    (failure) => updateState(viewState.copyWith(error: failure.message)),
  );
}
```

---

## 🛠️ Best Use Cases

| Category | Examples |
| :--- | :--- |
| **Validation** | Email/Phone regex, password strength, form field checks. |
| **Transformations** | Mapping API models to UI models, filtering lists, sorting. |
| **Calculations** | Cart totals, tax math, currency formatting, unit conversion. |
| **Business Rules** | Permission checks (if local), feature flag evaluation. |

---

## 🧠 Comparison: UseCase Types

| Type | Return Type | Best For |
| :--- | :--- | :--- |
| **UseCase** | `Future<Result>` | API calls, Database, File I/O. |
| **SyncUseCase** | `Result` | Validations, Math, Transformations. |
| **StreamUseCase** | `Stream<Result>` | WebSockets, Firebase, DB Watchers. |
| **BackgroundUseCase** | `Future<Result>` | Heavy CPU work (Image processing, Big JSON). |

---

## 📂 Next Steps

*   [**UseCase Patterns**](../architecture/usecases) - Learn about Orchestrators and Polymorphic UseCases.
*   [**Result Type**](../architecture/result-type) - Deep dive into type-safe error handling.
*   [**CLI Reference**](../cli/commands) - Master all UseCase generation flags.
