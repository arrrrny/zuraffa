# AI Agents Guide for Zuraffa

This document provides comprehensive guidance for AI agents working with Zuraffa projects, covering all features and best practices.

## Introduction to Zuraffa

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
- ✅ **Dependency Injection Generation**: Automated DI setup with get_it
- ✅ **Mock Data Generation**: Realistic mock data for testing and UI previews
- ✅ **Testing Support**: Unit test generation for all UseCases

## Architecture Overview

```
lib/src/
├── domain/                    # Business logic layer (pure Dart)
│   ├── entities/              # Business objects
│   ├── repositories/          # Repository interfaces (contracts)
│   └── usecases/              # Business operations
├── data/                      # Data layer (external dependencies)
│   ├── datasources/          # Data source interfaces & implementations
│   └── repositories/          # Repository implementations
└── presentation/              # UI layer (Flutter)
    └── pages/
        └── {feature}/
            ├── {feature}_view.dart
            ├── {feature}_presenter.dart
            └── {feature}_controller.dart
```

### Entity Location Convention

Entities MUST be at:
```
lib/src/domain/entities/{entity_snake}/{entity_snake}.dart
```

Example for `Product`:
```
lib/src/domain/entities/product/product.dart
```

## ZFA CLI Tool - Complete Reference

The `zfa` (Zuraffa) CLI is a powerful code generator that creates Clean Architecture boilerplate code from simple command-line flags or JSON input. It's designed to be **AI-agent friendly** with machine-readable output formats.

### Installation

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

### Quick Start

Generate a complete CRUD stack for an entity:

```bash
# Basic CRUD with repository
zfa generate Product --methods=get,getList,create,update,delete

# With VPC layer (View, Presenter, Controller)
zfa generate Product --methods=get,getList,create,update,delete --vpcs

# With data layer (DataRepository + DataSource)
zfa generate Product --methods=get,getList,create,update,delete --data

# Complete feature with state management, caching, DI, and tests
zfa generate Product --methods=get,getList,create,update,delete,watchList --data --vpcs --state --cache --di --test

# Complete feature with GraphQL generation
zfa generate Product --methods=get,getList,create,update,delete --data --gql --gql_returns="id,name,description,price,isActive,createdAt"
```

### Entity-Based Generation

Entity-based generation creates UseCases that operate on a specific entity type.

#### Available Methods

| Method | UseCase Type | Description |
|--------|--------------|-------------|
| `get` | `UseCase` | Get single entity by ID |
| `getList` | `UseCase` | Get all entities |
| `create` | `UseCase` | Create new entity |
| `update` | `UseCase` | Update existing entity |
| `delete` | `CompletableUseCase` | Delete entity by ID |
| `watch` | `StreamUseCase` | Watch single entity changes |
| `watchList` | `StreamUseCase` | Watch all entities changes |

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
| `--gql` | | Generate GraphQL query/mutation/subscription files |
| `--gql-type=<type>` | | GraphQL operation type: query, mutation, subscription (default: auto) |
| `--gql-returns=<fields>` | | GraphQL return fields (comma-separated) |
| `--gql-input-type=<type>` | | GraphQL input type name |
| `--gql-input-name=<name>` | | GraphQL input variable name |
| `--gql-name=<name>` | | Custom GraphQL operation name |

**Note:** Repository interface is automatically generated for entity-based operations.

### Custom UseCase Generation

Create standalone UseCases without an entity, useful for complex business operations.

#### Custom UseCase Options

| Flag | Description |
|------|-------------|
| `--repo=<name>` | Repository to inject (single, enforces SRP) |
| `--service=<name>` | Service to inject (alternative to `--repo`) |
| `--domain=<name>` | Domain folder (required for custom UseCases) |
| `--method=<name>` | Dependency method name (default: auto from UseCase name) |
| `--service-method=<name>` | Service method name (default: auto from UseCase name) |
| `--append` | Append to existing repository or service |
| `--usecases=<list>` | Orchestrator: compose UseCases (comma-separated) |
| `--variants=<list>` | Polymorphic: generate variants (comma-separated) |
| `--type=<type>` | UseCase type: `usecase`, `stream`, `background`, `completable` |
| `--params=<type>` | Params type (default: `NoParams`) |
| `--returns=<type>` | Return type (default: `void`) |

#### UseCase Types

| Type | Description | Use When |
|------|-------------|----------|
| `usecase` | Single request-response operations | CRUD, API calls |
| `stream` | Real-time data, WebSocket, Firebase listeners | Reactive data streams |
| `background` | CPU-intensive work (image processing, crypto) | Heavy computations on isolates |
| `completable` | Operations that don't return a value | Delete, logout, clear cache |

### VPC Layer Generation

Generate the presentation layer with View, Presenter, and Controller.

| Flag | Description |
|------|-------------|
| `--vpcs` | Generate View + Presenter + Controller |
| `--vpcs` | Generate View, Presenter, Controller, and State |
| `--pc` | Generate Presenter + Controller only (preserve View) |
| `--pcs` | Generate Presenter, Controller, and State (preserve View) |
| `--state` | Generate State object with granular loading states |

### Advanced Generation Features

#### Caching with Dual DataSource Pattern

| Flag | Description |
|------|-------------|
| `--cache` | Enable caching with dual datasources (remote + local) |
| `--cache-policy` | Cache expiration: daily, restart, ttl (default: daily) |
| `--cache-storage` | Local storage hint: hive, sqlite, shared_preferences (default: hive) |
| `--ttl` | TTL duration in minutes (default: 1440 = 24 hours) |

#### Mock Data Generation

| Flag | Description |
|------|-------------|
| `--mock` | Generate mock data files alongside other layers |
| `--mock-data-only` | Generate only mock data files (no other layers) |

#### Dependency Injection Generation

| Flag | Description |
|------|-------------|
| `--di` | Generate dependency injection files (get_it) |
| `--use-mock` | Use mock datasource in DI (default: remote datasource) |

#### Additional Features

| Flag | Description |
|------|-------------|
| `--init` | Add initialize method & isInitialized stream to repos |
| `--test` | Generate unit tests for each UseCase |
| `--subfolder` | Organize under a subfolder (e.g., `--subfolder=auth`) |

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

#### GraphQL Generation Options

| Flag | Description |
|------|-------------|
| `--gql` | Enable GraphQL query/mutation/subscription generation |
| `--gql-type=<type>` | GraphQL operation type: query, mutation, subscription |
| `--gql-returns=<fields>` | Return fields as comma-separated string |
| `--gql-input-type=<type>` | GraphQL input type name |
| `--gql-input-name=<name>` | GraphQL input variable name (default: input) |
| `--gql-name=<name>` | Custom GraphQL operation name |

### Initialize Command

The quickest way to get started is with the `initialize` command:

```bash
# Create a sample Product entity with common fields
zfa initialize

# Create a different entity
zfa initialize --entity=User

# Preview without writing files
zfa initialize --dry-run

# Specify custom output directory
zfa initialize --entity=Order --output=lib/src
```

The `initialize` command creates a sample entity with realistic fields:
- `id` (String) - Unique identifier
- `name` (String) - Display name
- `description` (String) - Detailed description
- `price` (double) - Numeric value
- `category` (String) - Classification
- `isActive` (bool) - Status flag
- `createdAt` (DateTime) - Creation timestamp
- `updatedAt` (DateTime?) - Optional update timestamp

### GraphQL Generation

Generate GraphQL query/mutation/subscription files for your entities and UseCases.

#### Entity-Based GraphQL Generation

```bash
# Basic GraphQL with auto-generated queries
zfa generate Product --methods=get,getList --gql

# With custom return fields
zfa generate Product --methods=get,getList,create --gql --gql-returns="id,name,price,category,isActive,createdAt"

# With custom operation types
zfa generate Product --methods=watch,watchList --gql --gql-type=subscription

# Complete GraphQL setup
zfa generate Product --methods=get,getList,create,update,delete --data --gql --gql-returns="id,name,description,price,category,isActive,createdAt,updatedAt"
```

Generated files are placed in:
```
lib/src/data/datasources/{entity}/graphql/
├── get_product_query.dart
├── get_product_list_query.dart
├── create_product_mutation.dart
└── update_product_mutation.dart
```

#### Custom UseCase with GraphQL

```bash
# Custom UseCase with GraphQL query
zfa generate SearchProducts \
  --service=Search \
  --domain=products \
  --params=SearchQuery \
  --returns=List<Product> \
  --gql \
  --gql-type=query \
  --gql-name=searchProducts \
  --gql-input-type=SearchInput \
  --gql-returns="id,name,price,category"

# Custom UseCase with GraphQL mutation
zfa generate UploadFile \
  --service=Storage \
  --domain=storage \
  --params=FileData \
  --returns=String \
  --gql \
  --gql-type=mutation \
  --gql-name=uploadFile \
  --gql-input-type=FileInput

# Custom UseCase with GraphQL subscription
zfa generate WatchUserLocation \
  --service=Location \
  --domain=realtime \
  --params=UserId \
  --returns=Location \
  --gql \
  --gql-type=subscription
```

#### GraphQL Options

| Flag | Description |
|------|-------------|
| `--gql` | Enable GraphQL generation |
| `--gql-type` | Operation type: query, mutation, subscription (auto-detected for entity methods) |
| `--gql-returns` | Return fields as comma-separated string |
| `--gql-input-type` | Input type name for mutation/subscription |
| `--gql-input-name` | Input variable name (default: input) |
| `--gql-name` | Custom operation name (default: auto-generated) |

**Auto-Detection for Entity Methods:**
- `get`, `getList` → query
- `create`, `update`, `delete` → mutation
- `watch`, `watchList` → subscription

#### JSON Configuration

Instead of command-line flags, you can use a JSON configuration file.

#### Entity-Based Configuration

```json
{
  "name": "Product",
  "methods": ["get", "getList", "create", "update", "delete", "watchList"],
  "repository": true,
  "vpc": true,
  "data": true,
  "id_type": "String",
  "cache": true,
  "cache_policy": "daily",
  "di": true,
  "test": true
}
```

#### JSON Configuration with GraphQL

```json
{
  "name": "Product",
  "methods": ["get", "getList", "create", "update", "delete"],
  "repository": true,
  "data": true,
  "gql": true,
  "gql_returns": "id,name,description,price,category,isActive,createdAt,updatedAt",
  "di": true
}
```

```json
{
  "name": "SearchProducts",
  "service": "Search",
  "domain": "products",
  "params": "SearchQuery",
  "returns": "List<Product>",
  "gql": true,
  "gql_type": "query",
  "gql_name": "searchProducts",
  "gql_input_type": "SearchInput",
  "gql_returns": "id,name,price,category,rating",
  "data": true
}
```

```bash
zfa generate Product -j product.json
```

### AI Agent Integration

The CLI is designed to be AI-agent friendly with machine-readable I/O.

#### JSON Output Format

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
    "Implement DataProductRepository in data layer",
    "Register repositories with DI container"
  ]
}
```

#### Reading from stdin

AI agents can pipe JSON directly:

```bash
echo '{"name":"Product","methods":["get","getList"],"repository":true}' | \
  zfa generate Product --from-stdin --format=json
```

#### Getting the Schema

For validation before calling:

```bash
zfa schema
```

#### Dry Run

Preview what would be generated:

```bash
zfa generate Product --methods=get,getList --dry-run --format=json
```

## Core Patterns and Concepts

### UseCase Pattern

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

// Usage
final result = await getProductUseCase('id-123');
result.fold(
  (product) => print('Success: $product'),
  (failure) => print('Error: ${failure.message}'),
);
```

### Result Type

All UseCases return `Result<T, AppFailure>`:

```dart
// Pattern matching
switch (result) {
  case Success(:final value):
    print('Got: $value');
  case Failure(:final error):
    print('Error: ${error.message}');
}

// Fold
result.fold(
  (value) => handleSuccess(value),
  (failure) => handleError(failure),
);

// Get or default
final value = result.getOrElse(() => defaultValue);
```

### AppFailure Types

```dart
sealed class AppFailure {
  // Available subtypes:
  // - ServerFailure
  // - NetworkFailure
  // - ValidationFailure
  // - NotFoundFailure
  // - UnauthorizedFailure
  // - ForbiddenFailure
  // - TimeoutFailure
  // - CacheFailure
  // - ConflictFailure
  // - CancellationFailure
  // - UnknownFailure
}
```

### VPC Architecture

When `--vpcs` is used:
- **View** → Pure UI, uses `ControlledWidgetBuilder`
- **Controller** → Manages state, calls Presenter methods
- **Presenter** → Contains UseCases, orchestrates business logic

```
View → Controller → Presenter → UseCase → Repository
```

### State Management with StatefulController

When using the `--state` flag, controllers use `StatefulController<T>` with immutable state objects:

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
}
```

### CancelToken for Cooperative Cancellation

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

## Advanced Features

### Caching with Dual DataSource Pattern

Zuraffa's caching strategy uses the **Dual DataSource Pattern**:
- **Remote DataSource**: Fetches data from API/external service
- **Local DataSource**: Stores data in local storage (Hive, SQLite, etc.)
- **Repository**: Orchestrates between remote and local based on cache policy

#### Cache Policies

| Policy | Description | Use Case |
|--------|-------------|----------|
| `DailyCachePolicy` | Cache expires after 24 hours | Data that updates daily |
| `AppRestartCachePolicy` | Cache valid only during app session | Config data that rarely changes |
| `TtlCachePolicy` | Custom expiration duration | Fine-grained control |

### Dependency Injection Generation

Zuraffa can automatically generate dependency injection setup using get_it:

```bash
# Generate DI files alongside your code
zfa generate Product --methods=get,getList,create --data --vpcs --di

# Use mock datasource in DI (for development/testing)
zfa generate Product --methods=get,getList --data --mock --di --use-mock

# With caching enabled
zfa generate Product --methods=get,getList --data --cache --di
```

### Mock Data Generation

Zuraffa can generate realistic mock data for your entities:

```bash
# Generate mock data alongside other layers
zfa generate Product --methods=get,getList,create --vpcs --mock

# Generate only mock data files
zfa generate Product --mock-data-only
```

### MCP Server Integration

Zuraffa includes an MCP (Model Context Protocol) server for seamless integration with AI-powered development environments like Claude Desktop, Cursor, and VS Code.

#### Installation

```bash
dart pub global activate zuraffa
# MCP server is immediately available: zuraffa_mcp_server
```

#### MCP Tools

- `zuraffa_generate` - Generate Clean Architecture code
- `zuraffa_schema` - Get JSON schema for config validation
- `zuraffa_validate` - Validate a generation config

## File Naming Conventions

| Type | Pattern | Example |
|------|---------|---------|
| Entity | `{entity_snake}.dart` | `product.dart` |
| Repository | `{entity_snake}_repository.dart` | `product_repository.dart` |
| UseCase | `{action}_{entity_snake}_usecase.dart` | `get_product_usecase.dart` |
| DataSource | `{entity_snake}_datasource.dart` | `product_datasource.dart` |
| View | `{entity_snake}_view.dart` | `product_view.dart` |
| Presenter | `{entity_snake}_presenter.dart` | `product_presenter.dart` |
| Controller | `{entity_snake}_controller.dart` | `product_controller.dart` |
| State | `{entity_snake}_state.dart` | `product_state.dart` |

## Workflow for Adding Features

### Adding a New Entity

1. **Create Entity** (manual or use your preferred generator like freezed/zorphy)
   ```
   lib/src/domain/entities/product/product.dart
   ```

2. **Generate Domain + Data Layer**
   ```bash
   zfa generate Product --methods=get,getList,create,update,delete --data
   ```

3. **Generate Presentation Layer**
   ```bash
   zfa generate Product --methods=get,getList,create --vpcs --state --force
   ```

4. **Generate with Advanced Features**
   ```bash
   zfa generate Product --methods=get,getList,create,update,delete,watchList --data --vpcs --state --cache --di --test
   ```

5. **Implement DataSource** (create concrete implementation)

6. **Register with DI** (get_it, riverpod, etc.)

7. **Customize View UI**

### Adding a Method to Existing Entity

1. Run with only new methods and `--force`:
   ```bash
   zfa generate Product --methods=watch,watchList --force
   ```
2. Manually add new methods to Presenter if using VPC

### Creating Orchestrator UseCase

```bash
zfa generate ProcessCheckout \
  --domain=checkout \
  --usecases=ValidateCart,ProcessPayment,CreateOrder \
  --params=CheckoutRequest \
  --returns=OrderResult
```

### Debugging Generation Issues

```bash
# Dry run to see what would be generated
zfa generate Product --methods=get --dry-run --format=json

# Verbose mode
zfa generate Product --methods=get --verbose

# Validate JSON config
zfa validate config.json
```

## Common Tasks for AI Agents

### Entity-Based Generation

1. **Basic CRUD Generation:**
   ```bash
   zfa generate Product --methods=get,getList,create,update,delete
   ```

2. **Complete Feature with Presentation:**
   ```bash
   zfa generate Product --methods=get,getList,create,update,delete --vpcs --state
   ```

3. **Complete Feature with Data Layer:**
   ```bash
   zfa generate Product --methods=get,getList,create,update,delete --data
   ```

# Complete Feature with All Layers:
```bash
zfa generate Product --methods=get,getList,create,update,delete,watchList --data --vpcs --state --cache --di --test
```

### GraphQL Generation

1. **Generate GraphQL for Entity:**
   ```bash
   zfa generate Product --methods=get,getList,create --gql --gql-returns="id,name,price,category"
   ```

2. **Generate GraphQL for Custom UseCase:**
   ```bash
   zfa generate SearchProducts \
     --service=Search \
     --domain=products \
     --params=SearchQuery \
     --returns=List<Product> \
     --gql \
     --gql-type=query \
     --gql-name=searchProducts \
     --gql-input-type=SearchInput
   ```

3. **Complete GraphQL Setup:**
   ```bash
   zfa generate Product \
     --methods=get,getList,create,update,delete,watchList \
     --data \
     --gql \
     --gql-returns="id,name,description,price,category,isActive,createdAt,updatedAt" \
     --di
   ```

### Custom UseCase Generation

1. **Custom UseCase with Repository:**
   ```bash
   zfa generate SearchProduct --domain=search --repo=Product --params=Query --returns=List<Product>
   ```

2. **Custom UseCase with Service:**
   ```bash
   zfa generate ProcessPayment --domain=payment --service=Payment --params=PaymentRequest --returns=PaymentResult
   ```

3. **Stream UseCase with Service:**
   ```bash
   zfa generate WatchPrices --domain=pricing --service=PriceStream --type=stream --params=ProductId --returns=Price
   ```

4. **Background UseCase:**
   ```bash
   zfa generate ProcessImages --type=background --domain=processing --params=ImageBatch --returns=ProcessedImage
   ```

### Advanced Generation

1. **With Caching:**
   ```bash
   zfa generate Config --methods=get,getList --data --cache --cache-policy=daily
   ```

2. **With Mock Data:**
   ```bash
   zfa generate Product --methods=get,getList --mock
   ```

3. **With Dependency Injection:**
   ```bash
   zfa generate Product --methods=get,getList --data --vpcs --di
   ```

4. **With Tests:**
   ```bash
   zfa generate Product --methods=get,create,update,delete --test
   ```

### AI-Agent Friendly Commands

1. **JSON Output for Parsing:**
   ```bash
   zfa generate Product --methods=get,getList --format=json
   ```

2. **From stdin (pipe JSON):**
   ```bash
   echo '{"name":"Product","methods":["get","getList"]}' | zfa generate Product --from-stdin
   ```

3. **Get JSON schema:**
   ```bash
   zfa schema
   ```

4. **Dry run (preview):**
   ```bash
   zfa generate Product --methods=get --dry-run --format=json
   ```

## Understanding the Architecture

### Layer Dependencies

```
┌─────────────────────────────────────────┐
│           PRESENTATION LAYER            │
│    (View, Controller, Presenter)        │
└──────────────────┬──────────────────────┘
                   │ depends on
┌──────────────────▼──────────────────────┐
│             DOMAIN LAYER                │
│  (UseCase, Repository Interface, Entity)│
└──────────────────┬──────────────────────┘
                   │ depends on (inverted)
┌──────────────────▼──────────────────────┐
│              DATA LAYER                 │
│  (DataRepository, DataSource, Models)   │
└─────────────────────────────────────────┘
```

### Key Principles

1. **Domain is pure Dart** - No Flutter imports in domain layer
2. **Dependency Inversion** - Domain defines interfaces, data implements them
3. **Single Responsibility** - Each UseCase does one thing
4. **Result-based errors** - No thrown exceptions, use `Result<T, AppFailure>`
5. **Cooperative cancellation** - Use `CancelToken` for long operations

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

## Links

- [CLI Guide](./CLI_GUIDE.md) - Comprehensive CLI documentation
- [Caching Guide](./CACHING.md) - Dual datasource caching pattern
- [MCP Server](./MCP_SERVER.md) - MCP server setup and usage
- [README](./README.md) - Package overview and API reference
- [Example](./example) - Working example application

## Active Technologies
- YAML (extension definition), Dart/ZFA CLI + ZFA CLI (v4.0.0+), Speckit extension framework (003-speckit-cli-commands)
- N/A (no persistent data) (003-speckit-cli-commands)

## Recent Changes
- 003-speckit-cli-commands: Added YAML (extension definition), Dart/ZFA CLI + ZFA CLI (v4.0.0+), Speckit extension framework
