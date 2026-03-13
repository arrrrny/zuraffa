# Dependency Injection

**Zuraffa** provides an automated, modular dependency injection setup using **GetIt**. By using the `--di` flag, Zuraffa generates and maintains registration files for your repositories, data sources, and services.

---

## 🦄 Architecture

Zuraffa's DI follows a "Lazy Singleton" approach by default, ensuring components are only instantiated when needed. The structure is split into domain-specific registration files to prevent circular dependencies and merge conflicts.

```text
lib/src/di/
├── datasources/
│   ├── product_remote_datasource_di.dart
│   └── product_local_datasource_di.dart
├── repositories/
│   └── product_repository_di.dart
├── index.dart             # Root registration entry point
└── service_locator.dart   # The GetIt instance
```

---

## 🚀 Basic Usage

### 1. Generate with DI
When generating a feature, include the `--di` flag:

```bash
zfa generate Product --data --di
```

### 2. Initialize in main.dart
Import the generated `index.dart` and call `setupDependencies()` before `runApp()`:

```dart
import 'package:get_it/get_it.dart';
import 'src/di/index.dart';

final getIt = GetIt.instance;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Register all Zuraffa dependencies
  await setupDependencies(getIt);

  runApp(MyApp());
}
```

---

## 🧪 Development with Mocks

Zuraffa makes it easy to swap real implementations for mocks during development or testing.

### Swapping at Registration
Use the `--use-mock` flag to register a `MockDataSource` instead of the `RemoteDataSource`:

```bash
zfa generate Product --data --mock --di --use-mock
```

### Manual Swapping
You can also conditionally register dependencies based on your environment:

```dart
Future<void> setupDependencies(GetIt getIt) async {
  if (kDebugMode) {
    await registerProductMockDataSource(getIt);
  } else {
    await registerProductRemoteDataSource(getIt);
  }
  
  await registerProductRepository(getIt);
}
```

---

## 🧠 Smart Registration

Zuraffa's DI generator is "smart"—it understands your architectural choices:

*   **Caching**: If `--cache` is used, the DI registration will automatically wire the `RemoteDataSource`, `LocalDataSource`, and `CachePolicy` into the `CachedRepository`.
*   **Services**: If you use the `--service` pattern, Zuraffa generates a separate registration for the service interface and its implementation.
*   **Custom View Preservation**: Presentation layer components (View, Presenter, Controller) are **not** registered in the global DI container. Instead, they are instantiated within the View's state to ensure proper lifecycle management and cleanup.

---

## 📂 Next Steps

*   [**Caching**](./caching) - Dual datasource caching setup.
*   [**Mock Data**](./mock-data) - Development with mock data.
*   [**CLI Reference**](../cli/commands) - Complete DI flag documentation.
