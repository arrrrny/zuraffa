# Caching

Zuraffa provides a built-in dual datasource pattern for intelligent caching. This allows you to cache data locally while still fetching fresh data from remote sources.

## Overview

The caching system uses two datasources:

1. **Remote DataSource** - Fetches from API/external services
2. **Local DataSource** - Stores in local cache (Hive, SQLite, etc.)

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│   Repository    │────▶│  DataRepository  │────▶│  RemoteSource   │
│   (Interface)   │     │  (Implementation)│     │    (API/HTTP)   │
└─────────────────┘     └──────────────────┘     └─────────────────┘
                               │
                               ▼
                        ┌──────────────────┐
                        │   LocalSource    │
                        │  (Hive/SQLite)   │
                        └──────────────────┘
```

## Cache Policies

Zuraffa supports three cache policies:

| Policy | Description | Use Case |
|--------|-------------|----------|
| `daily` | Cache expires at midnight | Data that refreshes daily |
| `restart` | Cache expires on app restart | Session-based data |
| `ttl` | Cache expires after duration | Time-sensitive data |

## Quick Start

Enable caching with the `--cache` flag:

```bash
zfa generate Product \
  --methods=get,getList,create,update,delete \
  --repository \
  --data \
  --cache \
  --cache-policy=daily \
  --cache-storage=hive
```

This generates:

```
lib/src/data/
├── data_sources/
│   └── product/
│       ├── product_data_source.dart          # Abstract interface
│       ├── product_remote_data_source.dart   # API implementation
│       └── product_local_data_source.dart    # Hive implementation
└── repositories/
    └── data_product_repository.dart          # Cache-aware repository
```

## Generated Code

### DataRepository with Caching

```dart
class DataProductRepository implements ProductRepository {
  final ProductDataSource _remoteDataSource;
  final ProductDataSource? _localDataSource;
  final CachePolicy _cachePolicy;

  DataProductRepository(
    this._remoteDataSource, {
    ProductDataSource? localDataSource,
    CachePolicy? cachePolicy,
  })  : _localDataSource = localDataSource,
        _cachePolicy = cachePolicy ?? DailyCachePolicy();

  @override
  Future<Product> get(String id) async {
    // Check cache first
    if (_localDataSource != null && await _cachePolicy.isValid()) {
      try {
        return await _localDataSource!.get(id);
      } catch (_) {
        // Cache miss or expired
      }
    }

    // Fetch from remote
    final product = await _remoteDataSource.get(id);
    
    // Save to cache
    await _localDataSource?.save(product);
    
    return product;
  }

  @override
  Future<List<Product>> getList() async {
    // Similar pattern: check cache, fetch remote, update cache
    if (_localDataSource != null && await _cachePolicy.isValid()) {
      try {
        return await _localDataSource!.getList();
      } catch (_) {}
    }

    final products = await _remoteDataSource.getList();
    await _localDataSource?.saveAll(products);
    return products;
  }

  @override
  Future<Product> create(Product product) async {
    final created = await _remoteDataSource.create(product);
    await _localDataSource?.save(created);
    return created;
  }

  @override
  Future<Product> update(UpdateParams<Product> params) async {
    final updated = await _remoteDataSource.update(params);
    await _localDataSource?.save(updated);
    return updated;
  }

  @override
  Future<void> delete(String id) async {
    await _remoteDataSource.delete(id);
    await _localDataSource?.delete(id);
  }
}
```

### Local DataSource (Hive)

```dart
class ProductLocalDataSource implements ProductDataSource {
  final Box<Product> _box;

  ProductLocalDataSource(this._box);

  @override
  Future<Product> get(String id) async {
    final product = _box.get(id);
    if (product == null) {
      throw CacheFailure('Product not found in cache');
    }
    return product;
  }

  @override
  Future<List<Product>> getList() async {
    return _box.values.toList();
  }

  @override
  Future<void> save(Product product) async {
    await _box.put(product.id, product);
  }

  @override
  Future<void> saveAll(List<Product> products) async {
    final Map<String, Product> entries = {
      for (var p in products) p.id: p,
    };
    await _box.putAll(entries);
  }

  @override
  Future<void> delete(String id) async {
    await _box.delete(id);
  }

  @override
  Future<void> clear() async {
    await _box.clear();
  }
}
```

## Cache Policy Implementations

### DailyCachePolicy

Cache expires at midnight. Perfect for data that updates daily.

```dart
final policy = DailyCachePolicy();

// Check if cache is valid
if (await policy.isValid()) {
  // Use cached data
}

// Invalidate cache (e.g., after manual refresh)
await policy.invalidate();
```

### AppRestartCachePolicy

Cache only lasts until app restart. Good for session data.

```dart
final policy = AppRestartCachePolicy();
```

### TtlCachePolicy

Cache expires after a specific duration.

```dart
// Cache for 1 hour
final policy = TtlCachePolicy(
  ttl: Duration(hours: 1),
);

// Or with custom storage key
final policy = TtlCachePolicy(
  ttl: Duration(minutes: 30),
  storageKey: 'products_cache_ttl',
);
```

## Custom Cache Policy

Implement your own cache policy:

```dart
class CustomCachePolicy implements CachePolicy {
  @override
  Future<bool> isValid() async {
    // Your custom logic
    final lastUpdate = await getLastUpdateTime();
    return DateTime.now().difference(lastUpdate) < Duration(hours: 2);
  }

  @override
  Future<void> invalidate() async {
    await clearLastUpdateTime();
  }
}
```

## Setup Hive for Caching

### Automatic Setup (Recommended)

When using `--cache` with `--di`, Zuraffa automatically generates all cache initialization:

```bash
zfa generate Product \
  --methods=get,getList \
  --repository \
  --data \
  --cache \
  --cache-policy=ttl \
  --ttl=30 \
  --di
```

This generates:

```
lib/src/cache/
├── hive_registrar.dart              # @GenerateAdapters for all entities
├── product_cache.dart               # Opens Product box
├── timestamp_cache.dart             # Opens timestamps box
├── ttl_30_minutes_cache_policy.dart # Fully implemented cache policy
└── index.dart                       # initAllCaches() function
```

**Usage:**

```dart
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'src/cache/index.dart';
import 'src/di/index.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Hive.initFlutter();
  await initAllCaches();  // Registers adapters + opens boxes
  
  setupDependencies(GetIt.instance);
  
  runApp(MyApp());
}
```

Then run:

```bash
dart run build_runner build
```

That's it! All Hive adapters, boxes, and cache policies are automatically configured.

### Manual Setup

If you prefer manual setup:

### 1. Add Dependencies

```yaml
dependencies:
  zuraffa: ^1.14.0
  hive_ce_flutter: ^2.0.0

dev_dependencies:
  hive_ce_generator: ^1.0.0
  build_runner: ^2.4.0
```

### 2. Initialize Hive

```dart
// main.dart
import 'package:hive_ce_flutter/hive_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive
  await Hive.initFlutter();
  
  // Register adapters
  Hive.registerAdapter(ProductAdapter());
  
  runApp(const MyApp());
}
```

### 3. Make Entity Hive-Compatible

```dart
import 'package:hive_ce/hive.dart';

part 'product.g.dart';

@HiveType(typeId: 1)
class Product {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String name;
  
  @HiveField(2)
  final double price;
  
  const Product({
    required this.id,
    required this.name,
    required this.price,
  });
}
```

Generate adapter:

```bash
dart run build_runner build
```

### 4. Register with DI

```dart
void setupDI() {
  // Open Hive box
  final productBox = await Hive.openBox<Product>('products');
  
  // Register datasources
  getIt.registerLazySingleton<ProductDataSource>(
    () => ProductRemoteDataSource(getIt<HttpClient>()),
    instanceName: 'remote',
  );
  
  getIt.registerLazySingleton<ProductDataSource>(
    () => ProductLocalDataSource(productBox),
    instanceName: 'local',
  );
  
  // Register repository with caching
  getIt.registerLazySingleton<ProductRepository>(
    () => DataProductRepository(
      getIt<ProductDataSource>(instanceName: 'remote'),
      localDataSource: getIt<ProductDataSource>(instanceName: 'local'),
      cachePolicy: DailyCachePolicy(),
    ),
  );
}
```

## Advanced Patterns

### Selective Caching

Cache only specific operations:

```dart
class DataProductRepository implements ProductRepository {
  // Always fetch fresh for get()
  @override
  Future<Product> get(String id) => _remoteDataSource.get(id);

  // Cache list operations
  @override
  Future<List<Product>> getList() async {
    // ... caching logic
  }
}
```

### Cache with Background Refresh

Show cached data immediately, refresh in background:

```dart
Future<List<Product>> getListWithRefresh() async {
  // Return cached data immediately
  if (await _cachePolicy.isValid()) {
    final cached = await _localDataSource!.getList();
    
    // Refresh in background
    _refreshCache();
    
    return cached;
  }
  
  // No valid cache, fetch fresh
  return await _fetchAndCache();
}

Future<void> _refreshCache() async {
  try {
    final products = await _remoteDataSource.getList();
    await _localDataSource!.saveAll(products);
  } catch (_) {
    // Ignore background refresh errors
  }
}
```

### Cache Invalidation Strategies

#### Time-Based

```dart
// Auto-invalidate after duration
final policy = TtlCachePolicy(ttl: Duration(hours: 1));
```

#### Event-Based

```dart
// Invalidate on specific events
class ProductRepository {
  Future<Product> create(Product product) async {
    final created = await _remoteDataSource.create(product);
    await _localDataSource?.save(created);
    return created;
  }

  Future<void> refresh() async {
    await _cachePolicy.invalidate();
  }
}
```

#### Version-Based

```dart
class VersionedCachePolicy implements CachePolicy {
  final String currentVersion;
  
  VersionedCachePolicy(this.currentVersion);
  
  @override
  Future<bool> isValid() async {
    final cachedVersion = await getCachedVersion();
    return cachedVersion == currentVersion;
  }
  
  @override
  Future<void> invalidate() async {
    await clearCachedVersion();
  }
}
```

## Testing Cached Repositories

```dart
group('DataProductRepository', () {
  late MockProductDataSource remote;
  late MockProductDataSource local;
  late DataProductRepository repository;

  setUp(() {
    remote = MockProductDataSource();
    local = MockProductDataSource();
    repository = DataProductRepository(
      remote,
      localDataSource: local,
      cachePolicy: DailyCachePolicy(),
    );
  });

  test('returns cached data when cache is valid', () async {
    final cachedProducts = [testProduct];
    when(() => local.getList()).thenAnswer((_) async => cachedProducts);
    
    final result = await repository.getList();
    
    expect(result, equals(cachedProducts));
    verifyNever(() => remote.getList());
  });

  test('fetches from remote when cache is invalid', () async {
    when(() => local.getList()).thenThrow(CacheFailure('Expired'));
    when(() => remote.getList()).thenAnswer((_) async => [testProduct]);
    
    final result = await repository.getList();
    
    expect(result, equals([testProduct]));
    verify(() => remote.getList()).called(1);
  });

  test('saves to cache after remote fetch', () async {
    when(() => local.getList()).thenThrow(CacheFailure('Empty'));
    when(() => remote.getList()).thenAnswer((_) async => [testProduct]);
    when(() => local.saveAll(any())).thenAnswer((_) async {});
    
    await repository.getList();
    
    verify(() => local.saveAll([testProduct])).called(1);
  });
});
```

## Best Practices

### 1. Cache at the Right Level

```dart
// Good: Cache in repository
class DataProductRepository {
  Future<List<Product>> getList() {
    // Cache coordination here
  }
}

// Bad: Cache in UseCase
class GetProductListUseCase {
  // Don't cache here - belongs in data layer
}
```

### 2. Handle Cache Failures Gracefully

```dart
Future<Product> get(String id) async {
  try {
    return await _localDataSource!.get(id);
  } on CacheFailure {
    // Cache miss - fetch from remote
    return await _remoteDataSource.get(id);
  }
}
```

### 3. Invalidate on Mutations

```dart
Future<Product> update(UpdateParams<Product> params) async {
  final updated = await _remoteDataSource.update(params);
  
  // Update cache with new data
  await _localDataSource?.save(updated);
  
  return updated;
}
```

### 4. Use Appropriate Policies

| Data Type | Recommended Policy |
|-----------|-------------------|
| User profile | `AppRestartCachePolicy` |
| Product catalog | `DailyCachePolicy` |
| Stock prices | `TtlCachePolicy(minutes: 5)` |
| News feed | `DailyCachePolicy` |
| Search results | No caching |

---

## Next Steps

- [CLI Commands](../cli/commands) - All generation options
- [Dependency Injection](./dependency-injection) - DI setup for caching
- [Testing](../guides/testing) - Test cached repositories