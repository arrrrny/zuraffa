# Getting Started

Get up and running with Zuraffa in minutes. This guide walks you through installation, your first entity, and generating a complete Clean Architecture stack with ZFA patterns.

## Installation

### 1. Add Dependency

Add Zuraffa to your `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  zuraffa: ^2.2.2
```

Run:

```bash
flutter pub get
```

### 2. Activate CLI

Activate the `zfa` command globally:

```bash
dart pub global activate zuraffa
```

Verify installation:

```bash
zfa --help
```

:::tip
If `zfa` is not found, ensure your Dart pub cache bin directory is in your PATH:
- macOS/Linux: `export PATH="$PATH":"$HOME/.pub-cache/bin"`
- Windows: Add `%LOCALAPPDATA%\Pub\Cache\bin` to your PATH
:::

---

## ZFA - Four Powerful Patterns

ZFA introduces four distinct patterns for organizing your business logic:

### 1. Entity-Based Pattern
Perfect for standard CRUD operations on entities:
```bash
zfa generate Product --methods=get,getList,create,update,delete --data --vpc
```

### 2. Single (Responsibility) Repository Pattern
One UseCase, one repository for focused business logic:
```bash
zfa generate ProcessCheckout --domain=checkout --repo=CheckoutRepository --params=Request --returns=Result
```

### 3. Orchestrator Pattern (NEW)
Compose multiple UseCases into complex workflows:
```bash
zfa generate ProcessCheckout --domain=checkout --usecases=ValidateCart,CreateOrder,ProcessPayment --params=Request --returns=Result
```

### 4. Polymorphic Pattern (NEW)
Generate abstract base + concrete variants + factory:
```bash
zfa generate SparkSearch --domain=search --variants=Barcode,Url,Text,Image --params=Spark --returns=Listing --type=stream
```

---

## Quick Start (5 Minutes)

### Step 1: Configure Your Project

Set up ZFA configuration for your project:

```bash
# Create configuration with defaults
zfa config init

# Optionally customize
zfa config set useZorphyByDefault true
zfa config set defaultEntityOutput lib/src/domain/entities
```

:::note
Entity generation requires `zorphy_annotation` in your project. If you haven't added it yet, ZFA will prompt you when you create your first entity:

```bash
dart pub add zorphy_annotation
```
:::

### Step 2: Create Your Entities

Define your data model with entities and enums. You have three options:

#### Option A: Create from JSON (Fastest!)

If you have JSON samples (e.g., from an API), create entities directly:

```bash
# From a JSON file
zfa entity from-json user_response.json

# From API documentation
cat > order.json << EOF
{
  "id": "123",
  "customer": {
    "id": "456",
    "name": "John Doe",
    "email": "john@example.com"
  },
  "status": "processing",
  "items": [
    {
      "product": {"id": "789", "name": "Widget", "price": 29.99},
      "quantity": 2
    }
  ],
  "total": 59.98,
  "createdAt": "2024-01-15T10:30:00Z"
}
EOF

zfa entity from-json order.json --name Order
```

This automatically creates all entities with proper types:
- `Order` with all fields
- `User` (nested from customer object)
- `Product` (nested from items array)
- `OrderItem` (for array items)
- Infers `DateTime` from ISO date strings
- Handles nullable fields from `null` values

#### Option B: Interactive Field Entry

Let ZFA prompt you for each field:

```bash
zfa entity create -n User

📝 Creating Zorphy Entity: User
Enter fields one by one. Press Enter without input to finish.

Field name (or press Enter to finish): id
Field type (e.g., String, int, List<String>, OrderStatus, \$Order): String?
✓ Added field: id (String?)

Field name (or press Enter to finish): name
Field type (e.g., String, int, List<String>, OrderStatus, \$Order): String
✓ Added field: name (String)

Field name (or press Enter to finish): [Press Enter]
```

#### Option C: Define Fields Inline

Specify all fields in one command:

```bash
# Create an enum
zfa entity enum -n OrderStatus --value pending,processing,shipped,delivered

# Create entities with fields
zfa entity create -n User --field name:String --field email:String?
zfa entity create -n Product --field name:String --field price:double --field description:String?
zfa entity create -n Order --field customer:\$User --field status:OrderStatus --field items:List<\$OrderItem>
zfa entity create -n OrderItem --field product:\$Product --field quantity:int
```


This creates entity files like:
```
lib/src/domain/entities/order/order.dart
lib/src/domain/entities/order/order.zorphy.dart
lib/src/domain/entities/order/order.g.dart
```

### Step 3: Run Code Generation

Generate the entity implementations:

```bash
zfa build
```

This generates:
- `copyWith`, `==`, `hashCode`, `toString` methods
- JSON serialization (`toJson`/`fromJson`)
- Typed patch classes for updates

### Step 4: Generate Clean Architecture

Generate all layers with one command:

```bash
zfa generate Order \
  --methods=get,getList,create,update,delete,watch,watchList \
  --data \
  --vpc \
  --state \
  --di \
  --test
```

This generates **21 files**:

```
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
   • Create a DataSource that implements OrderDataSource in data layer
   • Register repositories with DI container
   • Run tests: flutter test
```

### Step 3: Implement DataSource

Create a concrete implementation:

```dart
// lib/src/data/data_sources/product/product_remote_data_source.dart
import 'package:zuraffa/zuraffa.dart';
import '../../../domain/entities/product/product.dart';
import 'product_data_source.dart';

class ProductRemoteDataSource implements ProductDataSource {
  final HttpClient _client;

  ProductRemoteDataSource(this._client);

  @override
  Future<Product> get(String id) async {
    final response = await _client.get('/products/$id');
    return Product.fromJson(response.data);
  }

  @override
  Future<List<Product>> getList() async {
    final response = await _client.get('/products');
    return (response.data as List)
        .map((json) => Product.fromJson(json))
        .toList();
  }

  @override
  Future<Product> create(Product product) async {
    final response = await _client.post('/products', data: product.toJson());
    return Product.fromJson(response.data);
  }

  @override
  Future<Product> update(UpdateParams<Product> params) async {
    final response = await _client.put(
      '/products/${params.id}',
      data: params.toJson(),
    );
    return Product.fromJson(response.data);
  }

  @override
  Future<void> delete(String id) async {
    await _client.delete('/products/$id');
  }
}
```

### Step 4: Register with DI

The `--di` flag generated DI files. Register your implementation:

```dart
// lib/src/di/datasources/product_remote_data_source_di.dart
import 'package:get_it/get_it.dart';
import '../../data/data_sources/product/product_remote_data_source.dart';
import '../../data/data_sources/product/product_data_source.dart';

Future<void> registerProductRemoteDataSource(GetIt getIt) async {
  getIt.registerLazySingleton<ProductDataSource>(
    () => ProductRemoteDataSource(HttpClient()),
  );
}
```

### Step 5: Use in Your App

```dart
// main.dart
import 'package:flutter/material.dart';
import 'package:zuraffa/zuraffa.dart';
import 'package:get_it/get_it.dart';
import 'src/presentation/pages/product/product_view.dart';
import 'src/di/index.dart'; // Generated DI index

final getIt = GetIt.instance;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  setupDependencies(getIt); // Generated DI setup
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zuraffa Demo',
      home: ProductView(
        productRepository: getIt<ProductRepository>(),
      ),
    );
  }
}
```

### Step 6: Customize the View

The generated View is a starting point. Customize it:

```dart
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
            return const Center(child: CircularProgressIndicator());
          }

          if (controller.viewState.hasError) {
            return ErrorView(failure: controller.viewState.error!);
          }

          return ListView.builder(
            itemCount: controller.viewState.productList.length,
            itemBuilder: (context, index) {
              final product = controller.viewState.productList[index];
              return ListTile(
                title: Text(product.name),
                subtitle: Text('\$${product.price}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => controller.deleteProduct(product.id),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showCreateProductDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

---

## ZFA Patterns in Practice

### Entity-Based Pattern (Standard CRUD)

Perfect for domain entities like Product, User, Order:

```bash
zfa generate Product \
  --methods=get,getList,create,update,delete,watch,watchList \
  --data \
  --vpc \
  --state \
  --di \
  --test
```

### Single Repository Pattern (Custom Logic)

For focused business operations with one repository:

```bash
zfa generate ProcessCheckout \
  --domain=checkout \
  --repo=CheckoutRepository \
  --params=CheckoutRequest \
  --returns=OrderConfirmation \
  --test
```

### Orchestrator Pattern (Complex Workflows)

Compose multiple UseCases into workflows:

```bash
# Step 1: Create atomic UseCases
zfa generate ValidateCart --domain=checkout --repo=Cart --params=CartId --returns=bool --test
zfa generate CreateOrder --domain=checkout --repo=Order --params=OrderData --returns=Order --test
zfa generate ProcessPayment --domain=checkout --repo=Payment --params=PaymentData --returns=Receipt --test

# Step 2: Orchestrate them
zfa generate ProcessCheckout \
  --domain=checkout \
  --usecases=ValidateCart,CreateOrder,ProcessPayment \
  --params=CheckoutRequest \
  --returns=Order \
  --test
```

### Polymorphic Pattern (Multiple Implementations)

Generate multiple implementations of the same operation:

```bash
zfa generate SparkSearch \
  --domain=search \
  --repo=Search \
  --variants=Barcode,Url,Text \
  --params=Spark \
  --returns=Listing \
  --type=stream \
  --test
```

---

## Next Steps

### Learn the Architecture

- [Architecture Overview](../architecture/overview) - Understand the three layers and ZFA patterns
- [UseCase Types](../architecture/usecases) - Deep dive into each UseCase type and patterns
- [Result Type](../architecture/result-type) - Type-safe error handling

### Explore CLI Features

- [CLI Commands](../cli/commands) - Complete command reference with ZFA patterns
- [Architecture Overview](../architecture/overview) - Clean Architecture patterns
- [UseCase Types](../architecture/usecases) - UseCase patterns and ZFA patterns

### Advanced Topics

- [Caching](../features/caching) - Dual datasource caching
- [Dependency Injection](../features/dependency-injection) - DI setup with domain organization
- [Testing](../features/testing) - Test your code with ZFA patterns
- [Mock Data](../features/mock-data) - Development with mock data

---

## Common Patterns

### Adding a New Entity

```bash
# 1. Create entity
zfa entity create -n Category --field name:String --field parent:\$Category?

# 2. Run build
zfa build

# 3. Generate all layers
zfa generate Category \
  --methods=get,getList,create,update,delete \
  --data \
  --vpc \
  --state \
  --di

# 4. Implement DataSource
# 5. Register with DI
```

### Adding Methods to Existing Entity

```bash
# Add watch methods to existing Product
zfa generate Product --methods=watch,watchList --data --force
```

### Creating a Custom UseCase with Single Repository

```bash
zfa generate ProcessOrder \
  --domain=order \
  --repo=OrderRepository \
  --params=CheckoutRequest \
  --returns=OrderConfirmation \
  --test
```

### Creating an Orchestrator UseCase

```bash
zfa generate ProcessCheckout \
  --domain=checkout \
  --usecases=ValidateCart,CreateOrder,ProcessPayment \
  --params=CheckoutRequest \
  --returns=Order \
  --test
```

---

## Troubleshooting

### Entity Not Found

Ensure your entity is at the correct path:

```
lib/src/domain/entities/{entity_snake}/{entity_snake}.dart
```

For `Product`:
```
lib/src/domain/entities/product/product.dart
```

### Domain Required Error

For custom UseCases, add `--domain`:

```bash
zfa generate ProcessCheckout --domain=checkout --repo=Checkout
```

### Import Errors

Run `flutter pub get` after generation to resolve imports.

### Tests Failing

Generated tests use mocktail. Ensure it's in your `pubspec.yaml`:

```yaml
dev_dependencies:
  mocktail: ^1.0.0
```

---

## Getting Help

- [GitHub Issues](https://github.com/arrrrny/zuraffa/issues) - Report bugs
- [GitHub Discussions](https://github.com/arrrrny/zuraffa/discussions) - Ask questions
- [Example App](https://github.com/arrrrny/zuraffa/tree/master/example) - Full working example
