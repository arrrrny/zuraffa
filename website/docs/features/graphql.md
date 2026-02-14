# GraphQL Generation

Zuraffa v3 can generate GraphQL queries, mutations, and subscriptions from your entities and use cases.

## Overview

GraphQL generation in Zuraffa eliminates the boilerplate of writing GraphQL operation strings by hand. With a single command, you can generate:

- **Queries** for fetching data
- **Mutations** for modifying data
- **Subscriptions** for real-time updates

All generated as Dart string constants that work seamlessly with any GraphQL client library.

## Why GraphQL Generation?

- **Type Safety**: Generated operations match your entity and UseCase types
- **No Manual Strings**: No need to maintain inline GraphQL strings
- **Auto-Detection**: Operation types are automatically detected for entity methods
- **Consistency**: Ensures all team members use the same field selections
- **Refactoring Ready**: Change your entity structure, regenerate GraphQL operations

## How It Works

1. **Define your entities** or **custom UseCases** using Zuraffa
2. **Add the `--gql` flag** to your generation command
3. **Specify return fields** and other GraphQL options
4. **Generated files** appear in `data/data_sources/{entity}/graphql/`
5. **Use with any GraphQL client** (graphql_flutter, ferry, etc.)

## Entity-Based Generation

Generate GraphQL operations for entity CRUD methods:

```bash
# Basic GraphQL generation
zfa generate Product --methods=get,getList,create --gql

# With custom return fields
zfa generate Product \
  --methods=get,getList,create,update,delete \
  --gql \
  --gql-returns="id,name,description,price,category,isActive,createdAt,updatedAt"

# Complete GraphQL setup with data layer
zfa generate Product \
  --methods=get,getList,create,update,delete,watch,watchList \
  --data \
  --gql \
  --gql-returns="id,name,description,price,category,isActive,createdAt,updatedAt" \
  --di
```

### Generated Files Structure

```
lib/src/data/data_sources/product/graphql/
├── get_product_query.dart
├── get_product_list_query.dart
├── create_product_mutation.dart
├── update_product_mutation.dart
├── delete_product_mutation.dart
├── watch_product_subscription.dart
└── watch_product_list_subscription.dart
```

### Generated Code Examples

**Query:**
```dart
// Generated GraphQL query for GetProduct
const String getProductQuery = r'''
  query GetProduct($id: String!) {
    getProduct(id: $id) {
      id
      name
      description
      price
      category
      isActive
      createdAt
      updatedAt
    }
  }''';
```

**Mutation:**
```dart
// Generated GraphQL mutation for CreateProduct
const String createProductMutation = r'''
  mutation CreateProduct($input: CreateProductInput!) {
    createProduct(input: $input) {
      id
      name
      description
      price
      category
      isActive
      createdAt
    }
  }''';
```

**Subscription:**
```dart
// Generated GraphQL subscription for WatchProductList
const String watchProductListSubscription = r'''
  subscription WatchProductList {
    watchProductList {
      id
      name
      price
      category
      isActive
      updatedAt
    }
  }''';
```

## Custom UseCase Generation

Generate GraphQL operations for custom UseCases that use services:

```bash
# Custom UseCase with query
zfa generate SearchProducts \
  --service=Search \
  --domain=products \
  --params=SearchQuery \
  --returns=List<Product> \
  --gql \
  --gql-type=query \
  --gql-name=searchProducts \
  --gql-input-type=SearchInput \
  --gql-returns="id,name,price,category,rating"

# Custom UseCase with mutation
zfa generate UploadFile \
  --service=Storage \
  --domain=storage \
  --params=FileData \
  --returns=String \
  --gql \
  --gql-type=mutation \
  --gql-name=uploadFile \
  --gql-input-type=FileInput

# Custom UseCase with subscription
zfa generate WatchUserLocation \
  --service=Location \
  --domain=realtime \
  --params=UserId \
  --returns=Location \
  --gql \
  --gql-type=subscription
```

### Generated Code Example

**Custom Query:**
```dart
// Generated GraphQL query for SearchProducts
const String searchProductsQuery = r'''
  query SearchProducts($input: SearchInput!) {
    searchProducts(input: $input) {
      id
      name
      price
      category
      rating
    }
  }''';
```

## Using Generated GraphQL

### With graphql_flutter

```dart
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:zuraffa_example/data/data_sources/product/graphql/get_product_query.dart';
import 'package:zuraffa_example/data/data_sources/product/graphql/create_product_mutation.dart';

class ProductGraphQLDataSource {
  final GraphQLClient _client;

  ProductGraphQLDataSource(this._client);

  Future<Product> getProduct(String id) async {
    final result = await _client.query(
      QueryOptions(
        document: gql(getProductQuery),
        variables: {'id': id},
      ),
    );

    if (result.hasException) {
      throw Exception('Failed to fetch product: ${result.exception}');
    }

    return Product.fromJson(result.data!['getProduct']);
  }

  Future<Product> createProduct(CreateProductInput input) async {
    final result = await _client.mutate(
      MutationOptions(
        document: gql(createProductMutation),
        variables: {'input': input.toJson()},
      ),
    );

    if (result.hasException) {
      throw Exception('Failed to create product: ${result.exception}');
    }

    return Product.fromJson(result.data!['createProduct']);
  }

  Stream<List<Product>> watchProductList() {
    return _client.subscribe(
      SubscriptionOptions(
        document: gql(watchProductListSubscription),
      ),
    );
  }
}
```

### With Ferry

```dart
import 'package:ferry/ferry.dart';
import 'package:ferry/graphql_flutter.dart';
import 'package:zuraffa_example/data/data_sources/product/graphql/get_product_query.dart';

class ProductGraphQLDataSource {
  final Client _client;

  ProductGraphQLDataSource(this._client);

  Stream<Product> getProduct(String id) {
    return _client.request(GetProductReq((b) => b
      ..vars.id = id
    ));
  }
}
```

### Direct String Usage

```dart
import 'package:http/http.dart' as http;
import 'package:zuraffa_example/data/data_sources/product/graphql/get_product_query.dart';

class ProductGraphQLDataSource {
  final String _endpoint;
  final http.Client _httpClient;

  ProductGraphQLDataSource(this._endpoint, this._httpClient);

  Future<Product> getProduct(String id) async {
    final response = await _httpClient.post(
      Uri.parse(_endpoint),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'query': getProductQuery,
        'variables': {'id': id},
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch product');
    }

    return Product.fromJson(json.decode(response.body)['data']['getProduct']);
  }
}
```

## GraphQL Flags Reference

| Flag | Description | Example |
|------|-------------|---------|
| `--gql` | Enable GraphQL generation | `--gql` |
| `--gql-type` | Operation type: query, mutation, subscription | `--gql-type=query` |
| `--gql-returns` | Return fields (comma-separated) | `--gql-returns="id,name,price"` |
| `--gql-input-type` | Input type name for mutation/subscription | `--gql-input-type=ProductInput` |
| `--gql-input-name` | Input variable name (default: input) | `--gql-input-name=request` |
| `--gql-name` | Custom operation name | `--gql-name=getProductById` |

## Auto-Detection

For entity-based generation, operation types are automatically detected:

| Method | Auto-Detected Type |
|---------|-------------------|
| `get` | query |
| `getList` | query |
| `create` | mutation |
| `update` | mutation |
| `delete` | mutation |
| `watch` | subscription |
| `watchList` | subscription |

For custom UseCases, you must specify `--gql-type` explicitly.

## Nested Fields

Specify nested fields in `--gql-returns` using dot notation:

```bash
zfa generate Order --methods=get \
  --gql \
  --gql-returns="id,createdAt,customer{id,name,email},items{id,quantity,price,product{id,name}}"
```

**Generated:**
```dart
const String getOrderQuery = r'''
  query GetOrder($id: String!) {
    getOrder(id: $id) {
      id
      createdAt
      customer {
        id
        name
        email
      }
      items {
        id
        quantity
        price
        product {
          id
          name
        }
      }
    }
  }''';
```

## Custom Operation Names

Override auto-generated operation names with `--gql-name`:

```bash
# Default operation name: GetProduct (from method 'get')
zfa generate Product --methods=get --gql

# Custom operation name: GetProductById
zfa generate Product --methods=get --gql --gql-name=GetProductById
```

## Coming Soon

We're working on even more powerful GraphQL features:

### Schema-First Generation

- **Auto-generate entities from GraphQL schema**: Import your GraphQL schema and Zuraffa will automatically create all entity definitions
- **Auto-generate UseCases from queries/mutations**: Parse your `.graphql` files and generate corresponding UseCases with proper types
- **Type safety from schema to code**: Ensure complete type alignment between your GraphQL server and Flutter app
- **Introspection support**: Fetch live schema from GraphQL server to generate up-to-date types
- **Federation support**: Generate code for federated GraphQL schemas

### Benefits

These features will make building GraphQL-powered Flutter apps even more seamless:

- **Zero Boilerplate**: No manual entity creation from schema
- **Always Synced**: Your Flutter types will always match your server schema
- **Type Safety End-to-End**: From database to UI, fully typed
- **Live Updates**: Fetch introspection on build to catch breaking changes early
- **Federation Ready**: Support for complex GraphQL federation setups

### Planned Features

```bash
# Import schema and generate everything
zfa generate-from-schema https://api.example.com/graphql

# Parse .graphql files and create UseCases
zfa generate-usecases queries/*.graphql

# Watch schema for changes
zfa watch-schema --endpoint https://api.example.com/graphql
```

## Best Practices

1. **Specify Return Fields**: Always provide `--gql-returns` to avoid over-fetching
2. **Use Nested Fields**: Leverage GraphQL's nested querying capabilities
3. **Custom Input Types**: Use `--gql-input-type` for complex mutations
4. **Version Your Operations**: Use `--gql-name` to maintain API compatibility
5. **Regenerate on Schema Changes**: Keep your GraphQL operations in sync with server

## Examples

### E-commerce App

```bash
# Product CRUD with GraphQL
zfa generate Product \
  --methods=get,getList,create,update,delete \
  --data \
  --gql \
  --gql-returns="id,name,price,category,images,stock,isActive" \
  --vpc --state --di

# Order management with GraphQL
zfa generate Order \
  --methods=get,getList,create,update \
  --data \
  --gql \
  --gql-returns="id,total,status,items{id,quantity,price},customer{id,name,address}" \
  --vpc --state --di

# Real-time order updates
zfa generate Order --methods=watchList \
  --gql --gql-type=subscription \
  --gql-returns="id,status,updatedAt"
```

### Chat Application

```bash
# Messages with GraphQL subscription
zfa generate Message \
  --methods=get,getList,create \
  --data \
  --gql \
  --gql-returns="id,content,sender{id,name},createdAt"

# Real-time chat updates
zfa generate Message \
  --methods=watchList \
  --gql --gql-type=subscription \
  --gql-returns="id,content,sender{id,name},createdAt,updatedAt"

# User status with subscription
zfa generate User \
  --methods=watch \
  --gql --gql-type=subscription \
  --gql-returns="id,name,status,lastSeen"
```

## See Also

- [GraphQL Documentation](https://graphql.org/learn/) - Official GraphQL documentation
- [graphql_flutter](https://pub.dev/packages/graphql_flutter) - Popular GraphQL client for Flutter
- [Ferry](https://pub.dev/packages/ferry) - Type-safe GraphQL client
- [Result Type](../architecture/result-type) - Type-safe error handling
- [Service Pattern](../cli/commands#single-service-pattern-new---alternative-to-repository) - Alternative to Repository pattern
