# Welcome to Zuraffa

**Zuraffa** (Zürafa means Giraffe in Türkçe) is a comprehensive Clean Architecture framework for Flutter applications with **Result-based error handling**, **type-safe failures**, **minimal boilerplate**, and **integrated entity generation**.

## Why Zuraffa?

- ✅ **Clean Architecture Enforced**: Entity-based, Single (Responsibility) Repository, Orchestrator, and Polymorphic patterns
- ✅ **Entity Generation**: Built-in Zorphy integration for type-safe entities with JSON serialization
- ✅ **UseCase Pattern**: Single-shot, streaming, and background operations
- ✅ **State Management Included**: Simple state management with automatic cleanup
- ✅ **ZFA CLI Tool**: Single command for entities, architecture, and boilerplate
- ✅ **MCP Server**: AI/IDE integration via Model Context Protocol
- ✅ **Cancellation**: Cooperative cancellation with `CancelToken`
- ✅ **Fine-grained Rebuilds**: Optimize performance with selective widget updates
- ✅ **Caching**: Built-in dual datasource pattern with flexible cache policies
- ✅ **Result Type**: Type-safe error handling with `Result<T, AppFailure>`
- ✅ **Sealed Failures**: Exhaustive pattern matching for error cases

## Complete Development Workflow

Zuraffa now provides **everything you need** in a single CLI:

### 1. Entity Generation (NEW!)

Create type-safe entities, enums, and data models:

```bash
# Create an entity with fields
zfa entity create -n User --field name:String --field email:String? --field age:int

# Create enums
zfa entity enum -n Status --value active,inactive,pending

# Create from JSON
zfa entity from-json api_response.json

# List all entities
zfa entity list
```

**Features:**
- ✅ Type-safe entities with null safety
- ✅ JSON serialization (built-in)
- ✅ Sealed classes for polymorphism
- ✅ Multiple inheritance support
- ✅ Generic types (`List<T>`, `Map<K,V>`)
- ✅ Nested entities with auto-imports
- ✅ Self-referencing types (trees, graphs)

### 2. Clean Architecture Generation

Generate complete architecture around your entities:

```bash
zfa generate User --methods=get,getList,create,update,delete --data --vpc --state
```

### 3. Build Everything

```bash
zfa build --watch
```

## ZFA - Complete Clean Architecture Framework

ZFA transforms from a CRUD generator into a **complete Clean Architecture framework** with four powerful patterns:

### 1. Entity-Based Pattern
Perfect for standard CRUD operations on entities:
```bash
# First create the entity
zfa entity create -n Product --field name:String --field price:double

# Then generate architecture
zfa generate Product --methods=get,getList,create,update,delete --data --vpc
```

### 2. Single (Responsibility) Repository Pattern (Recommended)
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
zfa generate SparkSearch --domain=search --variants=Barcode,Url,Text --params=Spark --returns=Listing --type=stream
```

## Quick Start

### Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  zuraffa: ^2.1.0
```

Then run:

```bash
flutter pub get
```

### Activate the CLI

```bash
dart pub global activate zuraffa
```

### Generate Your First Complete Feature

```bash
# 1. Create an entity
zfa entity create -n Product \
  --field name:String \
  --field description:String? \
  --field price:double \
  --field category:String

# 2. Create an enum
zfa entity enum -n ProductStatus --value available,out_of_stock,discontinued

# 3. Update the entity to use the enum
zfa entity add-field -n Product --field status:ProductStatus

# 4. Generate complete Clean Architecture
zfa generate Product --methods=get,getList,create,update,delete --data --vpc --state --di --test

# 5. Build everything
zfa build
```

**That's it!** You now have:
- ✅ Type-safe entity with JSON support
- ✅ Enum with automatic barrel export
- ✅ Domain layer (UseCases + Repository interface)
- ✅ Data layer (DataRepository + DataSource)
- ✅ Presentation layer (View, Presenter, Controller, State)
- ✅ Dependency injection setup (get_it)
- ✅ Unit tests with mock setup

### Custom UseCase Patterns

```bash
# Single Repository: Custom business logic
zfa generate ProcessCheckout --domain=checkout --repo=Checkout --params=CheckoutRequest --returns=OrderConfirmation

# Orchestrator: Compose multiple UseCases
zfa generate ProcessCheckout --domain=checkout --usecases=ValidateCart,CreateOrder,ProcessPayment --params=CheckoutRequest --returns=Order
```

## What's Next?

- [Entity Generation Guide](./entities/intro) - Complete guide to entity generation with 50+ examples
- [Architecture Overview](./architecture/overview) - Deep dive into Clean Architecture patterns
- [UseCase Types](./architecture/usecases) - Explore all UseCase patterns and ZFA patterns
- [CLI Reference](./cli/commands) - Complete CLI documentation with all flags and options
- [Features](./features/dependency-injection) - Explore advanced features like caching, mock data, and testing
- [GitHub Repository](https://github.com/arrrrny/zuraffa) - Source code and examples
