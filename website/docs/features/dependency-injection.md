# Dependency Injection

Zuraffa provides automated dependency injection setup using **get_it**. The `--di` flag generates all necessary registration files for your architecture components.

## Overview

Dependency injection in Zuraffa follows these principles:

1. **Infrastructure only**: DI registration focuses on infrastructure components (repositories, datasources)
2. **Manual UseCase registration**: UseCases are instantiated by Presenters using `registerUseCase()`
3. **Clean separation**: Presentation layer components are instantiated directly in Views

## Generated Files

When using `--di`, Zuraffa generates registration files for each component:

```
lib/src/di/
├── datasources/
│   ├── product_remote_data_source_di.dart
│   └── product_local_data_source_di.dart
├── repositories/
│   └── product_repository_di.dart
└── index.dart
```

## Basic Usage

### 1. Generate with DI

```bash
zfa generate Product \
  --methods=get,getList,create,update,delete \
  --data \
  --di
```

This generates:
- Repository registration
- DataSource registration (both remote and local if using `--cache`)

### 2. Register Dependencies

```dart
// main.dart
import 'package:get_it/get_it.dart';
import 'package:zuraffa/zuraffa.dart';
import 'src/di/index.dart'; // Auto-generated

final getIt = GetIt.instance;

void main() async {
  // Enable Zuraffa logging (optional)
  Zuraffa.enableLogging();

  // Register all dependencies
  await setupDependencies(getIt);

  runApp(MyApp());
}
```

### 3. Use in Presentation Layer

```dart
// In your View
class ProductView extends CleanView {
  const ProductView();

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

## Caching with DI

When using `--cache`, Zuraffa generates dual DataSource registration:

```bash
zfa generate Product \
  --methods=get,getList \
  --data \
  --cache \
  --di
```

This generates:
- Remote DataSource registration
- Local DataSource registration
- Cached Repository registration

### Using Mock DataSources

Use `--use-mock` to register mock datasources instead of remote:

```bash
zfa generate Product \
  --methods=get,getList \
  --data \
  --di \
  --use-mock
```

This registers `ProductMockDataSource` instead of `ProductRemoteDataSource` for development without backend.

## Generated Registration Code

### Repository Registration

```dart
// lib/src/di/repositories/product_repository_di.dart
import 'package:get_it/get_it.dart';
import '../../data/repositories/data_product_repository.dart';
import '../../data/data_sources/product/product_remote_data_source.dart';
import '../../domain/repositories/product_repository.dart';

Future<void> registerProductRepository(GetIt getIt) async {
  getIt.registerLazySingleton<ProductRepository>(() {
    return DataProductRepository(
      getIt<ProductRemoteDataSource>(),
    );
  });
}
```

### DataSource Registration

```dart
// lib/src/di/datasources/product_remote_data_source_di.dart
import 'package:get_it/get_it.dart';
import '../../data/data_sources/product/product_remote_data_source.dart';

Future<void> registerProductRemoteDataSource(GetIt getIt) async {
  getIt.registerLazySingleton<ProductRemoteDataSource>(() {
    return ProductRemoteDataSource();
  });
}
```

### Combined Setup

```dart
// lib/src/di/index.dart
import 'package:get_it/get_it.dart';
import 'repositories/product_repository_di.dart';
import 'datasources/product_remote_data_source_di.dart';

Future<void> setupDependencies(GetIt getIt) async {
  // Register data sources first
  await registerProductRemoteDataSource(getIt);
  
  // Then register repositories
  await registerProductRepository(getIt);
}
```

## ZFA 2.0.0 Patterns and DI

### Entity-Based Pattern

For entity-based generation, DI handles the complete stack:

```bash
zfa generate Product \
  --methods=get,getList,create,update,delete \
  --data \
  --vpc \
  --di
```

### Single Repository Pattern

For custom UseCases with single repository:

```bash
zfa generate ProcessCheckout \
  --domain=checkout \
  --repo=Checkout \
  --params=CheckoutRequest \
  --returns=OrderConfirmation \
  --di
```

This generates only repository registration, as UseCases are handled by Presenters.

### Orchestrator Pattern

For orchestrator UseCases:

```bash
zfa generate ProcessCheckout \
  --domain=checkout \
  --usecases=ValidateCart,CreateOrder,ProcessPayment \
  --params=CheckoutRequest \
  --returns=Order \
  --di
```

This generates registration for the repositories of the composed UseCases.

## Manual Registration

Some components require manual registration:

### UseCases

UseCases are registered by Presenters using `registerUseCase()`:

```dart
class ProductPresenter extends Presenter {
  final ProductRepository productRepository;

  late final GetProductUseCase _getProduct;
  late final GetProductListUseCase _getProductList;

  ProductPresenter({required this.productRepository}) {
    // Use registerUseCase to properly dispose when Presenter is disposed
    _getProduct = registerUseCase(GetProductUseCase(productRepository));
    _getProductList = registerUseCase(GetProductListUseCase(productRepository));
  }
}
```

### Presentation Layer

Presentation layer components are instantiated directly in Views:

```dart
class ProductView extends CleanView {
  const ProductView();

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

## Advanced Configuration

### Conditional Registration

Register different implementations based on environment:

```dart
Future<void> setupDependencies(GetIt getIt) async {
  if (kDebugMode) {
    // Use mock data in debug mode
    await registerProductMockDataSource(getIt);
  } else {
    // Use real API in release mode
    await registerProductRemoteDataSource(getIt);
  }
  
  await registerProductRepository(getIt);
}
```

### Using with `--use-mock`

For development without backend:

```bash
zfa generate Product \
  --methods=get,getList \
  --data \
  --di \
  --mock \
  --use-mock
```

This generates mock datasources and registers them instead of remote ones.

## Best Practices

### 1. Use `--di` with Complete Stacks

```bash
# Good: Complete architecture with DI
zfa generate Product \
  --methods=get,getList,create,update,delete \
  --data \
  --di

# Good: With caching
zfa generate Product \
  --methods=get,getList \
  --data \
  --cache \
  --di
```

### 2. Combine with Mock Data for Development

```bash
# Development setup with mock data
zfa generate Product \
  --methods=get,getList,create,update,delete \
  --data \
  --di \
  --mock \
  --use-mock
```

### 3. Use Domain Organization

```bash
# Register domain-specific dependencies
zfa generate ProcessCheckout \
  --domain=checkout \
  --repo=Checkout \
  --di
```

### 4. Handle Caching Properly

```bash
# Complete caching setup with DI
zfa generate Product \
  --methods=get,getList \
  --data \
  --cache \
  --cache-storage=hive \
  --di
```

## Migration from 1.x

### Before (1.x)
```bash
# Generated DI for all components including UseCases and Presenters
zfa generate Product --di
```

### After (2.0.0)
```bash
# DI only for infrastructure components (repositories, datasources)
zfa generate Product --di

# UseCases handled by Presenters with registerUseCase()
# Presenters/Controllers instantiated in Views
```

## Troubleshooting

### Circular Dependencies

If you encounter circular dependency errors, ensure proper registration order:

1. Register DataSources first
2. Then register Repositories
3. UseCases are handled by Presenters

### Missing Registrations

If getting "Unregistered type" errors, ensure you've called `setupDependencies()` in your main function.

## Next Steps

- [Caching](./caching) - Dual datasource caching setup
- [Mock Data](./mock-data) - Development with mock data
- [CLI Reference](../cli/commands) - Complete DI flag documentation