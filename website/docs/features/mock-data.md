# Mock Data

**Zuraffa** empowers rapid development and prototyping by providing a powerful, type-safe mock data system. With a single flag, you can generate a complete data layer that works without a real backend, allowing your team to start building UI and business logic immediately.

---

## 🦄 Why Use Mocks?

*   **Offline Development**: Build features even when your API is down or not yet implemented.
*   **Rapid Prototyping**: Test different UI states (loading, empty, error) with predictable data.
*   **Reliable Testing**: Use generated mocks as a foundation for integration and widget tests.
*   **AI-Native Mocking**: AI agents can generate realistic mock data based on your entity definitions and business requirements.

---

## 🚀 Generation

### 1. Basic Mocks
Generate mock data sources for an entity:

```bash
zfa feature Product --data --mock
```

### 2. Auto-Wired Mocks (The CLI Secret)
Use the `--use-mock` flag during generation to automatically wire your **Dependency Injection** to use the mock implementation instead of the remote one:

```bash
zfa feature Product --data --di --mock --use-mock
```

---

## 🛠️ The Mock Stack

When you use the `--mock` flag, Zuraffa generates:

### Mock Data (`product_mock_data.dart`)
A static collection of entity instances. Zuraffa's generator is smart—it uses your entity's field types to generate realistic data (strings for names, doubles for prices, etc.).

### Mock DataSource (`product_mock_datasource.dart`)
A full implementation of your DataSource interface that operates on the static mock data. It supports:
- **CRUD Operations**: Get, List, Create, Update, Delete.
- **Simulated Delays**: Every operation includes a configurable delay to simulate real network conditions.

---

## 🧠 Customizing Mocks

You can easily customize the behavior of your mocks to test edge cases:

```dart
// lib/src/data/datasources/product/product_mock_datasource.dart

@override
Future<Product> get(String id) async {
  await Future.delayed(const Duration(seconds: 1)); // Simulate network
  
  // Test empty state
  if (id == 'empty') throw notFoundFailure('Product not found');
  
  return mockProductData.firstWhere((e) => e.id == id);
}
```

---

## 📂 Next Steps

*   [**Dependency Injection**](./dependency-injection) - Learn how to swap mocks for real APIs.
*   [**CLI Reference**](../cli/commands) - Master all mock generation flags.
