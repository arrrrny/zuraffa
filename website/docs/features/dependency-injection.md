# Dependency Injection

Zuraffa can automatically generate dependency injection (DI) setup files for the `get_it` package. This eliminates the boilerplate of manually registering datasources and repositories.

## Overview

When you use the `--di` flag, Zuraffa generates:

1. **DataSource DI files** - Registration for remote/local/mock datasources
2. **Repository DI files** - Registration for repositories with datasource injection
3. **Index files** - Auto-generated via directory scanning
4. **Main DI file** - Single `setupDependencies()` function

**Note:** UseCases, Presenters, and Controllers are **not** registered in DI. They are handled by Zuraffa's built-in mechanisms and instantiated directly in views.

## Quick Start

Add `--di` to your generation command:

```bash
zfa generate Product \
  --methods=get,getList,create,update,delete \
  --repository \
  --data \
  --di
```

This generates DI files in `lib/src/di/`:

```
lib/src/di/
├── index.dart                                    # Main entry with setupDependencies()
├── datasources/
│   ├── index.dart                                # Auto-generated
│   └── product_remote_data_source_di.dart
└── repositories/
    ├── index.dart                                # Auto-generated
    └── product_repository_di.dart
```

## Setup

### 1. Add get_it

```yaml
dependencies:
  zuraffa: ^1.17.0
  get_it: ^7.0.0
```

### 2. Initialize DI

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'src/di/index.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Setup all DI
  setupDependencies(GetIt.instance);
  
  runApp(const MyApp());
}
```

## Generated DI Files

### Main DI File

```dart
// lib/src/di/index.dart
export 'datasources/index.dart';
export 'repositories/index.dart';

import 'package:get_it/get_it.dart';
import 'datasources/index.dart';
import 'repositories/index.dart';

void setupDependencies(GetIt getIt) {
  registerAllDataSources(getIt);
  registerAllRepositories(getIt);
}
```

### DataSource DI

```dart
// lib/src/di/datasources/product_remote_data_source_di.dart
import 'package:get_it/get_it.dart';
import '../../data/data_sources/product/product_data_source.dart';
import '../../data/data_sources/product/product_remote_data_source.dart';

void registerProductRemoteDataSource(GetIt getIt) {
  getIt.registerLazySingleton<ProductDataSource>(
    () => ProductRemoteDataSource(),
    instanceName: 'productRemote',
  );
}
```

### Repository DI

```dart
// lib/src/di/repositories/product_repository_di.dart
import 'package:get_it/get_it.dart';
import '../../domain/repositories/product_repository.dart';
import '../../data/repositories/data_product_repository.dart';
import '../../data/data_sources/product/product_data_source.dart';

void registerProductRepository(GetIt getIt) {
  getIt.registerLazySingleton<ProductRepository>(
    () => DataProductRepository(
      getIt<ProductDataSource>(instanceName: 'productRemote'),
    ),
  );
}
```

## With Caching

When using `--cache` with `--di`, both remote and local datasources are registered:

```bash
zfa generate Product \
  --methods=get,getList \
  --repository \
  --data \
  --cache \
  --cache-policy=ttl \
  --ttl=30 \
  --di
```

Generated DI:

```dart
// Datasource DI
void registerProductRemoteDataSource(GetIt getIt) {
  getIt.registerLazySingleton<ProductDataSource>(
    () => ProductRemoteDataSource(),
    instanceName: 'productRemote',
  );
}

void registerProductLocalDataSource(GetIt getIt) {
  final box = Hive.box<Product>('products');
  getIt.registerLazySingleton<ProductDataSource>(
    () => ProductLocalDataSource(box),
    instanceName: 'productLocal',
  );
}

// Repository DI
void registerProductRepository(GetIt getIt) {
  getIt.registerLazySingleton<ProductRepository>(
    () => DataProductRepository(
      getIt<ProductDataSource>(instanceName: 'productRemote'),
      localDataSource: getIt<ProductDataSource>(instanceName: 'productLocal'),
      cachePolicy: createTtl30MinutesCachePolicy(),
    ),
  );
}
```

**Complete setup with caching:**

```dart
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:get_it/get_it.dart';
import 'src/cache/index.dart';
import 'src/di/index.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Hive.initFlutter();
  await initAllCaches();  // Registers adapters + opens boxes
  
  setupDependencies(GetIt.instance);
  
  runApp(MyApp());
}
```

## With Mock Data

Use `--use-mock` to register mock datasources for development:

```bash
zfa generate Product \
  --methods=get,getList \
  --repository \
  --data \
  --mock \
  --di \
  --use-mock
```

Generated DI uses mock datasource:

```dart
void registerProductRepository(GetIt getIt) {
  getIt.registerLazySingleton<ProductRepository>(
    () => DataProductRepository(
      getIt<ProductDataSource>(instanceName: 'productMock'),
    ),
  );
}
```

## Multiple Entities

DI files are organized by component type:

```
lib/src/di/
├── index.dart
├── datasources/
│   ├── index.dart
│   ├── product_remote_data_source_di.dart
│   ├── category_remote_data_source_di.dart
│   └── order_remote_data_source_di.dart
└── repositories/
    ├── index.dart
    ├── product_repository_di.dart
    ├── category_repository_di.dart
    └── order_repository_di.dart
```

Index files are auto-regenerated on each generation:

```dart
// datasources/index.dart
export 'product_remote_data_source_di.dart';
export 'category_remote_data_source_di.dart';
export 'order_remote_data_source_di.dart';

import 'package:get_it/get_it.dart';
import 'product_remote_data_source_di.dart';
import 'category_remote_data_source_di.dart';
import 'order_remote_data_source_di.dart';

void registerAllDataSources(GetIt getIt) {
  registerProductRemoteDataSource(getIt);
  registerCategoryRemoteDataSource(getIt);
  registerOrderRemoteDataSource(getIt);
}
```

## Using Injected Dependencies

### In Views

Repositories are injected, but Presenters and Controllers are instantiated directly:

```dart
class ProductView extends CleanView {
  final ProductRepository productRepository;

  const ProductView({super.key, required this.productRepository});

  @override
  State<ProductView> createState() => _ProductViewState(
    ProductController(
      ProductPresenter(productRepository: productRepository),
    ),
  );
}

// Usage
final repository = GetIt.instance<ProductRepository>();
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => ProductView(productRepository: repository),
  ),
);
```

### In Custom UseCases

UseCases are not registered in DI. Instantiate them directly with repositories:

```dart
class ProcessCheckoutUseCase extends UseCase<Order, CheckoutRequest> {
  final CartRepository _cartRepository;
  final OrderRepository _orderRepository;
  final PaymentRepository _paymentRepository;

  ProcessCheckoutUseCase(
    this._cartRepository,
    this._orderRepository,
    this._paymentRepository,
  );
  
  // ...
}

// In Presenter
class CheckoutPresenter {
  final CartRepository cartRepository;
  final OrderRepository orderRepository;
  final PaymentRepository paymentRepository;
  
  late final ProcessCheckoutUseCase _processCheckout;
  
  CheckoutPresenter({
    required this.cartRepository,
    required this.orderRepository,
    required this.paymentRepository,
  }) {
    _processCheckout = ProcessCheckoutUseCase(
      cartRepository,
      orderRepository,
      paymentRepository,
    );
  }
}
```

## Best Practices

### 1. Register by Interface

Always register by interface, resolve by interface:

```dart
// Good
getIt.registerLazySingleton<ProductRepository>(
  () => DataProductRepository(...),
);

// Usage
final repo = getIt<ProductRepository>(); // ✓
```

### 2. Use Appropriate Lifetimes

| Component | Lifetime | Reason |
|-----------|----------|--------|
| DataSource | `singleton` | Expensive to create, stateless |
| Repository | `singleton` | Coordinates datasources |

### 3. Lazy Registration

Use `registerLazySingleton` for expensive-to-create objects:

```dart
getIt.registerLazySingleton<HttpClient>(
  () => HttpClient()..timeout = Duration(seconds: 30),
);
```

### 4. Environment-Specific DI

Use `--use-mock` for development, regular generation for production:

```bash
# Development
zfa generate Product --methods=get,getList --repository --data --mock --di --use-mock

# Production
zfa generate Product --methods=get,getList --repository --data --di
```

### 5. Testing with DI

Reset and register mocks in tests:

```dart
setUp(() {
  // Reset DI
  GetIt.instance.reset();
  
  // Register mocks
  GetIt.instance.registerLazySingleton<ProductRepository>(
    () => MockProductRepository(),
  );
});
```

## Troubleshooting

### "Object/factory with type X is not registered"

Ensure you're calling `setupDependencies()` before using dependencies:

```dart
void main() {
  setupDependencies(GetIt.instance); // Don't forget this!
  runApp(MyApp());
}
```

### Multiple Implementations

Use named instances (already handled by generated code):

```dart
// Remote datasource
getIt<ProductDataSource>(instanceName: 'productRemote');

// Local datasource
getIt<ProductDataSource>(instanceName: 'productLocal');

// Mock datasource
getIt<ProductDataSource>(instanceName: 'productMock');
```

---

## Next Steps

- [CLI Commands](../cli/commands) - All generation options
- [Caching](./caching) - DI with caching setup
- [Testing](../guides/testing) - Testing with DI
