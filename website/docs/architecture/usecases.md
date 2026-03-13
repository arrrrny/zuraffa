# UseCase Types

**UseCases** are the heart of your application's business logic. In Zuraffa, they act as single-responsibility units that orchestrate repositories and services.

---

## 🦄 UseCase Patterns

Zuraffa provides several base classes to handle different execution flows:

### 1. Standard UseCase (Async)
The default for most operations (e.g., fetching data from an API). Returns a `Future<Result<T, AppFailure>>`.

```bash
zfa generate Product --methods=get,getList
```

### 2. Stream UseCase
Ideal for real-time updates, WebSockets, or database watchers. Returns a `Stream<Result<T, AppFailure>>`.

```bash
zfa generate Product --methods=watch,watchList
```

### 3. Sync UseCase
For operations that complete immediately on the main thread (e.g., data mapping, local validation). Returns a `Result<T, AppFailure>` synchronously.

```bash
zfa generate ValidateEmail --type=sync --params=String --returns=bool --domain=auth
```

### 4. Completable UseCase
For async operations that don't return a value (e.g., logging out, deleting a record). Returns `Future<Result<void, AppFailure>>`.

```bash
zfa generate Product --methods=delete
```

### 5. Background UseCase
Runs CPU-intensive tasks on a separate **Isolate** to keep the UI smooth (e.g., image processing, large JSON parsing).

```bash
zfa generate ProcessImages --type=background --params=List<File> --returns=List<Image> --domain=media
```

### 6. Orchestrator UseCase
Composes multiple atomic UseCases into a single workflow (e.g., a checkout process that validates a cart, creates an order, and processes payment).

```bash
zfa generate ProcessCheckout --domain=checkout --usecases=ValidateCart,CreateOrder,ProcessPayment --params=CheckoutRequest --returns=Order
```

---

## 🚀 Execution

All UseCases are **Callable Classes**. You can execute them by calling the instance directly:

```dart
final getProduct = GetProductUseCase(repository);
final result = await getProduct('id-123'); // Simple and clean
```

---

## 🧠 Why Multiple Types?

By choosing the right UseCase type, you provide clear intent to both your team and your AI agent. Zuraffa's generators automatically wire up the correct boilerplate for each type, ensuring consistency across your entire project.
