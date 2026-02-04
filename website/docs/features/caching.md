# Caching

Zuraffa provides sophisticated caching capabilities using a **dual DataSource pattern**. The `--cache` flag generates complete caching infrastructure with configurable cache policies.

## Overview

Caching in Zuraffa follows the **dual DataSource pattern**:

- **Remote DataSource**: Fetches data from external sources (API, database)
- **Local DataSource**: Stores data locally (Hive, SQLite, shared preferences)
- **Cached Repository**: Coordinates between remote and local sources

## Basic Caching Setup

### 1. Generate with Caching

```bash
zfa generate Product \
  --methods=get,getList,create,update,delete \
  --data \
  --cache
```

This generates:
- Remote DataSource (for API calls)
- Local DataSource (for local storage)
- Cached Repository (coordinates both)

### 2. Configure Cache Policy

Choose from three cache policies:

| Policy | Description | Use Case |
|--------|-------------|----------|
| `daily` | Cache expires at midnight | Daily updated content |
| `restart` | Cache persists until app restart | Session-based data |
| `ttl` | Cache expires after time period | Time-sensitive data |

```bash
# Daily cache policy (default)
zfa generate Product --data --cache --cache-policy=daily

# TTL cache (expires after 2 hours)
zfa generate Product --data --cache --cache-policy=ttl --ttl=120

# Restart cache
zfa generate Product --data --cache --cache-policy=restart
```

### 3. Select Storage Backend

Currently supports Hive storage:

```bash
zfa generate Product --data --cache --cache-storage=hive
```

## Generated Architecture

### Local DataSource

```dart
// lib/src/data/data_sources/product/product_local_data_source.dart
import 'package:hive_ce/hive_ce.dart';
import '../../../domain/entities/product/product.dart';

class ProductLocalDataSource {
  static const String boxName = 'ProductBox';
  
  Future<Box<Product>> get _box async => Hive.box<Product>(boxName);

  Future<Product?> get(String id) async {
    final box = await _box;
    return box.get(id);
  }

  Future<List<Product>> getList() async {
    final box = await _box;
    return box.values.toList();
  }

  Future<void> save(Product product) async {
    final box = await _box;
    await box.put(product.id, product);
  }

  Future<void> saveAll(List<Product> products) async {
    final box = await _box;
    await box.putAll(Map.fromEntries(
      products.map((p) => MapEntry(p.id, p)),
    ));
  }

  Future<void> delete(String id) async {
    final box = await _box;
    await box.delete(id);
  }
}
```

### Remote DataSource

```dart
// lib/src/data/data_sources/product/product_remote_data_source.dart
import '../../../domain/entities/product/product.dart';

class ProductRemoteDataSource {
  Future<Product> get(String id) async {
    // TODO: Implement API call
    throw UnimplementedError();
  }

  Future<List<Product>> getList() async {
    // TODO: Implement API call
    throw UnimplementedError();
  }

  Future<Product> create(Product product) async {
    // TODO: Implement API call
    throw UnimplementedError();
  }

  Future<Product> update(Product product) async {
    // TODO: Implement API call
    throw UnimplementedError();
  }

  Future<void> delete(String id) async {
    // TODO: Implement API call
    throw UnimplementedError();
  }
}
```

### Cached Repository

```dart
// lib/src/data/repositories/data_product_repository.dart
import 'package:zuraffa/zuraffa.dart';
import '../../domain/entities/product/product.dart';
import '../data_sources/product/product_remote_data_source.dart';
import '../data_sources/product/product_local_data_source.dart';
import '../../cache/product_cache.dart';

class DataProductRepository extends ProductRepository {
  final ProductRemoteDataSource _remoteDataSource;
  final ProductLocalDataSource _localDataSource;
  final ProductCache _cache;

  DataProductRepository(
    this._remoteDataSource,
    this._localDataSource,
    this._cache,
  );

  @override
  Future<Product> get(String id) async {
    // Check cache first
    if (await _cache.isValid()) {
      try {
        final cached = await _localDataSource.get(id);
        if (cached != null) return cached;
      } catch (_) {}
    }

    // Fetch from remote and cache
    final product = await _remoteDataSource.get(id);
    await _localDataSource.save(product);
    await _cache.updateTimestamp();
    return product;
  }

  @override
  Future<List<Product>> getList() async {
    // Check cache first
    if (await _cache.isValid()) {
      try {
        return await _localDataSource.getList();
      } catch (_) {}
    }

    // Fetch from remote and cache
    final products = await _remoteDataSource.getList();
    await _localDataSource.saveAll(products);
    await _cache.updateTimestamp();
    return products;
  }

  // ... other methods
}
```

## Cache Policies

### Daily Cache Policy

Expires at midnight (based on device timezone):

```dart
// lib/src/cache/daily_cache_policy.dart
import 'package:hive_ce/hive_ce.dart';

class DailyCachePolicy implements CachePolicy {
  static const String boxName = 'CachePolicyBox';
  static const String timestampKey = 'daily_timestamp';

  @override
  Future<bool> isValid() async {
    final box = Hive.box(timestampBoxName);
    final timestamp = box.get(timestampKey) as int?;
    
    if (timestamp == null) return false;
    
    final lastUpdated = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final today = DateTime.now();
    
    return lastUpdated.day == today.day &&
           lastUpdated.month == today.month &&
           lastUpdated.year == today.year;
  }

  @override
  Future<void> updateTimestamp() async {
    final box = Hive.box(timestampBoxName);
    await box.put(timestampKey, DateTime.now().millisecondsSinceEpoch);
  }

  @override
  Future<void> invalidate() async {
    final box = Hive.box(timestampBoxName);
    await box.delete(timestampKey);
  }
}
```

### TTL Cache Policy

Expires after specified minutes:

```bash
zfa generate Product --data --cache --cache-policy=ttl --ttl=60  # 1 hour
```

### Restart Cache Policy

Persists until app restart:

```bash
zfa generate Product --data --cache --cache-policy=restart
```

## ZFA Patterns and Caching

### Entity-Based Pattern

Perfect for standard entity caching:

```bash
zfa generate Product \
  --methods=get,getList,create,update,delete \
  --data \
  --cache \
  --cache-policy=daily \
  --cache-storage=hive
```

### Single Repository Pattern

Caching works with custom UseCases too:

```bash
zfa generate ProcessCheckout \
  --domain=checkout \
  --repo=Checkout \
  --params=CheckoutRequest \
  --returns=OrderConfirmation \
  --cache
```

### Orchestrator Pattern

Each composed UseCase can have its own caching strategy.

## Advanced Configuration

### Custom TTL Values

```bash
# 30 minutes
zfa generate Product --cache --cache-policy=ttl --ttl=30

# 6 hours
zfa generate Product --cache --cache-policy=ttl --ttl=360

# 1 day (1440 minutes - this is the default)
zfa generate Product --cache --cache-policy=ttl --ttl=1440
```

### Combining with Other Features

```bash
# Complete setup with caching, DI, and testing
zfa generate Product \
  --methods=get,getList,create,update,delete \
  --data \
  --cache \
  --cache-policy=daily \
  --di \
  --test
```

### Using with Mock Data

```bash
# Development with mock data and caching
zfa generate Product \
  --methods=get,getList \
  --data \
  --cache \
  --mock \
  --use-mock
```

## Cache Initialization

Zuraffa automatically generates cache initialization code:

```dart
// lib/src/cache/index.dart
import 'package:hive_ce/hive_ce.dart';
import 'product_cache.dart';
import 'daily_cache_policy.dart';
import 'timestamp_cache.dart';

Future<void> initProductCaches() async {
  // Register adapters
  Hive.registerAdapter(ProductAdapter());
  
  // Open boxes
  await Hive.openBox<Product>('ProductBox');
  await Hive.openBox<int>('CachePolicyBox');
  await Hive.openBox<int>('TimestampBox');
}

Future<void> initAllCaches() async {
  await initProductCaches();
  // Add other cache initializations here
}
```

## Manual Cache Management

### Invalidating Cache

```dart
// In your UseCase or Repository
class RefreshProductUseCase extends UseCase<Product, String> {
  final ProductRepository _repository;
  final ProductCache _cache;

  RefreshProductUseCase(this._repository, this._cache);

  @override
  Future<Product> execute(String id, CancelToken? cancelToken) async {
    // Invalidate cache to force fresh fetch
    await _cache.invalidate();
    
    // Fetch fresh data
    return _repository.get(id);
  }
}
```

### Checking Cache Status

```dart
// Check if cache is valid before expensive operations
if (await productCache.isValid()) {
  // Use cached data
  final products = await localDataSource.getList();
} else {
  // Fetch fresh data
  final products = await remoteDataSource.getList();
}
```

## Best Practices

### 1. Choose the Right Cache Policy

```bash
# Daily: For content that updates once per day
zfa generate NewsArticle --cache --cache-policy=daily

# TTL: For time-sensitive data (prices, weather)
zfa generate StockPrice --cache --cache-policy=ttl --ttl=5

# Restart: For session data
zfa generate UserSession --cache --cache-policy=restart
```

### 2. Combine with Offline Support

```bash
# Robust offline-first setup
zfa generate Product \
  --methods=get,getList,create,update,delete \
  --data \
  --cache \
  --cache-policy=daily \
  --mock  # For development
```

### 3. Use with Dependency Injection

```bash
# Complete setup with DI
zfa generate Product \
  --data \
  --cache \
  --di
```

## Migration from 1.x

### Before (1.x)
```bash
# Caching was less sophisticated
zfa generate Product --cache
```

### After (2.0.0)
```bash
# More granular control over cache policies and storage
zfa generate Product \
  --data \
  --cache \
  --cache-policy=daily \
  --cache-storage=hive
```

## Troubleshooting

### Hive Initialization

If getting Hive errors, ensure proper initialization in `main()`:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive
  await Hive.initFlutter();
  await initAllCaches(); // Generated cache initialization
  
  runApp(MyApp());
}
```

### Cache Not Updating

Make sure to call `_cache.updateTimestamp()` after successful remote fetches in your Repository.

## Next Steps

- [Dependency Injection](./dependency-injection) - Register cached repositories with DI
- [Mock Data](./mock-data) - Develop with cached mock data
- [CLI Reference](../cli/commands) - Complete caching flag documentation
