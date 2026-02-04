# ZFA CLI Guide

The `zfa` (Zuraffa) CLI is a powerful code generator that creates Clean Architecture boilerplate code from simple command-line flags or JSON input. It's designed to be **AI-agent friendly** with machine-readable output formats.

## Table of Contents

- [Installation](#installation)
- [Quick Start](#quick-start)
- [Commands](#commands)
  - [generate](#generate-command)
  - [schema](#schema-command)
  - [validate](#validate-command)
- [Entity-Based Generation](#entity-based-generation)
- [Custom UseCase Generation](#custom-usecase-generation)
- [VPC Layer Generation](#vpc-layer-generation)
- [Data Layer Generation](#data-layer-generation)
- [AI Agent Integration](#ai-agent-integration)
- [JSON Configuration](#json-configuration)
- [Examples](#examples)
- [Generated File Structure](#generated-file-structure)

## Installation

The CLI is included with the `zuraffa` package. After adding it to your project:

```bash
# Add the package
flutter pub add zuraffa

# Run the CLI
dart run zuraffa:zfa --help
```

Or if installed globally:

```bash
dart pub global activate zuraffa
zfa --help
```

## Quick Start

Generate a complete CRUD stack for an entity:

```bash
# Basic CRUD (repository auto-generated)
zfa generate Product --methods=get,getList,create,update,delete

# With VPC layer (View, Presenter, Controller)
zfa generate Product --methods=get,getList,create,update,delete --vpc --state

# With data layer (DataRepository + DataSource)
zfa generate Product --methods=get,getList,create,update,delete --data

# Complete feature with everything
zfa generate Product --methods=get,getList,create,update,delete --data --vpc --state --test
```

## Commands

### generate Command

The primary command for generating Clean Architecture code.

```
zfa generate <Name> [options]
```

#### Arguments

| Argument | Description |
|----------|-------------|
| `<Name>` | Entity or UseCase name in PascalCase (e.g., `Product`, `ProcessOrder`) |

#### Entity-Based Options

| Flag | Short | Description |
|------|-------|-------------|
| `--methods=<list>` | `-m` | Comma-separated methods to generate |
| `--data` | `-d` | Generate data repository + data source |
| `--datasource` | | Generate data source only |
| `--id-field=<name>` | | ID field name (default: `id`) |
| `--id-field-type=<type>` | | ID field type (default: `String`) |
| `--query-field=<name>` | | Query field name for `get`/`watch` (default: `id`) |
| `--query-field-type=<type>` | | Query field type (default: matches id-type) |
| `--zorphy` | | Use Zorphy-style typed patches |
| `--init` | | Generate initialize method for repository |

**Note:** Repository interface is automatically generated for entity-based operations.

#### Supported Methods

| Method | UseCase Type | Generated Class | Description |
|--------|--------------|-----------------|-------------|
| `get` | `UseCase` | `GetProductUseCase` | Get single entity by ID |
| `getList` | `UseCase` | `GetProductListUseCase` | Get all entities |
| `create` | `UseCase` | `CreateProductUseCase` | Create new entity |
| `update` | `UseCase` | `UpdateProductUseCase` | Update existing entity |
| `delete` | `CompletableUseCase` | `DeleteProductUseCase` | Delete entity by ID |
| `watch` | `StreamUseCase` | `WatchProductUseCase` | Watch single entity |
| `watchList` | `StreamUseCase` | `WatchProductListUseCase` | Watch all entities |

#### Custom UseCase Options

| Flag | Description |
|------|-------------|
| `--repo=<name>` | Repository to inject (single, enforces SRP) |
| `--domain=<name>` | Domain folder (required for custom UseCases) |
| `--method=<name>` | Repository method name (default: auto from UseCase name) |
| `--append` | Append to existing repository/datasources |
| `--usecases=<list>` | Orchestrator: compose UseCases (comma-separated) |
| `--variants=<list>` | Polymorphic: generate variants (comma-separated) |
| `--type=<type>` | UseCase type: `usecase`, `stream`, `background`, `completable` |
| `--params=<type>` | Params type (default: `NoParams`) |
| `--returns=<type>` | Return type (default: `void`) |

#### VPC Layer Options

| Flag | Description |
|------|-------------|
| `--vpc` | Generate View + Presenter + Controller |
| `--vpcs` | Generate View + Presenter + Controller + State |
| `--pc` | Generate Presenter + Controller only (preserve View) |
| `--pcs` | Generate Presenter + Controller + State (preserve View) |
| `--state` | Generate State object with granular loading states |

#### Caching Options

| Flag | Description |
|------|-------------|
| `--cache` | Enable caching with dual datasources (remote + local) |
| `--cache-policy=<p>` | Cache policy: `daily`, `restart`, `ttl` (default: daily) |
| `--cache-storage=<s>` | Local storage: `hive`, `sqlite`, `shared_preferences` |
| `--ttl=<minutes>` | TTL duration in minutes (default: 1440 = 24 hours) |

#### Mock Data & Testing Options

| Flag | Description |
|------|-------------|
| `--mock` | Generate mock data files alongside other layers |
| `--mock-data-only` | Generate only mock data files (no other layers) |
| `--test` | Generate unit tests for UseCases |
| `--di` | Generate dependency injection files (get_it) |
| `--use-mock` | Use mock datasource in DI (default: remote datasource) |

#### Input/Output Options

| Flag | Short | Description |
|------|-------|-------------|
| `--from-json=<file>` | `-j` | JSON configuration file |
| `--from-stdin` | | Read JSON from stdin (AI-friendly) |
| `--output=<dir>` | `-o` | Output directory (default: `lib/src`) |
| `--format=<type>` | | Output format: `json` or `text` (default: `text`) |
| `--dry-run` | | Preview without writing files |
| `--force` | | Overwrite existing files |
| `--verbose` | `-v` | Verbose output |
| `--quiet` | `-q` | Minimal output (errors only) |

### schema Command

Output the JSON schema for configuration validation. Useful for AI agents.

```bash
zfa schema > zfa-schema.json
```

### validate Command

Validate a JSON configuration file.

```bash
zfa validate config.json
```

## Entity-Based Generation

Entity-based generation creates UseCases that operate on a specific entity type. The entity must already exist at:

```
lib/src/domain/entities/{entity_snake}/{entity_snake}.dart
```

### Example

Assuming you have a `Product` entity:

```bash
zfa generate Product --methods=get,getList,create,update,delete,watchList
```

This generates:

```
lib/src/
├── domain/
│   ├── repositories/
│   │   └── product_repository.dart
│   └── usecases/product/
│       ├── get_product_usecase.dart
│       ├── get_product_list_usecase.dart
│       ├── create_product_usecase.dart
│       ├── update_product_usecase.dart
│       ├── delete_product_usecase.dart
│       └── watch_product_list_usecase.dart
```

### Generated Repository Interface

```dart
abstract class ProductRepository {
  Future<Product> get(String id);
  Future<List<Product>> getList();
  Future<Product> create(Product product);
  Future<Product> update(Product product);
  Future<void> delete(String id);
  Stream<List<Product>> watchList();
}
```

### Generated UseCase Example

```dart
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

## Custom UseCase Generation

Create standalone UseCases without an entity, useful for complex business operations.

### Basic Custom UseCase

```bash
zfa generate SearchProduct \
  --domain=search \
  --repo=Product \
  --params=Query \
  --returns=List<Product>
```

Generates:

```dart
class ProcessOrderUseCase extends UseCase<OrderResult, OrderRequest> {
  final OrderRepository _orderRepository;
  final PaymentRepository _paymentRepository;

  ProcessOrderUseCase(this._orderRepository, this._paymentRepository);

  @override
  Future<OrderResult> execute(OrderRequest params, CancelToken? cancelToken) async {
    cancelToken?.throwIfCancelled();
    // TODO: Implement usecase logic
    throw UnimplementedError();
  }
}
```

### Stream UseCase

```bash
zfa generate ListenToNotifications \
  --domain=notification \
  --repo=Notification \
  --type=stream \
  --params=UserId \
  --returns=Notification
```

### Background UseCase

For CPU-intensive operations that run on a separate isolate:

```bash
zfa generate ProcessImages \
  --type=background \
  --params=ImageBatch \
  --returns=ProcessedImage
```

Generates:

```dart
class ProcessImagesUseCase extends BackgroundUseCase<ProcessedImage, ImageBatch> {
  ProcessImagesUseCase();

  @override
  BackgroundTask<ImageBatch> buildTask() => _process;

  static void _process(BackgroundTaskContext<ImageBatch> context) {
    try {
      final params = context.params;

      // TODO: Implement background processing
      // context.sendData(result);

      context.sendDone();
    } catch (e, stackTrace) {
      context.sendError(e, stackTrace);
    }
  }
}
```

## VPC Layer Generation

Generate the presentation layer with View, Presenter, and Controller.

**Note:** The `--vpc` flag creates files in `presentation/pages/{entity}/` to better organize multi-page applications.

```bash
zfa generate Product --methods=get,getList,create --vpc --state
```

Generates:

```
lib/src/
├── domain/
│   └── ...
└── presentation/pages/product/
    ├── product_view.dart
    ├── product_presenter.dart
    ├── product_controller.dart
    └── product_state.dart
```

### Generated View

```dart
class ProductView extends CleanView {
  final ProductRepository productRepository;

  const ProductView({
    super.key,
    super.routeObserver,
    required this.productRepository,
  });

  @override
  State<ProductView> createState() => _ProductViewState(
        ProductController(
          ProductPresenter(
            productRepository: productRepository,
          ),
        ),
      );
}

class _ProductViewState extends CleanViewState<ProductView, ProductController> {
  _ProductViewState(super.controller);

  @override
  Widget get view {
    return Scaffold(
      key: globalKey,
      appBar: AppBar(
        title: const Text('Product'),
      ),
      body: ControlledWidgetBuilder<ProductController>(
        builder: (context, controller) {
          return Container();
        },
      ),
    );
  }
}
```

### Generated Presenter

```dart
class ProductPresenter extends Presenter {
  final ProductRepository productRepository;

  late final GetProductUseCase _getProduct;
  late final GetProductListUseCase _getProductList;

  ProductPresenter({
    required this.productRepository,
  }) {
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

### Generated Controller

The controller generation differs based on whether you use the `--state` flag:

#### Without `--state` flag (Basic Controller)

```dart
class ProductController extends Controller {
  final ProductPresenter _presenter;

  ProductController(this._presenter);

  Future<void> getProduct(String id) async {
    final result = await _presenter.getProduct(id);
    result.fold(
      (entity) {},
      (failure) {},
    );
  }

  Future<void> getProductList() async {
    final result = await _presenter.getProductList();
    result.fold(
      (list) {},
      (failure) {},
    );
  }

  @override
  void onDisposed() {
    _presenter.dispose();
    super.onDisposed();
  }
}
```

**Key points:**
- Methods are generated but don't manage state
- Empty `result.fold()` handlers - you implement custom logic
- No state imports or mixins
- Useful for custom state management solutions

#### With `--state` flag (Stateful Controller)

```dart
class ProductController extends Controller with StatefulController<ProductState> {
  final ProductPresenter _presenter;

  ProductController(this._presenter) : super();

  @override
  ProductState createInitialState() => const ProductState();

  Future<void> getProduct(String id) async {
    updateState(viewState.copyWith(isGetting: true));
    final result = await _presenter.getProduct(id);

    result.fold(
      (entity) => updateState(viewState.copyWith(isGetting: false)),
      (failure) => updateState(viewState.copyWith(
        isGetting: false,
        error: failure,
      )),
    );
  }

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

  @override
  void onDisposed() {
    _presenter.dispose();
    super.onDisposed();
  }
}
```

**Key points:**
- Uses `StatefulController<ProductState>` mixin
- Implements `createInitialState()` to provide initial state
- Methods automatically update state with granular loading indicators
- State imports included
- Error handling built-in
- `viewState` provides type-safe state access

#### Watch Methods (Stream-based)

For `watch` and `watchList` methods, the generated code uses `.listen()` since they return Streams:

```dart
// Without --state
void watchProduct(String id) {
  _presenter.watchProduct(id).listen(
    (result) {
      result.fold(
        (entity) {},
        (failure) {},
      );
    },
  );
}

// With --state
void watchProduct(String id) {
  updateState(viewState.copyWith(isWatching: true));
  _presenter.watchProduct(id).listen(
    (result) {
      result.fold(
        (entity) => updateState(viewState.copyWith(isWatching: false)),
        (failure) => updateState(viewState.copyWith(
          isWatching: false,
          error: failure,
        )),
      );
    },
  );
}
```

## Data Layer Generation

Generate the data layer with DataSource interface and DataRepository implementation.

```bash
zfa generate Product --methods=get,getList,create,update,delete --data
```

Generates:

```
lib/src/
├── domain/
│   └── repositories/
│       └── product_repository.dart      # Abstract interface
└── data/
    ├── data_sources/product/
    │   └── product_data_source.dart     # Abstract DataSource
    └── repositories/
        └── data_product_repository.dart # Implementation
```

### Generated DataSource

```dart
abstract class ProductDataSource {
  Future<Product> get(String id);
  Future<List<Product>> getList();
  Future<Product> create(Product product);
  Future<Product> update(Product product);
  Future<void> delete(String id);
}
```

### Generated DataRepository

```dart
class DataProductRepository implements ProductRepository {
  final ProductDataSource _dataSource;

  DataProductRepository(this._dataSource);

  @override
  Future<Product> get(String id) {
    return _dataSource.get(id);
  }

  @override
  Future<List<Product>> getList() {
    return _dataSource.getList();
  }

  // ... all methods delegate to _dataSource
}
```

## AI Agent Integration

The CLI is designed to be AI-agent friendly with machine-readable I/O.

### JSON Output Format

```bash
zfa generate Product --methods=get,getList --format=json
```

Output:

```json
{
  "success": true,
  "name": "Product",
  "generated": [
    {
      "type": "repository",
      "path": "lib/src/domain/repositories/product_repository.dart",
      "action": "created"
    },
    {
      "type": "usecase",
      "path": "lib/src/domain/usecases/product/get_product_usecase.dart",
      "action": "created"
    }
  ],
  "errors": [],
  "next_steps": [
    "Implement ProductRepositoryImpl in data layer",
    "Register repositories with DI container"
  ]
}
```

### Reading from stdin

AI agents can pipe JSON directly:

```bash
echo '{"name":"Product","methods":["get","getList"],"repository":true}' | \
  zfa generate Product --from-stdin --format=json
```

### Getting the Schema

For validation before calling:

```bash
zfa schema
```

### Dry Run

Preview what would be generated:

```bash
zfa generate Product --methods=get,getList --dry-run --format=json
```

### Quiet Mode

For scripting, suppress all output except errors:

```bash
zfa generate Product --methods=get,getList --quiet
```

## JSON Configuration

Instead of command-line flags, you can use a JSON configuration file.

### Entity-Based Configuration

```json
{
  "name": "Product",
  "methods": ["get", "getList", "create", "update", "delete", "watchList"],
  "repository": true,
  "vpc": true,
  "data": true,
  "id_type": "String"
}
```

```bash
zfa generate Product -j product.json
```

### Custom UseCase Configuration

```json
{
  "name": "ProcessOrder",
  "type": "usecase",
  "repo": ["OrderRepository"],
  "params": "OrderRequest",
  "returns": "OrderResult"
}
```

### Full Schema

Run `zfa schema` to get the complete JSON schema.

## Generated State Object

When using the `--state` flag, ZFA generates an immutable state class with granular loading states for each method. This provides better control over UI loading indicators and prevents conflicting states.

### State Fields

The generated state includes:

| Field | Type | Description |
|-------|------|-------------|
| `{entity}List` | `List<Entity>` | List of entities |
| `error` | `AppFailure?` | Current error, if any |
| `isGetting` | `bool` | Whether `get` operation is in progress |
| `isGettingList` | `bool` | Whether `getList` operation is in progress |
| `isCreating` | `bool` | Whether `create` operation is in progress |
| `isUpdating` | `bool` | Whether `update` operation is in progress |
| `isDeleting` | `bool` | Whether `delete` operation is in progress |
| `isWatching` | `bool` | Whether `watch` operation is in progress |
| `isWatchingList` | `bool` | Whether `watchList` operation is in progress |
| `isLoading` | `bool` (getter) | Computed: `true` if any operation is loading |
| `hasError` | `bool` (getter) | Computed: `true` if error exists |

### Example Generated State

```dart
// Generated by zfa
// zfa generate Product --methods=get,getList,create,update,delete --vpc --state

class ProductState {
  final List<Product> productList;
  final AppFailure? error;
  final bool isGetting;
  final bool isGettingList;
  final bool isCreating;
  final bool isUpdating;
  final bool isDeleting;
  final bool isWatching;
  final bool isWatchingList;

  const ProductState({
    this.productList = const [],
    this.error,
    this.isGetting = false,
    this.isGettingList = false,
    this.isCreating = false,
    this.isUpdating = false,
    this.isDeleting = false,
    this.isWatching = false,
    this.isWatchingList = false,
  });

  // Computed getter - true if any operation is loading
  bool get isLoading =>
    isGetting || isGettingList || isCreating ||
    isUpdating || isDeleting || isWatching || isWatchingList;

  bool get hasError => error != null;

  ProductState copyWith({
    List<Product>? productList,
    AppFailure? error,
    bool clearError = false,
    bool? isGetting,
    bool? isGettingList,
    bool? isCreating,
    bool? isUpdating,
    bool? isDeleting,
    bool? isWatching,
    bool? isWatchingList,
  }) {
    return ProductState(
      productList: productList ?? this.productList,
      error: clearError ? null : (error ?? this.error),
      isGetting: isGetting ?? this.isGetting,
      isGettingList: isGettingList ?? this.isGettingList,
      isCreating: isCreating ?? this.isCreating,
      isUpdating: isUpdating ?? this.isUpdating,
      isDeleting: isDeleting ?? this.isDeleting,
      isWatching: isWatching ?? this.isWatching,
      isWatchingList: isWatchingList ?? this.isWatchingList,
    );
  }
}
```

### State Management

**Note:** State is managed by the Controller, not the Presenter. When using the `--state` flag with `--vpc`:

- The generated `Controller` includes the `StatefulController<ProductState>` mixin
- State updates happen automatically in each method
- Use `viewState` in your View to access the current state
- The Presenter focuses purely on business logic coordination

See the [Generated Controller](#generated-controller) section above for complete examples.

## Examples

### Complete CRUD with Full Stack

```bash
zfa generate Product \
  --methods=get,getList,create,update,delete,watch,watchList \
  --data \
  --vpc \
  --state \
  --test
```

### Entity-Based with Caching

```bash
zfa generate Config \
  --methods=get,getList \
  --data \
  --cache \
  --cache-policy=daily
```

### Custom UseCase with Repository

```bash
# Single repository UseCase
zfa generate SearchProduct \
  --domain=search \
  --repo=Product \
  --params=Query \
  --returns=List<Product>

# Stream UseCase
zfa generate WatchProduct \
  --domain=product \
  --repo=Product \
  --params=String \
  --returns=Stream<Product> \
  --type=stream
```

### Orchestrator Pattern

```bash
# Compose multiple UseCases
zfa generate ProcessCheckout \
  --domain=checkout \
  --usecases=ValidateCart,ProcessPayment,CreateOrder \
  --params=CheckoutRequest \
  --returns=OrderResult
```

### Polymorphic Pattern

```bash
# Generate abstract + variants + factory
zfa generate SparkSearch \
  --domain=search \
  --variants=Barcode,Url,Text \
  --repo=Search \
  --params=String \
  --returns=Stream<SearchResult> \
  --type=stream
```

### Append to Existing Repository

```bash
# Add new method to existing repository
zfa generate ListenToNotifications \
  --domain=customer \
  --repo=Customer \
  --params=String \
  --returns=Stream<Notification> \
  --type=stream \
  --append
```

### With Mock Data and DI

```bash
zfa generate Product \
  --methods=get,getList,create \
  --data \
  --mock \
  --di \
  --test
```

### Overwrite Existing Files

```bash
zfa generate Product --methods=get,getList --force
```

### Custom Output Directory

```bash
zfa generate Product --methods=get,getList --output=lib/features/product
```

### Custom ID Type

```bash
zfa generate Product --methods=get,delete --id-type=int
```

## Generated File Structure

After running all generation options, your project will have:

```
lib/src/
├── domain/
│   ├── entities/
│   │   └── product/
│   │       └── product.dart              # You create this
│   ├── repositories/
│   │   └── product_repository.dart       # Generated interface
│   └── usecases/
│       └── product/
│           ├── get_product_usecase.dart
│           ├── get_product_list_usecase.dart
│           ├── create_product_usecase.dart
│           ├── update_product_usecase.dart
│           ├── delete_product_usecase.dart
│           └── watch_product_list_usecase.dart
├── data/
│   ├── data_sources/
│   │   └── product/
│   │       └── product_data_source.dart  # Generated interface
│   └── repositories/
│       └── data_product_repository.dart  # Generated implementation
└── presentation/
    └── pages/
        └── product/
            ├── product_view.dart
            ├── product_presenter.dart
            └── product_controller.dart
```

## Troubleshooting

### Entity Not Found Errors

Make sure your entity exists at the expected path:

```
lib/src/domain/entities/{entity_snake}/{entity_snake}.dart
```

For `Product`, the path should be:

```
lib/src/domain/entities/product/product.dart
```

### Import Errors

If you see import errors after generation, ensure:

1. The entity file exists and exports the entity class
2. Run `flutter pub get` if dependencies are missing
3. Repository interface is automatically generated for entity-based operations

### Overwriting Files

By default, the CLI skips existing files. Use `--force` to overwrite:

```bash
zfa generate Product --methods=get,getList --force
```

## Next Steps

After generating code:

1. **Implement DataSource**: Create a concrete implementation of the DataSource (e.g., `RemoteProductDataSource`, `LocalProductDataSource`)
2. **Register with DI**: Register your repositories and data sources with your dependency injection container
3. **Customize Views**: Fill in the placeholder UI in generated views
4. **Add Business Logic**: Implement any TODO sections in generated UseCases
