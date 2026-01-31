# Caching with Zuraffa

This guide demonstrates how to implement caching in your Zuraffa application using the dual datasource pattern.

## Overview

Zuraffa's caching strategy uses the **Dual DataSource Pattern**:
- **Remote DataSource**: Fetches data from API/external service
- **Local DataSource**: Stores data in local storage (Hive, SQLite, etc.)
- **Repository**: Orchestrates between remote and local based on cache policy

## Quick Start

### 1. Generate with Caching Enabled

```bash
# Generate with daily cache policy
zfa generate Product \
  --methods=get,getList \
  --repository \
  --data \
  --cache \
  --cache-policy=daily \
  --cache-storage=hive

# Or use app restart policy (cache valid only during app session)
zfa generate Product \
  --methods=get,getList \
  --repository \
  --data \
  --cache \
  --cache-policy=restart
```

### 2. Generated Structure

```
lib/src/
├── domain/
│   ├── entities/product/product.dart
│   └── repositories/product_repository.dart
└── data/
    ├── data_sources/product/
    │   ├── product_remote_data_source.dart  # API calls
    │   └── product_local_data_source.dart   # Local storage (Hive)
    └── repositories/
        └── data_product_repository.dart     # Caching logic
```

### 3. Implement Remote DataSource

```dart
// product_remote_data_source.dart
import 'package:http/http.dart' as http;
import 'package:zuraffa/zuraffa.dart';

class ProductRemoteDataSource with Loggable, FailureHandler {
  final http.Client _client;
  final String _baseUrl;

  ProductRemoteDataSource(this._client, this._baseUrl);

  Future<List<Product>> getList(ListQueryParams params) async {
    final response = await _client.get(Uri.parse('$_baseUrl/products'));
    
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as List;
      return json.map((e) => Product.fromJson(e)).toList();
    }
    
    throw ServerFailure('Failed to fetch products');
  }

  Future<Product> get(String id) async {
    final response = await _client.get(Uri.parse('$_baseUrl/products/$id'));
    
    if (response.statusCode == 200) {
      return Product.fromJson(jsonDecode(response.body));
    }
    
    throw NotFoundFailure('Product not found');
  }
}
```

### 4. Local DataSource (Generated with Hive)

When using `--cache-storage=hive`, the local datasource is fully generated:

```dart
// product_local_data_source.dart (auto-generated)
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:zuraffa/zuraffa.dart';

class ProductLocalDataSource with Loggable, FailureHandler {
  final Box<Product> _box;

  ProductLocalDataSource(this._box);

  Future<Product> save(Product product) async {
    await _box.put(product.id, product);
    return product;
  }

  Future<void> saveAll(List<Product> items) async {
    final map = {for (var item in items) item.id: item};
    await _box.putAll(map);
  }

  Future<Product> get(String id) async {
    final item = _box.get(id);
    if (item == null) {
      throw NotFoundFailure('Product not found in cache');
    }
    return item;
  }

  Future<List<Product>> getList(ListQueryParams params) async {
    return _box.values.toList();
  }
}
```

### 5. Setup Cache Policy

```dart
// main.dart or DI setup
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zuraffa/zuraffa.dart';

Future<void> setupDI() async {
  final prefs = await SharedPreferences.getInstance();
  
  // Daily cache policy
  final cachePolicy = DailyCachePolicy(
    getTimestamps: () async {
      final keys = prefs.getKeys().where((k) => k.startsWith('cache_'));
      return {for (var k in keys) k: prefs.getInt(k) ?? 0};
    },
    setTimestamp: (key, timestamp) async {
      await prefs.setInt(key, timestamp);
    },
    removeTimestamp: (key) async {
      await prefs.remove(key);
    },
    clearAll: () async {
      final keys = prefs.getKeys().where((k) => k.startsWith('cache_'));
      for (var k in keys) {
        await prefs.remove(k);
      }
    },
  );

  // Or use app restart policy (simpler, no persistence needed)
  // final cachePolicy = AppRestartCachePolicy();

  // Register with DI
  getIt.registerSingleton<CachePolicy>(cachePolicy);
}
```

### 6. Register Repository

```dart
// DI setup
void registerRepositories() async {
  // Initialize Hive
  await Hive.initFlutter();
  Hive.registerAdapter(ProductAdapter());
  final productBox = await Hive.openBox<Product>('products');

  // Remote datasource
  getIt.registerLazySingleton<ProductRemoteDataSource>(
    () => ProductRemoteDataSource(
      getIt<http.Client>(),
      'https://api.example.com',
    ),
  );

  // Local datasource
  getIt.registerLazySingleton<ProductLocalDataSource>(
    () => ProductLocalDataSource(productBox),
  );

  // Repository with caching
  getIt.registerLazySingleton<ProductRepository>(
    () => DataProductRepository(
      getIt<ProductRemoteDataSource>(),
      getIt<ProductLocalDataSource>(),
      getIt<CachePolicy>(),
    ),
  );
}
```

## Generated Repository (Cache-Aware)

The generated repository automatically handles caching:

```dart
class DataProductRepository implements ProductRepository {
  final ProductRemoteDataSource _remoteDataSource;
  final ProductLocalDataSource _localDataSource;
  final CachePolicy _cachePolicy;

  DataProductRepository(
    this._remoteDataSource,
    this._localDataSource,
    this._cachePolicy,
  );

  @override
  Future<List<Product>> getList(ListQueryParams params) async {
    // Check cache validity
    if (await _cachePolicy.isValid('product_cache')) {
      try {
        return await _localDataSource.getList(params);
      } catch (e) {
        log('Cache miss, fetching from remote');
      }
    }

    // Fetch from remote
    final data = await _remoteDataSource.getList(params);
    
    // Update cache
    await _localDataSource.saveAll(data);
    await _cachePolicy.markFresh('product_cache');
    
    return data;
  }

  @override
  Future<Product> get(String id) async {
    // Check cache validity
    if (await _cachePolicy.isValid('product_cache')) {
      try {
        return await _localDataSource.get(id);
      } catch (e) {
        log('Cache miss for $id, fetching from remote');
      }
    }

    // Fetch from remote
    final data = await _remoteDataSource.get(id);
    
    // Update cache
    await _localDataSource.save(data);
    await _cachePolicy.markFresh('product_cache');
    
    return data;
  }
}
```

## Cache Policies

### Daily Cache Policy

Cache expires after 24 hours:

```dart
final policy = DailyCachePolicy(
  getTimestamps: () async => {...},
  setTimestamp: (key, ts) async => {...},
  removeTimestamp: (key) async => {...},
  clearAll: () async => {...},
);
```

### App Restart Policy

Cache valid only during app session:

```dart
final policy = AppRestartCachePolicy();
```

### TTL (Time-To-Live) Policy

Custom expiration duration:

```dart
final policy = TtlCachePolicy(
  ttl: const Duration(hours: 6),
  getTimestamps: () async => {...},
  setTimestamp: (key, ts) async => {...},
  removeTimestamp: (key) async => {...},
  clearAll: () async => {...},
);
```

## Manual Cache Invalidation

```dart
// In your UseCase or Controller
class RefreshProductsUseCase extends CompletableUseCase<NoParams> {
  final ProductRepository _repository;
  final CachePolicy _cachePolicy;

  RefreshProductsUseCase(this._repository, this._cachePolicy);

  @override
  Future<void> execute(NoParams params, CancelToken? cancelToken) async {
    // Invalidate cache
    await _cachePolicy.invalidate('product_cache');
    
    // Fetch fresh data (will bypass cache)
    await _repository.getList(ListQueryParams());
  }
}
```

## How It Works

### First App Launch

```
ProductRepository.getList()
  ↓
CachePolicy.isValid('product_cache') → false (no cache yet)
  ↓
ProductRemoteDataSource.getList() → Fetch from API
  ↓
ProductLocalDataSource.saveAll() → Save to Hive
  ↓
CachePolicy.markFresh('product_cache') → Mark as cached
  ↓
Return data
```

### Subsequent Calls (Same Day)

```
ProductRepository.getList()
  ↓
CachePolicy.isValid('product_cache') → true (cached)
  ↓
ProductLocalDataSource.getList() → Return from Hive ⚡
  ↓
Return data (instant!)
```

### Next Day

```
ProductRepository.getList()
  ↓
CachePolicy.isValid('product_cache') → false (expired)
  ↓
ProductRemoteDataSource.getList() → Fetch from API
  ↓
... (same as first launch)
```

## Setup Hive

### 1. Add Dependencies

```yaml
dependencies:
  hive_ce: ^2.6.0
  hive_ce_flutter: ^2.1.0

dev_dependencies:
  hive_ce_generator: ^1.6.0
  build_runner: ^2.4.6
```

### 2. Make Entity Hive-Compatible

```dart
import 'package:hive_ce/hive.dart';

part 'product.g.dart';

@HiveType(typeId: 0)
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

### 3. Generate Hive Adapters

```bash
dart run build_runner build
```

## Best Practices

1. **Use AppRestartCachePolicy for config data** that rarely changes
2. **Use DailyCachePolicy for data** that updates daily
3. **Use TtlCachePolicy for fine-grained control**
4. **Implement proper error handling** in local datasource (cache miss)
5. **Consider cache size** - implement cleanup for large datasets
6. **Test cache invalidation** scenarios

## Testing

```dart
// Mock cache policy for tests
class MockCachePolicy extends Mock implements CachePolicy {}

void main() {
  test('getList uses cache when valid', () async {
    final mockPolicy = MockCachePolicy();
    final mockLocal = MockLocalDataSource();
    final mockRemote = MockRemoteDataSource();
    
    when(mockPolicy.isValid(any)).thenAnswer((_) async => true);
    when(mockLocal.getList(any)).thenAnswer((_) async => [testProduct]);
    
    final repo = DataProductRepository(mockRemote, mockLocal, mockPolicy);
    final result = await repo.getList(ListQueryParams());
    
    expect(result, [testProduct]);
    verifyNever(mockRemote.getList(any)); // Remote not called
    verify(mockLocal.getList(any)).called(1);
  });
}
```

## CLI Examples

```bash
# Daily cache with Hive
zfa generate Product --methods=get,getList --repository --data --cache --cache-storage=hive

# App restart cache
zfa generate Product --methods=get,getList --repository --data --cache --cache-policy=restart

# TTL cache (6 hours)
zfa generate Product --methods=get,getList --repository --data --cache --cache-policy=ttl
```

