# GraphQL Generation

**Zuraffa** eliminates the boilerplate of manual GraphQL operation strings by providing a high-level generation system. By using the `--gql` flag, Zuraffa generates type-safe, optimized GraphQL queries, mutations, and subscriptions directly from your entities and UseCases.

---

## 🦄 Why GraphQL Generation?

*   **Type Safety**: Operations are automatically aligned with your Zorphy entities.
*   **Zero Boilerplate**: No more maintaining long, error-prone GraphQL strings.
*   **Auto-Detection**: Zuraffa intelligently detects the operation type (Query vs Mutation) based on your CRUD methods.
*   **Nested Selection**: Support for complex object graphs using dot notation or structured strings.
*   **Client Agnostic**: Generates raw Dart string constants that work with `graphql_flutter`, `ferry`, or simple HTTP clients.

---

## 🚀 Basic Usage

### 1. Entity-Based Generation
Generate GraphQL operations for an entity's CRUD methods:

```bash
zfa feature Product --methods=get,getList,create --gql
```

### 2. Custom Return Fields
Specify exactly which fields you want to fetch to avoid over-fetching:

```bash
zfa feature Product --methods=get,getList \
  --gql \
  --gql-returns="id,name,price,category,stock,isActive"
```

---

## 🛠️ Custom UseCase Generation

For custom business logic, you can specify the operation type and input structure:

```bash
zfa make SearchProducts usecase \
  --domain=search \
  --params=SearchRequest \
  --returns=List<Product> \
  --gql \
  --gql-type=query \
  --gql-name=searchProducts \
  --gql-input-type=SearchInput \
  --gql-returns="id,name,price,category"
```

---

## 🏗️ Generated Architecture

Generated GraphQL files are placed in a dedicated folder within your data source:

```text
lib/src/data/datasources/product/graphql/
├── get_product_query.dart
├── get_product_list_query.dart
├── create_product_mutation.dart
└── watch_product_subscription.dart
```

### Example: Generated Mutation
```dart
// lib/src/data/datasources/product/graphql/create_product_mutation.dart

const String createProductMutation = r'''
  mutation CreateProduct($input: CreateProductInput!) {
    createProduct(input: $input) {
      id
      name
      price
      category
    }
  }''';
```

---

## 🧠 Advanced Features

### Nested Fields
Select nested object properties using standard GraphQL syntax within the `--gql-returns` flag:

```bash
zfa feature Order --methods=get \
  --gql \
  --gql-returns="id,total,items{id,quantity,product{name,price}}"
```

### Auto-Detection Logic
When using `zfa feature` or `zfa make` with entity methods, Zuraffa maps them as follows:

| Method | GraphQL Operation |
| :--- | :--- |
| `get`, `getList` | `query` |
| `create`, `update`, `delete` | `mutation` |
| `watch`, `watchList` | `subscription` |

---

## 📂 Next Steps

*   [**Data Layer**](./caching) - How to use these operations in your DataSources.
*   [**CLI Reference**](../cli/commands) - Master all GraphQL generation flags.
