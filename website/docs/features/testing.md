# Testing Strategy

**Zuraffa** treats testing as a first-class citizen. By using the `--test` flag, you can automatically generate comprehensive unit and integration tests for your UseCases, Repositories, and Controllers.

---

## 🦄 Why Automated Testing?

*   **Consistency**: Every feature follows the same testing patterns (Mocktail/Flutter Test).
*   **Safety**: Instantly verify that your refactors haven't broken existing business logic.
*   **Documentation**: Tests serve as live documentation for how your UseCases should behave.
*   **AI-Native Verification**: AI agents can run your generated tests to verify their own code changes before you even see them.

---

## 🚀 Generation

### 1. Feature with Tests
Generate a full feature slice along with its test suite:

```bash
zfa feature Product --methods=get,getList,create --data --test
```

### 2. Granular UseCase Tests
Generate a test for a specific custom UseCase:

```bash
zfa make SearchProducts usecase --domain=search --test
```

---

## 🛠️ What Gets Generated?

### UseCase Unit Tests
Located in `test/domain/usecases/{domain}/`. These tests verify:
- **Success Scenarios**: Correct data mapping and repository calls.
- **Failure Scenarios**: Handling of `ServerFailure`, `CacheFailure`, etc.
- **Stream Behavior**: For `watch` UseCases, it verifies the stream emits the expected results.

### Mock Setup
Zuraffa uses **Mocktail** to generate repository and service mocks:

```dart
class MockProductRepository extends Mock implements ProductRepository {}

void main() {
  late GetProductUseCase usecase;
  late MockProductRepository mockRepository;

  setUp(() {
    mockRepository = MockProductRepository();
    usecase = GetProductUseCase(mockRepository);
  });
  
  // ... tests follow
}
```

---

## 🧠 Smart Test Scenarios

Zuraffa doesn't just generate empty test files. It creates realistic scenarios based on your UseCase type:

*   **Async UseCases**: Tests for `Future` completion and error catching.
*   **Sync UseCases**: Direct assertions on the `Result` without `await`.
*   **Orchestrators**: Verifies that all sub-UseCases are called in the correct order.
*   **Background UseCases**: Handles Isolate-based execution testing.

---

## 📂 Next Steps

*   [**Mock Data**](./mock-data) - Using static mock data in your tests.
*   [**Result Type**](../architecture/result-type) - Understanding the failure types being tested.
*   [**CLI Reference**](../cli/commands) - Master all testing generation flags.
