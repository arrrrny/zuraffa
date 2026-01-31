#  🦒 Zuraffa

[![Pub Version](https://img.shields.io/pub/v/zuraffa)](https://pub.dev/packages/zuraffa)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

A comprehensive Clean Architecture framework for Flutter applications with **Result-based error handling**, **type-safe failures**, and **minimal boilerplate**.

## What is Zuraffa?

 🦒 Zuraffa (Zürafa means Giraffe in Türkçe) is a modern Flutter package that implements Clean Architecture principles with a focus on developer experience and type safety. It provides a robust set of tools for building scalable, testable, and maintainable Flutter applications.

### Key Features

- ✅ **Result Type**: Type-safe error handling with `Result<T, AppFailure>`
- ✅ **Sealed Failures**: Exhaustive pattern matching for error cases
- ✅ **UseCase Pattern**: Single-shot, streaming, and background operations
- ✅ **Controller**: Simple state management with automatic cleanup
- ✅ **CLI Tool**: Generate boilerplate code with `zfa` command
- ✅ **MCP Server**: AI/IDE integration via Model Context Protocol
- ✅ **Cancellation**: Cooperative cancellation with `CancelToken`
- ✅ **Fine-grained Rebuilds**: Optimize performance with selective widget updates
- ✅ **Caching**: Built-in dual datasource pattern with flexible cache policies

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  zuraffa: ^1.10.0
```

Then run:

```bash
flutter pub get
```

## Quick Start

### 1. Generate Code with the CLI

The easiest way to get started is using the `zfa` CLI. **One command generates your entire feature:**

```bash
# Activate the CLI
dart pub global activate zuraffa

# Generate a complete feature with one line of code
# This creates 14 files: UseCases, Repository, DataSource, Presenter, Controller, State, and View
zfa generate Product --methods=get,watch,create,update,delete,getList,watchList --repository --data --vpc --state --test

# Or use the shorter alias
dart run zuraffa:zfa generate Product --methods=get,getList --repository --vpc --state
```

**That's it!** One command generates:
- ✅ Domain layer (UseCases + Repository interface)
- ✅ Data layer (DataRepository + DataSource)
- ✅ Presentation layer (View, Presenter, Controller, State)

### 2. Use the Generated Code

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
✅ Generated 21 files for Product

  ⟳ lib/src/domain/repositories/product_repository.dart
  ⟳ lib/src/domain/usecases/product/get_product_usecase.dart
  ⟳ lib/src/domain/usecases/product/watch_product_usecase.dart
  ⟳ lib/src/domain/usecases/product/create_product_usecase.dart
  ⟳ lib/src/domain/usecases/product/update_product_usecase.dart
  ⟳ lib/src/domain/usecases/product/delete_product_usecase.dart
  ⟳ lib/src/domain/usecases/product/get_product_list_usecase.dart
  ⟳ lib/src/domain/usecases/product/watch_product_list_usecase.dart
  ⟳ lib/src/presentation/pages/product/product_presenter.dart
  ⟳ lib/src/presentation/pages/product/product_controller.dart
  ⟳ lib/src/presentation/pages/product/product_view.dart
  ⟳ lib/src/presentation/pages/product/product_state.dart
  ⟳ lib/src/data/data_sources/product/product_data_source.dart
  ⟳ lib/src/data/repositories/data_product_repository.dart
  ✓ test/domain/usecases/product/get_product_usecase_test.dart
  ✓ test/domain/usecases/product/watch_product_usecase_test.dart
  ✓ test/domain/usecases/product/create_product_usecase_test.dart
  ✓ test/domain/usecases/product/update_product_usecase_test.dart
  ✓ test/domain/usecases/product/delete_product_usecase_test.dart
  ✓ test/domain/usecases/product/get_product_list_usecase_test.dart
  ✓ test/domain/usecases/product/watch_product_list_usecase_test.dart

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

#### 2. Typed Updates with Morphy (`--morphy`)
If you use [Morphy](https://pub.dev/packages/morphy) or similar tools, you can use typed Patch objects for full type safety.

```bash
zfa generate Product --methods=update --morphy
```

```dart
// Generated with --morphy
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

## CLI Tool

Zuraffa includes a powerful CLI tool (`zfa`) for generating boilerplate code.

### Installation

```bash
# Global activation
dart pub global activate zuraffa

# Or run directly
dart run zuraffa:zfa
```

### Basic Usage

**One command generates your entire feature:**

```bash
# Generate everything at once - Domain, Data, and Presentation layers
zfa generate Product --methods=get,getList,create,update,delete --repository --data --vpc --state

# Or generate incrementally:

# Generate UseCases + Repository interface
zfa generate Product --methods=get,getList,create,update,delete --repository

# Add presentation layer (View, Presenter, Controller, State)
zfa generate Product --methods=get,getList,create,update,delete --repository --vpc --state

# Add data layer (DataRepository + DataSource)
zfa generate Product --methods=get,getList,create,update,delete --repository --data

# Use typed patches for updates (Morphy support)
zfa generate Product --methods=update --morphy

# Enable caching with dual datasources
zfa generate Config --methods=get,getList --repository --data --cache --cache-policy=daily

# Preview what would be generated without writing files
zfa generate Product --methods=get,getList --repository --dry-run

# Generate with unit tests for each UseCase
zfa generate Product --methods=get,create,update,delete --repository --test

# Generate in a subfolder (e.g., for auth-related entities)
zfa generate Session --methods=get,create --repository --subfolder=auth

# Custom UseCase with multiple repositories
zfa generate PublishProduct --repos=ProductRepository,CategoryRepository --params=PublishProductRequest --returns=PublishedProduct

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

# Complex types with multiple repositories
zfa generate ProcessCheckout --repos=CartRepository,PaymentRepository --params=CheckoutRequest --returns=OrderConfirmation
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
| `--repository` | Generate repository interface                         |
| `--data`       | Generate DataRepository and DataSource                |
| `--vpc`        | Generate View, Presenter, and Controller              |
| `--state`      | Generate immutable State class                        |
| `--morphy`     | Use typed Patch objects for updates                   |
| `--cache`      | Enable caching with dual datasources (remote + local) |
| `--cache-policy` | Cache expiration: daily, restart, ttl (default: daily) |
| `--cache-storage` | Local storage hint: hive, sqlite, shared_preferences |
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

### Running the MCP Server

```bash
# Compile for faster startup
dart compile exe bin/zuraffa_mcp_server.dart -o zuraffa_mcp_server

# Run the server
./zuraffa_mcp_server
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
zfa generate Product --methods=get,getList,create,update,delete --repository --data --vpc --state
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
