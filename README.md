# 🦒 Zuraffa

**AI-First Clean Architecture State Management for Flutter**

> Generate production-ready Flutter code from JSON with TDD, 100% test coverage, and zero boilerplate.

[![Version](https://img.shields.io/badge/version-0.3.3-blue.svg)](https://github.com/arrrrny/zuraffa)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

## 🎯 What is Zuraffa?

Zuraffa is a **code generation CLI + state management framework** that implements Clean Architecture for Flutter apps. Instead of writing boilerplate, you describe your data with JSON and Zuraffa generates:

- ✅ **Entities** with [zikzak_morphy](https://pub.dev/packages/zikzak_morphy) decorators
- ✅ **DataSources** (Remote/Local/Mock) with complete implementations
- ✅ **Repositories** with cache-first logic
- ✅ **UseCases** for business logic
- ✅ **100% test coverage** - all tests passing by default!

**Built for [ZikZak AI](https://zikzak.ai)** - The AI-powered shopping experience.

---

## 🚀 Quick Start

### Installation

```bash
dart pub global activate zuraffa
```

### Generate Your First Feature

1. Create a JSON file describing your entity:

```json
// product.json
{
  "id": "prod-123",
  "name": "Wireless Headphones",
  "price": 99.99,
  "inStock": true,
  "tags": ["electronics", "audio"]
}
```

2. Run the generator:

```bash
zuraffa generate Product --from-json product.json
```

3. That's it! You now have:
   - 📄 1 Entity (+ .g.dart from Morphy)
   - 🌐 4 DataSource files (interface + remote + local + mock)
   - 🗄️ 2 Repository files (interface + implementation)
   - ⚙️ 3 UseCase files (Get + GetProducts + ProductFilter)
   - 🧪 **9 test files with 100% coverage!**

4. Run the tests:

```bash
dart test  # All tests pass! ✅
```

---

## 🧬 Entities vs Value Objects (Auto-Detected!)

Zuraffa is **opinionated and smart** - it automatically detects whether to generate an Entity or Value Object based on your JSON:

**🎯 Auto-Detection Rules:**
- ✅ **Has `id` field** (String or int) → **Entity** (full CRUD stack)
- ✅ **No `id` field** → **Value Object** (just entity + tests)
- ✅ **`--value-object` flag** → **Force Value Object** (even if `id` exists)

Zuraffa supports both **Morphy Entities** and **Morphy Value Objects** following Domain-Driven Design principles:

### Entities (Auto-Detected)

Objects with **identity** - tracked and cached:

```bash
# JSON with id → Auto-generates Entity
zuraffa generate Product --from-json product.json
```

**Example JSON:**
```json
{
  "id": "prod-123",           // ← Auto-detected as Entity!
  "name": "Wireless Headphones",
  "price": 99.99
}
```

**Generates:**
- ✅ Full CRUD stack (Repository + DataSources + UseCases)
- ✅ Cache-first logic
- ✅ Comprehensive tests

**Use for:** Product, User, Order, Customer - anything that needs tracking and CRUD operations.

**Supported `id` types:** `String` or `int`

### Value Objects (Auto-Detected)

Objects **without identity** - just immutable data structures:

```bash
# JSON without id → Auto-generates Value Object
zuraffa generate Address --from-json address.json

# Or force Value Object even if id exists
zuraffa generate Address --from-json address.json --value-object
```

**Example JSON:**
```json
{
  "rating": 5,                  // ← No id = Auto-detected as Value Object!
  "title": "Excellent!",
  "comment": "Great product",
  "reviewerName": "John Doe",
  "createdAt": "2025-11-14T12:00:00Z"
}
```

**Generates:**
- ✅ Only entity + tests (no repository/usecases)
- ✅ Can be used as types within Entities
- ✅ Immutable data structures

**Use for:** Address, Money, Rating, Review, Color, Coordinates - data structures that don't need their own repositories.

### Why This Is Powerful

- 🎯 **AI-First**: Zuraffa makes the right decision automatically
- 🧬 **DDD Principles**: Entities have lifecycle, Value Objects don't
- 🔹 **Entities** = Domain objects with lifecycle (Create, Read, Update, Delete)
- 🔹 **Value Objects** = Domain data without lifecycle (just immutable types)
- 🔹 Both use `@Morphy(generateJson: true)` - same serialization power!
- 🔹 Compose Value Objects inside Entities for rich domain models
- 🎚️ **Override**: Use `--value-object` flag to force Value Object generation

### Future: .env Configuration

Coming in v0.4.0+, configure Zuraffa behavior with `.env`:

```bash
# .env (future feature)
ENFORCE_ID=true          # Require id field for all entities (strict mode)
AUTO_DETECT=true         # Auto-detect Entity vs Value Object (default)
DEFAULT_ID_TYPE=String   # String or int
```

Stay opinionated while staying flexible! 🦒

---

## 📦 What Gets Generated?

### Default Generation (Read-Only)

By default, Zuraffa generates **read-only operations** with filtering:

```bash
zuraffa generate Product --from-json product.json
```

**Generates:**
- `GetProductUseCase` - Fetch single product by ID
- `GetProductsUseCase` - Fetch filtered list of products
- `ProductFilter` - Filter class with search, pagination, custom filters

### With CRUD Operations

Add `--crud` flag for full Create/Update/Delete:

```bash
zuraffa generate Product --from-json product.json --crud
```

**Additionally generates:**
- `CreateProductUseCase`
- `UpdateProductUseCase`
- `DeleteProductUseCase`

---

## 🏗️ Architecture

Zuraffa follows **Uncle Bob's Clean Architecture**:

```
lib/
├── domain/                      # Business logic (pure Dart)
│   ├── entities/
│   │   └── product.dart         # @morphy entity
│   ├── repositories/
│   │   └── product_repository.dart
│   └── usecases/
│       ├── get_product_usecase.dart
│       ├── get_products_usecase.dart
│       └── product_filter.dart
│
├── data/                        # Data layer
│   ├── datasources/
│   │   ├── product_datasource.dart           # Interface
│   │   ├── remote_product_datasource.dart    # HTTP implementation
│   │   ├── local_product_datasource.dart     # Cache implementation
│   │   └── mock_product_datasource.dart      # Testing implementation
│   └── repositories/
│       └── data_product_repository.dart      # Cache-first logic
│
└── presentation/                # UI layer (you write this!)
    └── pages/
        └── product_page.dart

test/                            # 🧪 100% test coverage!
├── domain/
│   ├── entities/
│   │   └── product_test.dart
│   └── usecases/
│       ├── get_product_usecase_test.dart
│       └── get_products_usecase_test.dart
└── data/
    ├── datasources/
    │   ├── remote_product_datasource_test.dart
    │   ├── local_product_datasource_test.dart
    │   └── mock_product_datasource_test.dart
    └── repositories/
        └── data_product_repository_test.dart
```

---

## 🎨 Core Concepts

### 1. Entities (Morphy-Powered)

Zuraffa uses [zikzak_morphy](https://pub.dev/packages/zikzak_morphy) for JSON serialization:

```dart
import 'package:zikzak_morphy/zikzak_morphy.dart';

part 'product.g.dart';

@morphy
abstract class $Product {
  String get id;
  String get name;
  double get price;
  bool get inStock;
  List<String> get tags;
}
```

**Why Morphy?**
- Primitive JSON Forever™ - No complex nested structures
- Type-safe with minimal code
- Better than Freezed for ZikZak AI's needs

### 2. Result<Success, Failure> Pattern

Zuraffa uses functional error handling instead of exceptions:

```dart
sealed class Result<S, F> {
  T fold<T>(
    T Function(F failure) onFailure,
    T Function(S success) onSuccess,
  );
}

class Success<S, F> extends Result<S, F> { ... }
class Failure<S, F> extends Result<S, F> { ... }
```

**Usage in UseCases:**

```dart
class GetProductUseCase extends UseCase<Product, AppFailure, String> {
  @override
  Future<Result<Product, AppFailure>> execute(String id) async {
    try {
      final product = await _repository.getById(id);
      return Success(product);
    } catch (e) {
      return Failure(NetworkFailure(e.toString()));
    }
  }
}
```

### 3. Filter Pattern

All `GetProducts` usecases include filtering by default:

```dart
class ProductFilter {
  final String? searchQuery;
  final int? limit;
  final int? offset;
  final Map<String, dynamic>? customFilters;

  Map<String, dynamic> toJson() => {
    if (searchQuery != null) 'q': searchQuery,
    if (limit != null) 'limit': limit,
    if (offset != null) 'offset': offset,
    if (customFilters != null) ...customFilters,
  };
}
```

### 4. Cache-First Repository

Repositories implement cache-first logic automatically:

```dart
Future<Result<Product, AppFailure>> getById(String id) async {
  try {
    // 1. Try remote
    final product = await remoteDataSource.getById(id);
    // 2. Cache it locally
    await localDataSource.update(product);
    return Success(product);
  } catch (e) {
    // 3. Fallback to cache
    try {
      final cached = await localDataSource.getById(id);
      return Success(cached);
    } catch (e) {
      return Failure(NetworkFailure(e.toString()));
    }
  }
}
```

---

## 🧪 TDD First - 100% Test Coverage

**Zuraffa's killer feature:** All tests are generated automatically and pass by default!

### Entity Tests
```dart
test('fromJson creates valid Product', () { ... });
test('toJson serializes correctly', () { ... });
test('fromJson -> toJson roundtrip preserves data', () { ... });
test('has required id field', () { ... });
```

### DataSource Tests
- Remote: Tests HTTP calls with mocked `http.Client`
- Local: Tests cache with mocked `SharedPreferences`
- Mock: Tests in-memory implementation

### Repository Tests
- Cache-first logic (remote → cache → fallback)
- Network failure scenarios
- All CRUD operations with mocked datasources

### UseCase Tests
- Success and Failure paths
- Mocked repository for isolation
- Result type handling

**Run all tests:**
```bash
dart test
# All tests pass! ✅
```

---

## 📚 CLI Reference

### Commands

#### `generate` - Full-Stack Generation (RECOMMENDED)

```bash
zuraffa generate <EntityName> --from-json <file> [options]
```

**Options:**
- `--from-json, -j <file>` - JSON file path (required)
- `--crud` - Include Create/Update/Delete usecases (default: false)
- `--no-build-runner` - Skip build_runner execution
- `--verbose, -v` - Verbose output

**Examples:**
```bash
# Read-only with filtering
zuraffa generate Product --from-json product.json

# Full CRUD
zuraffa generate Product --from-json product.json --crud

# Skip build_runner (faster, but no .g.dart files)
zuraffa generate Product --from-json product.json --no-build-runner
```

#### `create entity` - Entity Only

```bash
zuraffa create entity <name> [options]
```

**Options:**
- `--from-json, -j <file>` - Read JSON from file
- `--interactive, -i` - Paste JSON interactively
- `--name, -n <name>` - Entity name (optional)
- `--no-build-runner` - Skip build_runner
- `--verbose, -v` - Verbose output

**Examples:**
```bash
# From file
zuraffa create entity Product --from-json product.json

# Interactive mode
zuraffa create entity --interactive
# (paste JSON and press Ctrl+D)
```

---

## 🔧 Configuration

### Dependencies

Add to your `pubspec.yaml`:

```yaml
dependencies:
  zikzak_morphy: ^2.8.3

dev_dependencies:
  build_runner: ^2.4.0
  mocktail: ^1.0.0       # For generated tests
  test: ^1.24.0
```

### Build Configuration

Zuraffa auto-generates `build.yaml` if missing:

```yaml
targets:
  $default:
    builders:
      zikzak_morphy|morphy:
        enabled: true
```

---

## 🎯 Philosophy

Zuraffa is built on **three pillars**:

### 1. 🧬 Primitive JSON Forever
- Simple, flat JSON structures
- zikzak_morphy for serialization (not Freezed)
- Type-safe with minimal boilerplate

### 2. 🧪 TDD First
- Tests generated automatically
- 100% coverage by default
- All tests pass on first generation

### 3. 🤖 CLI + AI First
- AI (Claude) generates perfect code every time
- Developers describe intent, AI handles implementation
- Zero manual boilerplate

---

## 🚦 Why Zuraffa?

| Feature | Zuraffa | Manual Clean Arch | Riverpod + Freezed |
|---------|---------|-------------------|-------------------|
| **Setup Time** | 1 command | Hours | Hours |
| **Test Coverage** | 100% auto | Manual | Manual |
| **Boilerplate** | Zero | Massive | Medium |
| **Serialization** | Morphy | Manual | Freezed |
| **State Management** | Built-in (v0.4.0) | Manual | Riverpod |
| **Cache Logic** | Auto-generated | Manual | Manual |
| **Type Safety** | ✅ | ✅ | ✅ |
| **Learning Curve** | Minimal | Steep | Medium |
| **AI-Optimized** | ✅ | ❌ | ❌ |

---

## 🛣️ Roadmap

See [ROADMAP.md](ROADMAP.md) for the complete vision.

### v0.3.0 (Current) ✅
- Filter support for GetProducts
- TDD with 100% test coverage
- Dynamic package name detection
- Read-only by default with `--crud` flag

### v0.4.0 (Next) 🚧
- `@zuraffa` annotation for reactive providers
- Riverpod-like DX without dependencies
- Auto-generated state management

### v1.0.0 (Future) 🎯
- Full state management framework
- Offline-first caching
- AI-powered code suggestions
- The only state management built for AI agents

---

## 🤝 Contributing

Zuraffa is built for **ZikZak AI** and the Flutter community.

**Issues & PRs:** https://github.com/arrrrny/zuraffa/issues

---

## 📄 License

MIT License - see [LICENSE](LICENSE)

---

## 🦒 About

**Built by:** [@arrrrny](https://github.com/arrrrny)
**For:** [ZikZak AI](https://zikzak.ai) - AI-powered shopping
**With:** ❤️ and lots of coffee

---

## 📞 Support

- **Documentation:** https://github.com/arrrrny/zuraffa
- **Issues:** https://github.com/arrrrny/zuraffa/issues
- **Twitter:** Coming soon!

---

<p align="center">
  <strong>For Humanity. For ZikZak. For AI Agents. 🦒</strong>
</p>
