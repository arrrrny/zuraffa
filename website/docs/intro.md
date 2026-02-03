# Welcome to Zuraffa

**Zuraffa** (Zürafa means Giraffe in Türkçe) is a comprehensive Clean Architecture framework for Flutter applications with **Result-based error handling**, **type-safe failures**, and **minimal boilerplate**.

## Why Zuraffa?

- ✅ **Result Type**: Type-safe error handling with `Result<T, AppFailure>`
- ✅ **Sealed Failures**: Exhaustive pattern matching for error cases
- ✅ **UseCase Pattern**: Single-shot, streaming, and background operations
- ✅ **Controller**: Simple state management with automatic cleanup
- ✅ **CLI Tool**: Generate boilerplate code with `zfa` command
- ✅ **MCP Server**: AI/IDE integration via Model Context Protocol
- ✅ **Cancellation**: Cooperative cancellation with `CancelToken`
- ✅ **Fine-grained Rebuilds**: Optimize performance with selective widget updates
- ✅ **Caching**: Built-in dual datasource pattern with flexible cache policies
- ✅ **ZFA**: Entity-based, Single Repository, Orchestrator, and Polymorphic patterns

## ZFA - Complete Clean Architecture Framework

ZFA transforms from a CRUD generator into a **complete Clean Architecture framework** with four powerful patterns:

### 1. Entity-Based Pattern
Perfect for standard CRUD operations on entities:
```bash
zfa generate Product --methods=get,getList,create,update,delete --data --vpc
```

### 2. Single Repository Pattern (Recommended)
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
  zuraffa: ^1.16.0
```

Then run:

```bash
flutter pub get
```

### Activate the CLI

```bash
dart pub global activate zuraffa
```

### Generate Your First Feature

```bash
# Initialize with a sample entity
zfa initialize

# Entity-based: Generate complete Clean Architecture
zfa generate Product --methods=get,getList,create,update,delete --data --vpc --state --di --test

# Single Repository: Custom business logic
zfa generate ProcessCheckout --domain=checkout --repo=Checkout --params=CheckoutRequest --returns=OrderConfirmation

# Orchestrator: Compose multiple UseCases
zfa generate ProcessCheckout --domain=checkout --usecases=ValidateCart,CreateOrder,ProcessPayment --params=CheckoutRequest --returns=Order
```

That's it! One command generates:
- ✅ Domain layer (UseCases + Repository interface)
- ✅ Data layer (DataRepository + DataSource)
- ✅ Presentation layer (View, Presenter, Controller, State)
- ✅ Dependency injection setup (get_it)
- ✅ Unit tests with mock setup

## What's Next?

- [Architecture Overview](./architecture/overview) - Deep dive into Clean Architecture patterns
- [UseCase Types](./architecture/usecases) - Explore all UseCase patterns and ZFA patterns
- [CLI Reference](./cli/commands) - Complete CLI documentation with all flags and options
- [Features](./features/dependency-injection) - Explore advanced features like caching, mock data, and testing
- [GitHub Repository](https://github.com/arrrrny/zuraffa) - Source code and examples