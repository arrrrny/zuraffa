# Dependency Injection

Zuraffa can automatically generate dependency injection (DI) setup files for the `get_it` package. This eliminates the boilerplate of manually registering all your generated components.

## Overview

When you use the `--di` flag, Zuraffa generates:

1. **Component DI files** - One file per layer (datasource, repository, usecase, presenter, controller)
2. **Index files** - Auto-generated barrel files via directory scanning
3. **Main DI file** - Imports and calls all component registrations

## Quick Start

Add `--di` to your generation command:

```bash
zfa generate Product \
  --methods=get,getList,create,update,delete \
  --repository \
  --data \
  --vpc \
  --state \
  --di
```

This generates DI files in `lib/src/di/`:

```
lib/src/di/
├── di.dart                          # Main entry point
├── product/
│   ├── product_datasource_di.dart   # DataSource registration
│   ├── product_repository_di.dart   # Repository registration
│   ├── product_usecase_di.dart      # UseCase registration
│   ├── product_presenter_di.dart    # Presenter registration
│   └── product_controller_di.dart   # Controller registration
```

## Setup

### 1. Add get_it

```yaml
dependencies:
  zuraffa: ^1.14.0
  get_it: ^7.0.0
```

### 2. Create get_it Instance

```dart
// lib/src/di/get_it.dart
import 'package:get_it/get_it.dart';

final getIt = GetIt.instance;
```

### 3. Initialize DI

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'src/di/di.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Setup all DI
  setupDI();
  
  runApp(const MyApp());
}
```

## Generated DI Files

### Main DI File

```dart
// lib/src/di/di.dart
import 'get_it.dart';
import 'product/product_datasource_di.dart';
import 'product/product_repository_di.dart';
import 'product/product_usecase_di.dart';
import 'product/product_presenter_di.dart';
import 'product/product_controller_di.dart';

void setupDI() {
  registerProductDataSources();
  registerProductRepositories();
  registerProductUseCases();
  registerProductPresenters();
  registerProductControllers();
}
```

### DataSource DI

```dart
// lib/src/di/product/product_datasource_di.dart
import '../get_it.dart';
import '../../data/data_sources/product/product_data_source.dart';
import '../../data/data_sources/product/product_remote_data_source.dart';

void registerProductDataSources() {
  // Register remote datasource
  getIt.registerLazySingleton<ProductDataSource>(
    () => ProductRemoteDataSource(
      getIt(), // HttpClient or similar
    ),
    instanceName: 'remote',
  );
}
```

### Repository DI

```dart
// lib/src/di/product/product_repository_di.dart
import '../get_it.dart';
import '../../domain/repositories/product_repository.dart';
import '../../data/repositories/data_product_repository.dart';
import '../../data/data_sources/product/product_data_source.dart';

void registerProductRepositories() {
  getIt.registerLazySingleton<ProductRepository>(
    () => DataProductRepository(
      getIt<ProductDataSource>(instanceName: 'remote'),
    ),
  );
}
```

### UseCase DI

```dart
// lib/src/di/product/product_usecase_di.dart
import '../get_it.dart';
import '../../domain/usecases/product/get_product_usecase.dart';
import '../../domain/usecases/product/get_product_list_usecase.dart';
import '../../domain/usecases/product/create_product_usecase.dart';
import '../../domain/usecases/product/update_product_usecase.dart';
import '../../domain/usecases/product/delete_product_usecase.dart';
import '../../domain/repositories/product_repository.dart';

void registerProductUseCases() {
  getIt.registerFactory(() => GetProductUseCase(getIt()));
  getIt.registerFactory(() => GetProductListUseCase(getIt()));
  getIt.registerFactory(() => CreateProductUseCase(getIt()));
  getIt.registerFactory(() => UpdateProductUseCase(getIt()));
  getIt.registerFactory(() => DeleteProductUseCase(getIt()));
}
```

### Presenter DI

```dart
// lib/src/di/product/product_presenter_di.dart
import '../get_it.dart';
import '../../presentation/pages/product/product_presenter.dart';
import '../../domain/repositories/product_repository.dart';

void registerProductPresenters() {
  getIt.registerFactoryParam<ProductPresenter, ProductRepository, void>(
    (repository, _) => ProductPresenter(productRepository: repository),
  );
}
```

### Controller DI

```dart
// lib/src/di/product/product_controller_di.dart
import '../get_it.dart';
import '../../presentation/pages/product/product_controller.dart';
import '../../presentation/pages/product/product_presenter.dart';

void registerProductControllers() {
  getIt.registerFactoryParam<ProductController, ProductPresenter, void>(
    (presenter, _) => ProductController(presenter),
  );
}
```

## With Caching

When using `--cache`, DI includes both remote and local datasources:

```dart
// lib/src/di/product/product_datasource_di.dart
void registerProductDataSources() {
  // Remote datasource
  getIt.registerLazySingleton<ProductDataSource>(
    () => ProductRemoteDataSource(getIt()),
    instanceName: 'remote',
  );
  
  // Local datasource (Hive)
  getIt.registerLazySingleton<ProductDataSource>(
    () => ProductLocalDataSource(getIt()),
    instanceName: 'local',
  );
}

// lib/src/di/product/product_repository_di.dart
void registerProductRepositories() {
  getIt.registerLazySingleton<ProductRepository>(
    () => DataProductRepository(
      getIt<ProductDataSource>(instanceName: 'remote'),
      localDataSource: getIt<ProductDataSource>(instanceName: 'local'),
    ),
  );
}
```

## With Mock Data

Use `--use-mock` to register mock datasources for development:

```bash
zfa generate Product --methods=get,getList --repository --data --di --use-mock
```

Generated DI:

```dart
void registerProductDataSources() {
  // Register mock instead of remote
  getIt.registerLazySingleton<ProductDataSource>(
    () => ProductMockDataSource(),
    instanceName: 'remote',
  );
}
```

## Multiple Entities

DI files are organized by entity, making it easy to manage:

```
lib/src/di/
├── di.dart
├── get_it.dart
├── product/
│   ├── product_datasource_di.dart
│   ├── product_repository_di.dart
│   ├── product_usecase_di.dart
│   ├── product_presenter_di.dart
│   └── product_controller_di.dart
├── category/
│   ├── category_datasource_di.dart
│   ├── category_repository_di.dart
│   ├── category_usecase_di.dart
│   ├── category_presenter_di.dart
│   └── category_controller_di.dart
└── order/
    ├── order_datasource_di.dart
    ├── order_repository_di.dart
    ├── order_usecase_di.dart
    ├── order_presenter_di.dart
    └── order_controller_di.dart
```

Main DI file:

```dart
void setupDI() {
  // Product
  registerProductDataSources();
  registerProductRepositories();
  registerProductUseCases();
  registerProductPresenters();
  registerProductControllers();
  
  // Category
  registerCategoryDataSources();
  registerCategoryRepositories();
  // ...
  
  // Order
  registerOrderDataSources();
  // ...
}
```

## Using Injected Dependencies

### In Views

```dart
class ProductView extends CleanView {
  const ProductView({super.key});

  @override
  State<ProductView> createState() => _ProductViewState(
    ProductController(
      ProductPresenter(
        productRepository: getIt<ProductRepository>(),
      ),
    ),
  );
}
```

Or with factory params:

```dart
class ProductView extends CleanView {
  const ProductView({super.key});

  @override
  State<ProductView> createState() {
    final repository = getIt<ProductRepository>();
    final presenter = getIt<ProductPresenter>(param1: repository);
    final controller = getIt<ProductController>(param1: presenter);
    return _ProductViewState(controller);
  }
}
```

### In Custom UseCases

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

// DI registration
void registerProcessCheckout() {
  getIt.registerFactory(() => ProcessCheckoutUseCase(
    getIt(),
    getIt(),
    getIt(),
  ));
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
| UseCase | `factory` | New instance per operation |
| Presenter | `factory` | New per view instance |
| Controller | `factory` | New per view instance |

### 3. Lazy Registration

Use `registerLazySingleton` for expensive-to-create objects:

```dart
getIt.registerLazySingleton<HttpClient>(
  () => HttpClient()..timeout = Duration(seconds: 30),
);
```

### 4. Environment-Specific DI

Create different DI setups for different environments:

```dart
// lib/src/di/di_development.dart
void setupDevelopmentDI() {
  // Use mock datasources
  getIt.registerLazySingleton<ProductDataSource>(
    () => ProductMockDataSource(),
  );
}

// lib/src/di/di_production.dart
void setupProductionDI() {
  // Use real datasources
  getIt.registerLazySingleton<ProductDataSource>(
    () => ProductRemoteDataSource(getIt()),
  );
}
```

### 5. Testing with DI

Reset and register mocks in tests:

```dart
setUp(() {
  // Reset DI
  getIt.reset();
  
  // Register mocks
  getIt.registerLazySingleton<ProductRepository>(
    () => MockProductRepository(),
  );
});
```

## Troubleshooting

### "Object/factory with type X is not registered"

Ensure you're calling `setupDI()` before using dependencies:

```dart
void main() {
  setupDI(); // Don't forget this!
  runApp(MyApp());
}
```

### Circular Dependencies

If you have circular dependencies, use `registerFactory` instead of `registerSingleton`:

```dart
// Bad - circular dependency
getIt.registerSingleton<A>(A(getIt<B>()));
getIt.registerSingleton<B>(B(getIt<A>()));

// Good - factory breaks the cycle
getIt.registerFactory<A>(() => A(getIt<B>()));
getIt.registerFactory<B>(() => B(getIt<A>()));
```

### Multiple Implementations

Use named instances:

```dart
getIt.registerLazySingleton<ProductDataSource>(
  () => ProductRemoteDataSource(),
  instanceName: 'remote',
);

getIt.registerLazySingleton<ProductDataSource>(
  () => ProductLocalDataSource(),
  instanceName: 'local',
);

// Usage
final remote = getIt<ProductDataSource>(instanceName: 'remote');
```

---

## Next Steps

- [CLI Commands](../cli/commands) - All generation options
- [Caching](./caching) - DI with caching setup
- [Testing](../guides/testing) - Testing with DI
