# Cache Initialization

When using `--cache` with `--di`, Zuraffa automatically generates cache initialization files for Hive boxes.

## Generated Structure

```
lib/src/
├── cache/
│   ├── product_cache.dart
│   ├── user_cache.dart
│   └── index.dart              # Auto-generated with initAllCaches()
└── di/
    └── datasources/
        └── product_local_data_source_di.dart
```

## Example Generated Files

### Cache Init File

```dart
// lib/src/cache/product_cache.dart
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import '../domain/entities/product/product.dart';

Future<void> initProductCache() async {
  await Hive.openBox<Product>('products');
}
```

### Cache Index

```dart
// lib/src/cache/index.dart
export 'product_cache.dart';
export 'user_cache.dart';

Future<void> initAllCaches() async {
  await initProductCache();
  await initUserCache();
}
```

### DI File

```dart
// lib/src/di/datasources/product_local_data_source_di.dart
import 'package:get_it/get_it.dart';
import '../../data/data_sources/product/product_local_data_source.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import '../../domain/entities/product/product.dart';

void registerProductLocalDataSource(GetIt getIt) {
  getIt.registerLazySingleton<ProductLocalDataSource>(
    () => ProductLocalDataSource(Hive.box<Product>('products')),
  );
}
```

## Usage

```dart
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'src/cache/index.dart';
import 'src/di/index.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Hive.initFlutter();
  await initAllCaches();  // Initialize all Hive boxes first
  
  setupDependencies(GetIt.instance);  // Then setup DI
  
  runApp(MyApp());
}
```

## Generate Command

```bash
zfa generate Product --methods=get,getList --repository --data --cache --di
```

## Benefits

- ✅ No async in DI files
- ✅ Centralized cache initialization
- ✅ Single `initAllCaches()` call
- ✅ Automatic index generation
- ✅ Clean separation of concerns
