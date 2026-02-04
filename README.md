#  🦒 Zuraffa

[![Pub Version](https://img.shields.io/pub/v/zuraffa)](https://pub.dev/packages/zuraffa)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Documentation](https://img.shields.io/badge/docs-docusaurus-blue)](https://arrrrny.github.io/zuraffa/)

A comprehensive Clean Architecture framework for Flutter applications with **Result-based error handling**, **type-safe failures**, and **minimal boilerplate**.

## 📚 Documentation

- **[Full Documentation](https://zuraffa.com/docs/intro)** - Complete guides and API reference
- **[Landing Page](https://zuraffa.com)** - Beautiful overview and quick start
- **[Github](https://github.com/arrrrny/zuraffa)** - Source code and example

## What is Zuraffa?

 🦒 Zuraffa (Zürafa means Giraffe in Türkçe) is a modern Flutter package that implements Clean Architecture principles with a focus on developer experience and type safety. It provides a robust set of tools for building scalable, testable, and maintainable Flutter applications.

### Key Features

- ✅ **Clean Architecture Enforced**: Entity-based, Single (Responsibility) Repository, Orchestrator, and Polymorphic patterns
- ✅ **UseCase Pattern**: Single-shot, streaming, and background operations
- ✅ **State Management Included**: Simple state management with automatic cleanup
- ✅ **ZFA CLI Tool**: Generate boilerplate code with `zfa` command
- ✅ **MCP Server**: AI/IDE integration via Model Context Protocol
- ✅ **Cancellation**: Cooperative cancellation with `CancelToken`
- ✅ **Fine-grained Rebuilds**: Optimize performance with selective widget updates
- ✅ **Caching**: Built-in dual datasource pattern with flexible cache policies
- ✅ **Result Type**: Type-safe error handling with `Result<T, AppFailure>`
- ✅ **Sealed Failures**: Exhaustive pattern matching for error cases

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  zuraffa: ^2.1.0
```

Then run:

```bash
flutter pub get
```

## Quick Start

### 1. Configure Your Project

First, set up ZFA configuration for your project:

```bash
# Activate the CLI
dart pub global activate zuraffa

# Create configuration with defaults
zfa config init

# Optionally customize defaults
zfa config set useZorphyByDefault true
zfa config set defaultEntityOutput lib/src/domain/entities
```

**Configuration Options:**
- `useZorphyByDefault` - Use Zorphy for entities (default: true)
- `jsonByDefault` - Default JSON serialization (default: true)
- `compareByDefault` - Default compareTo generation (default: true)
- `defaultEntityOutput` - Default entity output directory

### 2. Create Your Entities

Create entities first, then generate Clean Architecture around them:

```bash
# Create an enum
zfa entity enum -n OrderStatus --value pending,processing,shipped,delivered

# Create entities with fields
zfa entity create -n User --field name:String --field email:String?
zfa entity create -n Order --field customer:\$User --field status:OrderStatus --field items:List<\$OrderItem>
zfa entity create -n OrderItem --field product:\$Product --field quantity:int --field price:double

# List all entities
zfa entity list
```

### 3. Generate Clean Architecture

Now generate complete features around your entities:

```bash
# Generate a complete feature for your entity
zfa generate Order --methods=get,getList,create,update,delete --data --vpc --state --test

# Or generate multiple entities at once
zfa generate User --methods=get,create --data
zfa generate Product --methods=get,getList,watch,watchList --data --vpc --state
```

**That's it!** One command generates:
- ✅ Domain layer (UseCases + Repository interface)
- ✅ Data layer (DataRepository + DataSource)
- ✅ Presentation layer (View, Presenter, Controller, State)
- ✅ Unit tests for all UseCases

### 4. Run Code Generation

After creating entities, run the build:

```bash
# Run Zorphy + json_serializable code generation
zfa build

# Or watch for changes
zfa build --watch
```

This generates:
- Entity implementations with `copyWith`, `==`, `hashCode`, `toString`
- JSON serialization (`toJson`/`fromJson`)
- Typed patch classes for updates (when using `--zorphy`)

### 5. Use the Generated Code

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

class _ProductViewState extends CleanViewState<ProductView, ProductController> {
  _ProductViewState(super.controller);

  @override
  void onInitState() {
    super.onInitState();
    controller.getProductList();
  }

  @override
  Widget get view {
    return Scaffold(
      key: globalKey,
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

### Generated Output Example

```
✅ Created 2 entities

  ⟳ lib/src/domain/entities/order/order.dart
  ⟳ lib/src/domain/entities/order/order.zorphy.dart
  ⟳ lib/src/domain/entities/order/order.g.dart
  ⟳ lib/src/domain/entities/order_item/order_item.dart
  ⟳ lib/src/domain/entities/order_item/order_item.zorphy.dart
  ⟳ lib/src/domain/entities/order_item/order_item.g.dart

✅ Generated 21 files for Order

  ⟳ lib/src/domain/repositories/order_repository.dart
  ⟳ lib/src/domain/usecases/order/get_order_usecase.dart
  ⟳ lib/src/domain/usecases/order/watch_order_usecase.dart
  ⟳ lib/src/domain/usecases/order/create_order_usecase.dart
  ⟳ lib/src/domain/usecases/order/update_order_usecase.dart
  ⟳ lib/src/domain/usecases/order/delete_order_usecase.dart
  ⟳ lib/src/domain/usecases/order/get_order_list_usecase.dart
  ⟳ lib/src/domain/usecases/order/watch_order_list_usecase.dart
  ⟳ lib/src/presentation/pages/order/order_presenter.dart
  ⟳ lib/src/presentation/pages/order/order_controller.dart
  ⟳ lib/src/presentation/pages/order/order_view.dart
  ⟳ lib/src/presentation/pages/order/order_state.dart
  ⟳ lib/src/data/data_sources/order/order_data_source.dart
  ⟳ lib/src/data/repositories/data_order_repository.dart
  ✓ test/domain/usecases/order/get_order_usecase_test.dart
  ✓ test/domain/usecases/order/watch_order_usecase_test.dart
  ✓ test/domain/usecases/order/create_order_usecase_test.dart
  ✓ test/domain/usecases/order/update_order_usecase_test.dart
  ✓ test/domain/usecases/order/delete_order_usecase_test.dart
  ✓ test/domain/usecases/order/get_order_list_usecase_test.dart
  ✓ test/domain/usecases/order/watch_order_list_usecase_test.dart

📝 Next steps:
   • Create a DataSource that implements ProductDataSource in data layer
   • Register repositories with DI container
   • Run tests: flutter test 
```

## Core Concepts

### Result Type

All operations return `Result<T, AppFailure>` for type-safe error handling:

```dart
final result = await getProductUseCase('product-123');

// Pattern matching with fold
result.fold(
  (product) => showProduct(product),
  (failure) => showError(failure),
);

// Or use switch for exhaustive handling
switch (failure) {
  case NotFoundFailure():
    showNotFound();
  case NetworkFailure():
    showOfflineMessage();
  case UnauthorizedFailure():
    navigateToLogin();
  default:
    showGenericError();
}
```

### AppFailure Hierarchy

Zuraffa provides a sealed class hierarchy for comprehensive error handling:

```dart
sealed class AppFailure implements Exception {
  final String message;
  final StackTrace? stackTrace;
  final Object? cause;
}

// Specific failure types
final class ServerFailure extends AppFailure { ... }
final class NetworkFailure extends AppFailure { ... }
final class ValidationFailure extends AppFailure { ... }
final class NotFoundFailure extends AppFailure { ... }
final class UnauthorizedFailure extends AppFailure { ... }
final class ForbiddenFailure extends AppFailure { ... }
final class TimeoutFailure extends AppFailure { ... }
final class CacheFailure extends AppFailure { ... }
final class ConflictFailure extends AppFailure { ... }
final class CancellationFailure extends AppFailure { ... }
final class UnknownFailure extends AppFailure { ... }
```

### Data Updates

Zuraffa supports two strategies for updating entities:

#### 1. Flexible Partial Updates (Default)
Uses `Partial<T>` (a `Map<String, dynamic>`) to send only changed fields. The generator automatically adds validation to ensure only valid fields are updated.

```dart
// Generated UpdateUseCase
// params.validate(['id', 'name', 'price']); <-- Auto-generated from Entity
await updateProduct(id: '123', data: {'name': 'New Product Name'});
```

#### 2. Typed Updates with Zorphy (`--zorphy`)
If you use [Zorphy](https://pub.dev/packages/zorphy) or similar tools, you can use typed Patch objects for full type safety.

```bash
zfa generate Product --methods=update --zorphy
```

```dart
// Generated with --zorphy
await updateProduct(id: '123', data: ProductPatch(name: 'New Product Name'));
```

### UseCase Types

#### Single-shot UseCase

For operations that return once:

```dart
class GetProductUseCase extends UseCase<Product, String> {
  final ProductRepository _repository;

  GetProductUseCase(this._repository);

  @override
  Future<Product> execute(String productId, CancelToken? cancelToken) async {
    return _repository.getProduct(productId);
  }
}
```

#### StreamUseCase

For reactive operations that emit multiple values:

```dart
class WatchProductsUseCase extends StreamUseCase<List<Product>, NoParams> {
  final ProductRepository _repository;

  WatchProductsUseCase(this._repository);

  @override
  Stream<List<Product>> execute(NoParams params, CancelToken? cancelToken) {
    return _repository.watchProducts();
  }
}
```

#### BackgroundUseCase

For CPU-intensive operations on isolates:

```dart
class ProcessImageUseCase extends BackgroundUseCase<ProcessedImage, ImageParams> {
  @override
  BackgroundTask<ImageParams> buildTask() => _processImage;

  static void _processImage(BackgroundTaskContext<ImageParams> context) {
    final result = applyFilters(context.params.image);
    context.sendData(result);
    context.sendDone();
  }
}
```

#### CompletableUseCase

For operations that don't return a value (like delete, logout, or clear cache):

```dart
class DeleteProductUseCase extends CompletableUseCase<String> {
  final ProductRepository _repository;

  DeleteProductUseCase(this._repository);

  @override
  Future<void> execute(String productId, CancelToken? cancelToken) async {
    cancelToken?.throwIfCancelled();
    await _repository.delete(productId);
  }
}

// Usage - returns Result<void, AppFailure>
final result = await deleteProductUseCase('product-123');
result.fold(
  (_) => showSuccess('Product deleted'),
  (failure) => showError(failure),
);
```

`CompletableUseCase` is useful when you only care about whether an operation succeeded or failed, without needing any returned data. Common use cases include:
- Delete operations
- Logout/sign out
- Clear cache
- Send analytics events
- Fire-and-forget notifications

### Controller with State

Controllers use `StatefulController<T>` with immutable state objects:

```dart
class ProductController extends Controller with StatefulController<ProductState> {
  final ProductPresenter _presenter;

  ProductController(this._presenter) : super();

  @override
  ProductState createInitialState() => const ProductState();

  Future<void> getProductList() async {
    updateState(viewState.copyWith(isGettingList: true));
    final result = await _presenter.getProductList();

    result.fold(
      (list) => updateState(viewState.copyWith(
        isGettingList: false,
        productList: list,
      )),
      (failure) => updateState(viewState.copyWith(
        isGettingList: false,
        error: failure,
      )),
    );
  }

  Future<void> createProduct(Product product) async {
    updateState(viewState.copyWith(isCreating: true));
    final result = await _presenter.createProduct(product);

    result.fold(
      (created) => updateState(viewState.copyWith(
        isCreating: false,
        productList: [...viewState.productList, created],
      )),
      (failure) => updateState(viewState.copyWith(
        isCreating: false,
        error: failure,
      )),
    );
  }
}
```

### State

Immutable state classes are auto-generated with the `--state` flag:

```dart
class ProductState {
  final AppFailure? error;
  final List<Product> productList;
  final Product? product;
  final bool isGetting;
  final bool isCreating;
  final bool isUpdating;
  final bool isDeleting;
  final bool isGettingList;

  const ProductState({
    this.error,
    this.productList = const [],
    this.product,
    this.isGetting = false,
    this.isCreating = false,
    this.isUpdating = false,
    this.isDeleting = false,
    this.isGettingList = false,
  });

  ProductState copyWith({...}) => ...;

  bool get isLoading => isGetting || isCreating || isUpdating || isDeleting || isGettingList;
  bool get hasError => error != null;
}
```

### CleanView

Base class for views with automatic lifecycle management. Views are pure UI and delegate all business logic to the Controller:

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

class _ProductViewState extends CleanViewState<ProductView, ProductController> {
  _ProductViewState(super.controller);

  @override
  void onInitState() {
    super.onInitState();
    controller.getProductList();
  }

  @override
  Widget get view {
    return Scaffold(
      key: globalKey, // Important: use globalKey on root widget
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

## Dependency Injection Generation

Zuraffa can automatically generate dependency injection setup using get_it:

```bash
# Generate DI files alongside your code
zfa generate Product --methods=get,getList,create --data --vpc --di

# Use mock datasource in DI (for development/testing)
zfa generate Product --methods=get,getList --data --mock --di --use-mock

# With caching enabled
zfa generate Product --methods=get,getList --data --cache --di
```

### Generated DI Structure

```
lib/src/di/
├── index.dart                    # Main entry with setupDependencies()
├── datasources/
│   ├── index.dart               # Auto-generated
│   └── product_remote_data_source_di.dart
├── repositories/
│   ├── index.dart               # Auto-generated
│   └── product_repository_di.dart
├── usecases/
│   ├── index.dart               # Auto-generated
│   ├── get_product_usecase_di.dart
│   └── get_product_list_usecase_di.dart
├── presenters/
│   ├── index.dart               # Auto-generated
│   └── product_presenter_di.dart
└── controllers/
    ├── index.dart               # Auto-generated
    └── product_controller_di.dart
```

### Usage

```dart
import 'package:get_it/get_it.dart';
import 'src/di/index.dart';

void main() {
  final getIt = GetIt.instance;
  setupDependencies(getIt);
  
  runApp(MyApp());
}

// Access registered dependencies
final productRepository = getIt<ProductRepository>();
final productController = getIt<ProductController>();
```

### Features

- ✅ **One file per component**: No merge conflicts
- ✅ **Auto-generated indexes**: Directory scanning regenerates imports
- ✅ **Cache support**: Registers remote + local datasources when `--cache` used
- ✅ **Mock support**: Use `--use-mock` to register mock datasources
- ✅ **Fail-safe**: Regenerate anytime without manual merging

## Cache Initialization (Hive)

When using `--cache` with `--di`, Zuraffa automatically generates cache initialization files:

```bash
# Generate with cache and DI
zfa generate Product --methods=get,getList --data --cache --cache-policy=ttl --ttl=30 --di
```

### Generated Cache Structure

```
lib/src/cache/
├── hive_registrar.dart              # @GenerateAdapters for all entities
├── hive_manual_additions.txt        # Template for nested entities/enums
├── product_cache.dart               # Opens Product box
├── timestamp_cache.dart             # Opens timestamps box
├── ttl_30_minutes_cache_policy.dart # Cache policy implementation
└── index.dart                       # initAllCaches() + exports
```

### Adding Nested Entities and Enums

The generator creates `hive_manual_additions.txt` for entities that aren't directly cached but need adapters (nested entities, enums, etc.):

```txt
# Hive Manual Additions
# Format: import_path|EntityName

../domain/entities/enums/index.dart|ParserType
../domain/entities/enums/index.dart|HttpClientType
../domain/entities/range/range.dart|Range
../domain/entities/filter_parameter/filter_parameter.dart|FilterParameter
```

After adding entries, regenerate:

```bash
zfa generate Product --methods=get --data --cache --di --force
```

The registrar will include all manual additions:

```dart
@GenerateAdapters([
  AdapterSpec<ParserType>(),
  AdapterSpec<HttpClientType>(),
  AdapterSpec<Range>(),
  AdapterSpec<FilterParameter>(),
  AdapterSpec<Product>()
])
```

### Generated Files

**hive_registrar.dart** - Automatic adapter registration:
```dart
@GenerateAdapters([AdapterSpec<Product>(), AdapterSpec<User>()])
part 'hive_registrar.g.dart';

extension HiveRegistrar on HiveInterface {
  void registerAdapters() {
    registerAdapter(ProductAdapter());
    registerAdapter(UserAdapter());
  }
}
```

**Cache policy** - Fully implemented with Hive:
```dart
CachePolicy createTtl30MinutesCachePolicy() {
  final timestampBox = Hive.box<int>('cache_timestamps');
  return TtlCachePolicy(
    ttl: const Duration(minutes: 30),
    getTimestamps: () async => Map<String, int>.from(timestampBox.toMap()),
    setTimestamp: (key, timestamp) async => await timestampBox.put(key, timestamp),
    removeTimestamp: (key) async => await timestampBox.delete(key),
    clearAll: () async => await timestampBox.clear(),
  );
}
```

### Usage

```dart
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
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

### Workflow

1. Generate code with `--cache` and `--di`
2. Run `dart run build_runner build` (generates `hive_registrar.g.dart`)
3. Call `initAllCaches()` before DI setup

### Features

- ✅ **Automatic adapter registration**: No manual Hive.registerAdapter() calls
- ✅ **Separate policy files**: `daily_cache_policy.dart`, `ttl_<N>_minutes_cache_policy.dart`
- ✅ **Custom TTL**: Use `--ttl=<minutes>` for custom durations
- ✅ **Type-safe**: Abstract DataSource type allows easy mock/remote switching

## Mock Data Generation

Zuraffa can generate realistic mock data for your entities, perfect for testing, UI previews, and development:

```bash
# Generate mock data alongside other layers
zfa generate Product --methods=get,getList,create --vpc --mock

# Generate only mock data files
zfa generate Product --mock-data-only
```

### Generated Mock Data

Mock data files provide realistic test data with proper type safety:

```dart
// Generated: lib/src/data/mock/product_mock_data.dart
class ProductMockData {
  static final List<Product> products = [
    Product(
      id: 'id 1',
      name: 'name 1', 
      description: 'description 1',
      price: 10.5,
      category: 'category 1',
      isActive: true,
      createdAt: DateTime.now().subtract(Duration(days: 30)),
      updatedAt: DateTime.now().subtract(Duration(days: 30)),
    ),
    Product(
      id: 'id 2',
      name: 'name 2',
      description: 'description 2', 
      price: 21.0,
      category: 'category 2',
      isActive: false,
      createdAt: DateTime.now().subtract(Duration(days: 60)),
      updatedAt: DateTime.now().subtract(Duration(days: 60)),
    ),
    // ... more items
  ];

  static Product get sampleProduct => products.first;
  static List<Product> get sampleList => products;
  static List<Product> get emptyList => [];
  
  // Large dataset for performance testing
  static List<Product> get largeProductList => List.generate(100, 
    (index) => _createProduct(index + 1000));
}
```

### Features

- ✅ **Realistic data**: Type-appropriate values for all field types
- ✅ **Nested entities**: Automatic detection and cross-references
- ✅ **Complex types**: Support for `List<T>`, `Map<K,V>`, nullable types
- ✅ **Enum handling**: Smart imports only when needed
- ✅ **Large datasets**: Generated methods for performance testing
- ✅ **Null safety**: Proper handling of optional fields

### Usage in Tests

```dart
// Use in unit tests
test('should process product list', () {
  final products = ProductMockData.sampleList;
  final result = processProducts(products);
  expect(result.length, equals(3));
});

// Use in widget tests  
testWidgets('should display product', (tester) async {
  await tester.pumpWidget(ProductView(
    product: ProductMockData.sampleProduct,
  ));
  expect(find.text('name 1'), findsOneWidget);
});
```

## CLI Tool

Zuraffa includes a powerful CLI tool (`zfa`) for generating boilerplate code.

### Installation

```bash
# Global activation
dart pub global activate zuraffa

# Or run directly
dart run zuraffa:zfa
```


### Entity Commands (NEW!)

Zuraffa now includes **full Zorphy entity generation** - create type-safe entities, enums, and manage data models:

```bash
# Create an entity with fields
zfa entity create -n User --field name:String --field email:String? --field age:int

# Create an enum
zfa entity enum -n Status --value active,inactive,pending

# Quick-create a simple entity
zfa entity new -n Product

# Add fields to existing entity
zfa entity add-field -n User --field phone:String?

# Create entity from JSON file
zfa entity from-json user_data.json

# List all entities
zfa entity list

# Build generated code
zfa build
zfa build --watch  # Watch for changes
zfa build --clean  # Clean and rebuild
```

**Full Entity Generation Features:**
- ✅ Type-safe entities with null safety
- ✅ JSON serialization (built-in)
- ✅ Sealed classes for polymorphism
- ✅ Multiple inheritance support
- ✅ Generic types (`List<T>`, `Map<K,V>`)
- ✅ Nested entities with auto-imports
- ✅ Enum integration
- ✅ Self-referencing types (trees)
- ✅ compare`To, `copyWith`, `patch` methods

**📖 For complete entity generation documentation, see [ENTITY_GUIDE.md](ENTITY_GUIDE.md)**

### Generate Clean Architecture

**One command generates your entire feature:**

```bash
# Generate everything at once - Domain, Data, and Presentation layers
zfa generate Product --methods=get,getList,create,update,delete --data --vpc --state

# Generate with mock data for testing and UI previews
zfa generate Product --methods=get,getList,create,update,delete --data --vpc --state --mock

# Generate only mock data files
zfa generate Product --mock-data-only

# Or generate incrementally:

# Generate UseCases + Repository interface
zfa generate Product --methods=get,getList,create,update,delete

# Add presentation layer (View, Presenter, Controller, State)
zfa generate Product --methods=get,getList,create,update,delete --vpc --state

# Add data layer (DataRepository + DataSource)
zfa generate Product --methods=get,getList,create,update,delete --data

# Use typed patches for updates (Zorphy support)
zfa generate Product --methods=update --zorphy

# Enable caching with dual datasources
zfa generate Config --methods=get,getList --data --cache --cache-policy=daily

# Preview what would be generated without writing files
zfa generate Product --methods=get,getList --dry-run

# Generate with unit tests for each UseCase
zfa generate Product --methods=get,create,update,delete --test

# Custom UseCase with repository
zfa generate SearchProduct --domain=search --repo=Product --params=Query --returns=List<Product>

# Orchestrator pattern (compose UseCases)
zfa generate ProcessCheckout --domain=checkout --usecases=ValidateCart,ProcessPayment --params=CheckoutRequest --returns=OrderResult

# Background UseCase for CPU-intensive operations (runs on isolate)
zfa generate CalculatePrimeNumbers --type=background --params=int --returns=int
```

#### Custom UseCase Types

The `--type` flag supports three variants for custom UseCases:

| Type | Description | Use When |
|------|-------------|----------|
| `custom` (default) | Standard UseCase with repository dependencies | CRUD operations, business logic |
| `background` | Runs on a separate isolate | CPU-intensive work (calculations, image processing) |
| `stream` | Emits multiple values over time | Real-time data, WebSocket, Firebase listeners |

#### Defining Parameter and Return Types

Use `--params` and `--returns` to specify custom types for your UseCase:

```bash
# Define custom parameter and return types
zfa generate CalculatePrimeNumbers --type=background --params=int --returns=int

# Orchestrator with multiple UseCases
zfa generate ProcessCheckout --domain=checkout --usecases=ValidateCart,ProcessPayment --params=CheckoutRequest --returns=OrderConfirmation
```

| Flag | Description | Example |
|------|-------------|---------|
| `--params` | Input parameter type for the UseCase | `--params=int`, `--params=ProductFilter` |
| `--returns` | Return type from the UseCase | `--returns=bool`, `--returns=List<Product>` |

### Available Methods

| Method     | UseCase Type       | Description                     |
|------------|-------------------|---------------------------------|
| `get`      | UseCase           | Get single entity by ID         |
| `getList`  | UseCase           | Get all entities                |
| `create`   | UseCase           | Create new entity               |
| `update`   | UseCase           | Update existing entity          |
| `delete`   | CompletableUseCase| Delete entity by ID             |
| `watch`    | StreamUseCase     | Watch single entity             |
| `watchList`| StreamUseCase     | Watch all entities              |

### CLI Flags

| Flag           | Description                                           |
|----------------|-------------------------------------------------------|
| `--data`       | Generate DataRepository and DataSource (always includes remote datasource) |
| `--vpc`        | Generate View, Presenter, and Controller              |
| `--vpcs`       | Generate View, Presenter, Controller, and State       |
| `--pc`         | Generate Presenter and Controller only (preserve View)|
| `--pcs`        | Generate Presenter, Controller, and State (preserve View) |
| `--repo`       | Repository to inject (for custom UseCases)            |
| `--domain`     | Domain folder (required for custom UseCases)          |
| `--append`     | Append to existing repository/datasources             |
| `--usecases`   | Orchestrator: compose UseCases (comma-separated)      |
| `--variants`   | Polymorphic: generate variants (comma-separated)      |
| `--state`      | Generate immutable State class                        |
| `--mock`       | Generate mock data files alongside other layers       |
| `--mock-data-only` | Generate only mock data files (no other layers)   |
| `--use-mock`   | Use mock datasource in DI (default: remote datasource)|
| `--di`         | Generate dependency injection files (get_it)          |
| `--zorphy`     | Use typed Patch objects for updates                   |
| `--cache`      | Enable caching with dual datasources (remote + local) |
| `--cache-policy` | Cache expiration: daily, restart, ttl (default: daily) |
| `--cache-storage` | Local storage hint: hive, sqlite, shared_preferences (default: hive) |
| `--ttl`        | TTL duration in minutes (default: 1440 = 24 hours)    |
| `--subfolder`  | Organize under a subfolder (e.g., `--subfolder=auth`) |
| `--init`       | Add initialize method & isInitialized stream to repos |
| `--force`      | Overwrite existing files                              |
| `--dry-run`    | Preview what would be generated without writing files |
| `--test`       | Generate unit tests for each UseCase                  |
| `--format=json`| Output JSON for AI/IDE integration                    |

### AI/JSON Integration

```bash
# JSON output for parsing
zfa generate Product --methods=get,getList --format=json

# Read from stdin
echo '{"name":"Product","methods":["get","getList"]}' | zfa generate Product --from-stdin

# Get JSON schema for validation
zfa schema

# Dry run (preview without writing)
zfa generate Product --methods=get --dry-run --format=json
```

For complete CLI documentation, see [CLI_GUIDE.md](CLI_GUIDE.md).

## MCP Server

Zuraffa includes an MCP (Model Context Protocol) server for seamless integration with AI-powered development environments like Claude Desktop, Cursor, and VS Code.

### Installation

**Option 1: From pub.dev (Recommended)**
```bash
dart pub global activate zuraffa
# MCP server is immediately available: zuraffa_mcp_server
```

**Option 2: Pre-compiled Binary (Fastest)**

Download from [GitHub Releases](https://github.com/arrrrny/zuraffa/releases):
- macOS ARM64 / x64
- Linux x64
- Windows x64

```bash
# macOS/Linux
chmod +x zuraffa_mcp_server-macos-arm64
sudo mv zuraffa_mcp_server-macos-arm64 /usr/local/bin/zuraffa_mcp_server
```

**Option 3: Compile from Source**
```bash
dart compile exe bin/zuraffa_mcp_server.dart -o zuraffa_mcp_server
```

### MCP Tools

- `zuraffa_generate` - Generate Clean Architecture code
- `zuraffa_schema` - Get JSON schema for config validation
- `zuraffa_validate` - Validate a generation config

For complete MCP documentation, see [MCP_SERVER.md](MCP_SERVER.md).

## Project Structure

Recommended folder structure for Clean Architecture (auto-generated by `zfa`):

```
lib/
├── main.dart
└── src/
    ├── core/                    # Shared utilities
    │   ├── error/               # Custom failures if needed
    │   ├── network/             # HTTP client, interceptors
    │   └── utils/               # Helpers, extensions
    │
    ├── data/                    # Data layer
    │   ├── data_sources/        # Remote and local data sources
    │   │   └── product/
    │   │       └── product_data_source.dart
    │   └── repositories/        # Repository implementations
    │       └── data_product_repository.dart
    │
    ├── domain/                  # Domain layer (pure Dart)
    │   ├── entities/            # Business objects
    │   │   └── product/
    │   │       └── product.dart
    │   ├── repositories/        # Repository interfaces
    │   │   └── product_repository.dart
    │   └── usecases/            # Business logic
    │       └── product/
    │           ├── get_product_usecase.dart
    │           ├── create_product_usecase.dart
    │           └── ...
    │
    └── presentation/            # Presentation layer
        └── pages/               # Full-screen views
            └── product/
                ├── product_view.dart
                ├── product_presenter.dart
                ├── product_controller.dart
                └── product_state.dart
```

**All of this is generated with a single command:**
```bash
zfa generate Product --methods=get,getList,create,update,delete --data --vpc --state
```

## Advanced Features

### CancelToken

Cooperative cancellation for long-running operations:

```dart
// Create a token
final cancelToken = CancelToken();

// Use with a use case
final result = await getProductUseCase(productId, cancelToken: cancelToken);

// Cancel when needed
cancelToken.cancel('Product page closed');

// Create with timeout
final timeoutToken = CancelToken.timeout(const Duration(seconds: 30));

// In Controllers, use createCancelToken() for automatic cleanup
class MyController extends Controller {
  Future<void> loadData() async {
    // Token automatically cancelled when controller disposes
    final result = await execute(myUseCase, params);
  }
}
```

### ControlledWidgetSelector

For fine-grained rebuilds when only specific values change:

```dart
// Only rebuilds when product.name changes
ControlledWidgetSelector<ProductController, String?>(
  selector: (controller) => controller.viewState.product?.name,
  builder: (context, productName) {
    return Text(productName ?? 'Unknown');
  },
)
```

### Global Configuration

```dart
void main() {
  // Enable debug logging
  Zuraffa.enableLogging();

  runApp(MyApp());
}

// Access controllers from child widgets
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final controller = Zuraffa.getController<MyController>(context);
    return ElevatedButton(
      onPressed: () => controller.doSomething(),
      child: Text('Action'),
    );
  }
}
```

## Example

See the [example](./example) directory for a complete working application demonstrating:

- ✅ UseCase for CRUD operations
- ✅ StreamUseCase for real-time updates
- ✅ BackgroundUseCase for CPU-intensive calculations
- ✅ Controller with immutable state
- ✅ CleanView with ControlledWidgetBuilder
- ✅ CancelToken for cancellation
- ✅ Error handling with AppFailure

Run the example:

```bash
cd example
flutter pub get
flutter run
```

## Documentation

- [CLI Guide](CLI_GUIDE.md) - Complete CLI documentation
- [Caching Guide](CACHING.md) - Dual datasource caching pattern
- [MCP Server](MCP_SERVER.md) - MCP server setup and usage
- [AGENTS.md](AGENTS.md) - Guide for AI coding agents
- [Contributing](CONTRIBUTING.md) - How to contribute
- [Code of Conduct](CODE_OF_CONDUCT.md) - Community guidelines

## License

MIT License - see [LICENSE](LICENSE) for details.

## Authors

- **Ahmet TOK** - [GitHub](https://github.com/arrrrny)

---

Made with ⚡️ for the Flutter community
