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

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  zuraffa: ^1.0.0
```

Then run:

```bash
flutter pub get
```

## Quick Start

### 1. Generate Code with the CLI

The easiest way to get started is using the `zfa` CLI:

```bash
# Activate the CLI
dart pub global activate zuraffa

# Generate a complete feature with UseCases, Repository, Controller, and View
zfa generate Product --methods=get,getList,create,update,delete --repository --vpc

# Or use the shorter alias
dart run zuraffa:zfa generate Product --methods=get,getList --repository
```

### 2. Use a Controller

```dart
class ProductPage extends CleanView {
  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends CleanViewState<ProductPage, ProductController> {
  _ProductPageState() : super(ProductController(repository: getIt()));

  @override
  void onInitState() {
    super.onInitState();
    controller.loadProducts();
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
            itemCount: controller.viewState.products.length,
            itemBuilder: (context, index) {
              final product = controller.viewState.products[index];
              return ListTile(title: Text(product.name));
            },
          );
        },
      ),
    );
  }
}
```

## Core Concepts

### Result Type

All operations return `Result<T, AppFailure>` for type-safe error handling:

```dart
final result = await getUserUseCase('user-123');

// Pattern matching with fold
result.fold(
  (user) => showUser(user),
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
// params.validate(['id', 'name', 'status']); <-- Auto-generated from Entity
await updateCustomer(id: '123', data: {'name': 'New Name'});
```

#### 2. Typed Updates with Morphy (`--morphy`)
If you use [Morphy](https://pub.dev/packages/morphy) or similar tools, you can use typed Patch objects for full type safety.

```bash
zfa generate Customer --methods=update --morphy
```

```dart
// Generated with --morphy
await updateCustomer(id: '123', data: CustomerPatch(name: 'New Name'));
```

### UseCase Types

#### Single-shot UseCase

For operations that return once:

```dart
class GetUserUseCase extends UseCase<User, String> {
  final UserRepository _repository;

  GetUserUseCase(this._repository);

  @override
  Future<User> execute(String userId, CancelToken? cancelToken) async {
    return _repository.getUser(userId);
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

### Controller

Manages UI state and coordinates UseCases:

```dart
class ProductController extends Controller {
  final GetProductsUseCase _getProducts;

  ProductState _viewState = const ProductState();
  ProductState get viewState => _viewState;

  ProductController({required ProductRepository repository})
      : _getProducts = GetProductsUseCase(repository);

  Future<void> loadProducts() async {
    _setState(_viewState.copyWith(isLoading: true));

    final result = await _getProducts.call(const NoParams());

    result.fold(
      (products) => _setState(_viewState.copyWith(
        products: products,
        isLoading: false,
      )),
      (failure) => _setState(_viewState.copyWith(
        error: failure,
        isLoading: false,
      )),
    );
  }

  void _setState(ProductState newState) {
    _viewState = newState;
    refreshUI();
  }
}
```

### CleanView

Base class for views with automatic lifecycle management:

```dart
class ProductPage extends CleanView {
  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends CleanViewState<ProductPage, ProductController> {
  _ProductPageState() : super(ProductController(repository: getIt()));

  @override
  Widget get view {
    return Scaffold(
      key: globalKey, // Important: use globalKey on root widget
      body: YourBodyWidget(),
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

```bash
# Generate UseCases for an entity
zfa generate Product --methods=get,getList,create,update,delete --repository

# Add presentation layer (View, Presenter, Controller)
zfa generate Product --methods=get,getList --repository --vpc

# Add data layer (DataRepository + DataSource)
zfa generate Product --methods=get,getList --repository --data

# Use typed patches for updates (Morphy support)
zfa generate Product --methods=update --morphy

# Generate everything at once
zfa generate Product --methods=get,getList,create --repository --vpc --data

# Custom UseCase
zfa generate ProcessOrder --repos=OrderRepo,PaymentRepo --params=OrderRequest --returns=OrderResult
```

### Available Methods

| Method   | UseCase Type      | Description                     |
|----------|-------------------|---------------------------------|
| `get`    | UseCase           | Get single entity by ID         |
| `getList`| UseCase           | Get all entities                |
| `create` | UseCase           | Create new entity               |
| `update` | UseCase           | Update existing entity          |
| `delete` | CompletableUseCase| Delete entity by ID             |
| `watch`  | StreamUseCase     | Watch single entity             |
| `watchList`| StreamUseCase   | Watch all entities              |

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

Recommended folder structure for Clean Architecture:

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
    │   ├── datasources/         # Remote and local data sources
    │   ├── models/              # DTOs, JSON serialization
    │   └── repositories/        # Repository implementations
    │
    ├── domain/                  # Domain layer (pure Dart)
    │   ├── entities/            # Business objects
    │   ├── repositories/        # Repository interfaces
    │   └── usecases/            # Business logic
    │
    └── presentation/            # Presentation layer
        ├── pages/               # Full-screen views
        │   ├── home/
        │   │   ├── home_page.dart
        │   │   ├── home_controller.dart
        │   │   └── home_state.dart
        │   └── ...
        └── widgets/             # Reusable widgets
```

## Advanced Features

### CancelToken

Cooperative cancellation for long-running operations:

```dart
// Create a token
final cancelToken = CancelToken();

// Use with a use case
final result = await getUserUseCase(userId, cancelToken: cancelToken);

// Cancel when needed
cancelToken.cancel('User navigated away');

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
