# Architecture Overview

Zuraffa implements **Clean Architecture** principles with a clear separation of concerns across three main layers. This architecture ensures your code is **testable**, **maintainable**, and **scalable**.

## The Three Layers

```
┌─────────────────────────────────────────┐
│           PRESENTATION LAYER            │
│    (View, Controller, Presenter)        │
│         Flutter-dependent               │
└──────────────────┬──────────────────────┘
                   │ depends on
┌──────────────────▼──────────────────────┐
│             DOMAIN LAYER                │
│  (UseCase, Repository Interface, Entity)│
│           Pure Dart - No Flutter        │
└──────────────────┬──────────────────────┘
                   │ depends on (inverted)
┌──────────────────▼──────────────────────┐
│              DATA LAYER                 │
│  (DataRepository, DataSource, Models)   │
│    External dependencies (API, DB)      │
└─────────────────────────────────────────┘
```

### Dependency Rule

**The fundamental rule**: Dependencies always point **inward**. The Domain layer knows nothing about Flutter, databases, or HTTP clients. The Data layer implements interfaces defined by the Domain layer.

## Domain Layer (Pure Dart)

The heart of your application. Contains business logic with **zero external dependencies**.

### Components

| Component | Purpose | Example |
|-----------|---------|---------|
| **Entity** | Business objects with core data | `Product`, `User`, `Order` |
| **Repository Interface** | Contract for data operations | `ProductRepository` |
| **UseCase** | Single business operation | `GetProductUseCase` |

### Key Principles

1. **No Flutter imports** - Domain is pure Dart
2. **No external dependencies** - No HTTP clients, no databases
3. **Repository interfaces only** - Implementation is in Data layer
4. **Result-based errors** - All operations return `Result<T, AppFailure>`

```dart
// Domain layer - Pure Dart, no Flutter
import 'package:zuraffa/zuraffa.dart';

class Product {
  final String id;
  final String name;
  final double price;
  
  const Product({required this.id, required this.name, required this.price});
}

abstract class ProductRepository {
  Future<Product> get(String id);
  Future<List<Product>> getList();
}

class GetProductUseCase extends UseCase<Product, String> {
  final ProductRepository _repository;
  
  GetProductUseCase(this._repository);
  
  @override
  Future<Product> execute(String id, CancelToken? cancelToken) async {
    cancelToken?.throwIfCancelled();
    return _repository.get(id);
  }
}
```

## Data Layer

Implements the contracts defined by the Domain layer. Contains all external dependencies.

### Components

| Component | Purpose |
|-----------|---------|
| **DataRepository** | Implements Repository interface, coordinates data sources |
| **DataSource** | Abstract interface for data operations |
| **RemoteDataSource** | API calls, external services |
| **LocalDataSource** | Local cache, database (Hive, SQLite, etc.) |

### Structure

```
lib/src/data/
├── data_sources/
│   └── product/
│       ├── product_data_source.dart      # Abstract interface
│       ├── product_remote_data_source.dart   # API implementation
│       └── product_local_data_source.dart    # Cache implementation
└── repositories/
    └── data_product_repository.dart      # Implementation
```

```dart
// Data layer - Implements Domain contracts
class DataProductRepository implements ProductRepository {
  final ProductDataSource _remoteDataSource;
  final ProductDataSource? _localDataSource;
  
  DataProductRepository(this._remoteDataSource, [this._localDataSource]);
  
  @override
  Future<Product> get(String id) async {
    // Check cache first
    if (_localDataSource != null) {
      try {
        return await _localDataSource!.get(id);
      } catch (_) {
        // Cache miss - fetch from remote
      }
    }
    
    final product = await _remoteDataSource.get(id);
    await _localDataSource?.save(product);
    return product;
  }
  
  @override
  Future<List<Product>> getList() => _remoteDataSource.getList();
}
```

## Presentation Layer (Flutter)

UI and state management. Depends on the Domain layer but never directly on the Data layer.

### VPC Architecture

Zuraffa uses **View-Presenter-Controller** pattern for presentation:

```
View → Controller → Presenter → UseCase → Repository
```

| Component | Responsibility | Base Class |
|-----------|---------------|------------|
| **View** | Pure UI, widgets | `CleanView` |
| **Controller** | State management, UI events | `Controller` |
| **Presenter** | Business logic coordination | `Presenter` |

### View

The View is **pure UI** - no business logic, just widgets.

```dart
class ProductView extends CleanView {
  final ProductRepository productRepository;
  
  const ProductView({required this.productRepository});
  
  @override
  State<ProductView> createState() => _ProductViewState(
    ProductController(
      ProductPresenter(productRepository: productRepository),
    ),
  );
}

class _ProductViewState extends CleanViewState<ProductView, ProductController> {
  _ProductViewState(super.controller);
  
  @override
  Widget get view {
    return Scaffold(
      appBar: AppBar(title: const Text('Products')),
      body: ControlledWidgetBuilder<ProductController>(
        builder: (context, controller) {
          if (controller.viewState.isLoading) {
            return const CircularProgressIndicator();
          }
          return ListView.builder(
            itemCount: controller.viewState.productList.length,
            itemBuilder: (context, index) {
              final product = controller.viewState.productList[index];
              return ListTile(title: Text(product.name));
            },
          );
        },
      ),
    );
  }
}
```

### Controller

Manages state and handles UI events. Uses `StatefulController` mixin for state management.

:::tip Recommended: Use `--state` Flag
We highly recommend using the `--state` flag when generating VPC components. It automatically creates a `State` class with granular loading states for each operation:

```bash
zfa generate Product --methods=get,watch,create,update,delete,getList,watchList --vpc --state
```

This generates an immutable `ProductState` with:
- Individual loading flags (`isGetting`, `isCreating`, `isUpdating`, etc.)
- Error handling
- Data fields
- `copyWith()` for immutable updates
- `isLoading` getter for any operation in progress
:::

```dart
class ProductController extends Controller with StatefulController<ProductState> {
  final ProductPresenter _presenter;
  
  ProductController(this._presenter) : super();
  
  @override
  ProductState createInitialState() => const ProductState();
  
  Future<void> loadProducts() async {
    updateState(viewState.copyWith(isGettingList: true));
    
    final result = await _presenter.getProductList();
    
    result.fold(
      (products) => updateState(viewState.copyWith(
        isGettingList: false,
        productList: products,
      )),
      (failure) => updateState(viewState.copyWith(
        isGettingList: false,
        error: failure,
      )),
    );
  }
  
  @override
  void onDisposed() {
    _presenter.dispose();
    super.onDisposed();
  }
}
```

:::info No Complex State Management Needed
With Zuraffa's built-in `StatefulController` and the auto-generated State classes, **you don't need Bloc, Riverpod, or other complex state management solutions**. The framework handles:
- Automatic UI updates via `notifyListeners()`
- Immutable state updates via `copyWith()`
- Granular loading states for each operation
- Error state management
:::

### Presenter

Orchestrates UseCases. Contains no state - just business logic coordination.

```dart
class ProductPresenter extends Presenter {
  final ProductRepository productRepository;
  
  late final GetProductUseCase _getProduct;
  late final GetProductListUseCase _getProductList;
  
  ProductPresenter({required this.productRepository}) {
    _getProduct = registerUseCase(GetProductUseCase(productRepository));
    _getProductList = registerUseCase(GetProductListUseCase(productRepository));
  }
  
  Future<Result<Product, AppFailure>> getProduct(String id) {
    return _getProduct.call(id);
  }
  
  Future<Result<List<Product>, AppFailure>> getProductList() {
    return _getProductList.call(const NoParams());
  }
}
```

## Data Flow

```
User Action
    ↓
View (detects gesture)
    ↓
Controller (handles event)
    ↓
Presenter (orchestrates)
    ↓
UseCase (business logic)
    ↓
Repository Interface (Domain)
    ↓
DataRepository (Data layer implementation)
    ↓
DataSource (remote/local)
    ↓
External Service (API/Database)
```

## Benefits of This Architecture

### 1. Testability

- **Domain layer**: Unit test without mocks (pure logic)
- **UseCases**: Mock repositories, test business logic
- **Controllers**: Mock presenters, test state changes

### 2. Independence

- Swap HTTP clients without touching business logic
- Change database from Hive to SQLite in one place
- UI can be completely redesigned without affecting domain

### 3. Team Scalability

- Frontend developers work on Presentation
- Backend developers work on Data layer
- Domain experts define UseCases

### 4. Framework Independence

- Domain layer has no Flutter dependencies
- Could reuse domain in Dart backend
- Easy to migrate to new frameworks

## File Organization

```
lib/src/
├── domain/
│   ├── entities/
│   │   └── product/
│   │       └── product.dart
│   ├── repositories/
│   │   └── product_repository.dart
│   └── usecases/
│       └── product/
│           ├── get_product_usecase.dart
│           └── get_product_list_usecase.dart
├── data/
│   ├── data_sources/
│   │   └── product/
│   │       ├── product_data_source.dart
│   │       └── product_remote_data_source.dart
│   └── repositories/
│       └── data_product_repository.dart
└── presentation/
    └── pages/
        └── product/
            ├── product_view.dart
            ├── product_presenter.dart
            ├── product_controller.dart
            └── product_state.dart
```

## Next Steps

- [UseCase Types](./usecases) - Deep dive into each UseCase type
- [Error Handling](./error-handling) - Result type and AppFailure hierarchy
- [CLI Generation](../cli/commands) - Generate this architecture automatically