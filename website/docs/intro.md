# Welcome to Zuraffa

**Zuraffa** (Zürafa means Giraffe in Türkçe) is a comprehensive Clean Architecture framework for Flutter applications with **Result-based error handling**, **type-safe failures**, and **minimal boilerplate**.

## Why Zuraffa?

- ✅ **Result Type**: Type-safe error handling with `Result<T, AppFailure>`
- ✅ **Sealed Failures**: Exhaustive pattern matching for error cases
- ✅ **UseCase Pattern**: Single-shot, streaming, and background operations
- ✅ **Controller**: Simple state management with automatic cleanup
- ✅ **CLI Tool**: Generate boilerplate code with `zfa` command
- ✅ **DI Generation**: Automatic dependency injection setup with get_it
- ✅ **MCP Server**: AI/IDE integration via Model Context Protocol
- ✅ **Cancellation**: Cooperative cancellation with `CancelToken`
- ✅ **Fine-grained Rebuilds**: Optimize performance with selective widget updates
- ✅ **Caching**: Built-in dual datasource pattern with flexible cache policies

## Quick Start

### Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  zuraffa: ^1.13.0
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

# Generate complete Clean Architecture
zfa generate Product --methods=get,getList,create,update,delete --repository --data --vpc --state --di
```

That's it! One command generates:
- ✅ Domain layer (UseCases + Repository interface)
- ✅ Data layer (DataRepository + DataSource)
- ✅ Presentation layer (View, Presenter, Controller, State)
- ✅ Dependency injection setup (get_it)

## What's Next?

- [Dependency Injection](./features/dependency-injection) - Automatic DI setup with get_it
- [VPC Regeneration](./features/vpc-regeneration) - Regenerate business logic without losing custom UI
- [GitHub Repository](https://github.com/arrrrny/zuraffa) - Source code and examples
- [CLI Guide](https://github.com/arrrrny/zuraffa/blob/master/CLI_GUIDE.md) - Complete CLI documentation
