import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/src/plugins/cache/cache_plugin.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/plugins/cache/capabilities/create_cache_adapter_capability.dart';

import '../regression/regression_test_utils.dart';

void main() {
  late RegressionWorkspace workspace;
  late String outputDir;

  setUp(() async {
    workspace = await createWorkspace('cache_adapter_test');
    await writePubspec(workspace);
    await runFlutterPubGet(workspace);
    outputDir = workspace.outputDir;
  });

  tearDown(() async {
    await disposeWorkspace(workspace);
  });

  group('CreateCacheAdapterCapability', () {
    test('discovers sub-entities and updates hive registrar', () async {
      // ── 1. Create Product entity with sub-entity fields ──────────────
      final productDir = Directory('$outputDir/domain/entities/product');
      await productDir.create(recursive: true);
      await File(
        '$outputDir/domain/entities/product/product.dart',
      ).writeAsString('''
class Product {
  final String id;
  final Category category;
  final List<Variant> variants;

  Product({
    required this.id,
    required this.category,
    required this.variants,
  });
}

class ProductPatch {
  final String? id;
  final Category? category;

  ProductPatch({this.id, this.category});
}

class ProductFields {
  static const Field<Product, String> id = Field(name: 'id');
  static const Field<Product, Category> category = Field(name: 'category');
}
''');

      // ── 2. Create sub-entity: Category ───────────────────────────────
      final categoryDir = Directory('$outputDir/domain/entities/category');
      await categoryDir.create(recursive: true);
      await File(
        '$outputDir/domain/entities/category/category.dart',
      ).writeAsString('''
class Category {
  final String id;
  final String name;

  Category({required this.id, required this.name});
}

class CategoryPatch {
  final String? id;

  CategoryPatch({this.id});
}

class CategoryFields {
  static const Field<Category, String> id = Field(name: 'id');
  static const Field<Category, String> name = Field(name: 'name');
}
''');

      // ── 3. Create sub-entity: Variant ────────────────────────────────
      final variantDir = Directory('$outputDir/domain/entities/variant');
      await variantDir.create(recursive: true);
      await File(
        '$outputDir/domain/entities/variant/variant.dart',
      ).writeAsString('''
class Variant {
  final String id;
  final String sku;

  Variant({required this.id, required this.sku});
}

class VariantPatch {
  final String? id;

  VariantPatch({this.id});
}

class VariantFields {
  static const Field<Variant, String> id = Field(name: 'id');
  static const Field<Variant, String> sku = Field(name: 'sku');
}
''');

      // ── 4. Create cache directory with a cache file ──────────────────
      // The registrar generator needs at least one *_cache.dart file to
      // trigger regeneration (it returns early otherwise).
      final cacheDir = Directory('$outputDir/cache');
      await cacheDir.create(recursive: true);
      await File('$outputDir/cache/product_cache.dart').writeAsString('''
// Auto-generated cache for Product
import 'package:zuraffa/zuraffa.dart';
import '../domain/entities/product/product.dart';

Future<void> initProductCache() async {
  await Hive.openBox<Product>('products');
}
''');
      await File('$outputDir/cache/timestamp_cache.dart').writeAsString('''
// Auto-generated timestamp cache
import 'package:zuraffa/zuraffa.dart';

Future<void> initTimestampCache() async {
  await Hive.openBox<int>('cache_timestamps');
}
''');

      // ── 5. Execute the capability ────────────────────────────────────
      final plugin = CachePlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(
          dryRun: false,
          force: true,
          verbose: true,
        ),
      );

      final capability = CreateCacheAdapterCapability(plugin);
      final result = await capability.execute({'name': 'Product'});

      // ── 6. Verify execution succeeded ────────────────────────────────
      expect(result.success, isTrue);

      // ── 7. Verify generated files in result ──────────────────────────
      expect(result.files, isNotEmpty);

      // ── 8. Verify manual additions file ──────────────────────────────
      final manualAdditionsFile = File(
        '$outputDir/cache/hive_manual_additions.txt',
      );
      expect(manualAdditionsFile.existsSync(), isTrue);
      final manualContent = manualAdditionsFile.readAsStringSync();
      print('Manual Additions Content:\n$manualContent');

      expect(manualContent, contains('product/product.dart|Product'));
      expect(manualContent, contains('category/category.dart|Category'));
      expect(manualContent, contains('variant/variant.dart|Variant'));

      // ── 9. Verify registrar file ─────────────────────────────────────
      final registrarFile = File('$outputDir/cache/hive_registrar.dart');
      expect(registrarFile.existsSync(), isTrue);
      final registrarContent = registrarFile.readAsStringSync();
      print('Registrar Content:\n$registrarContent');

      // Both extension classes are present
      expect(
        registrarContent,
        contains('extension HiveRegistrar on HiveInterface'),
      );
      expect(
        registrarContent,
        contains('extension IsolatedHiveRegistrar on IsolatedHiveInterface'),
      );

      // All AdapterSpec entries present
      expect(registrarContent, contains('AdapterSpec<Product>()'));
      expect(registrarContent, contains('AdapterSpec<Category>()'));
      expect(registrarContent, contains('AdapterSpec<Variant>()'));

      // All registerAdapter calls present
      expect(registrarContent, contains('registerAdapter(ProductAdapter())'));
      expect(registrarContent, contains('registerAdapter(CategoryAdapter())'));
      expect(registrarContent, contains('registerAdapter(VariantAdapter())'));

      // @GenerateAdapters annotation present
      expect(registrarContent, contains('@GenerateAdapters('));

      // Part file directive present
      expect(registrarContent, contains("part 'hive_registrar.g.dart';"));
    });

    test('returns error for non-existent entity', () async {
      final plugin = CachePlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(dryRun: false, force: true),
      );

      final capability = CreateCacheAdapterCapability(plugin);
      final result = await capability.execute({'name': 'NonExistent'});

      expect(result.success, isFalse);
      expect(result.message, contains("Entity 'NonExistent' not found"));
    });

    test('handles duplicate runs without errors', () async {
      // Create a simple entity
      final productDir = Directory('$outputDir/domain/entities/product');
      await productDir.create(recursive: true);
      await File(
        '$outputDir/domain/entities/product/product.dart',
      ).writeAsString('''
class Product {
  final String id;
  Product({required this.id});
}

class ProductPatch {
  final String? id;
  ProductPatch({this.id});
}

class ProductFields {
  static const Field<Product, String> id = Field(name: 'id');
}
''');

      // Create cache directory with cache file
      final cacheDir = Directory('$outputDir/cache');
      await cacheDir.create(recursive: true);
      await File('$outputDir/cache/product_cache.dart').writeAsString('''
import 'package:zuraffa/zuraffa.dart';
import '../domain/entities/product/product.dart';

Future<void> initProductCache() async {
  await Hive.openBox<Product>('products');
}
''');
      await File('$outputDir/cache/timestamp_cache.dart').writeAsString('''
import 'package:zuraffa/zuraffa.dart';

Future<void> initTimestampCache() async {
  await Hive.openBox<int>('cache_timestamps');
}
''');

      final plugin = CachePlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(
          dryRun: false,
          force: true,
          verbose: true,
        ),
      );

      final capability = CreateCacheAdapterCapability(plugin);

      // First run
      final firstResult = await capability.execute({'name': 'Product'});
      expect(firstResult.success, isTrue);

      // Read first registrar content
      final registrarFile = File('$outputDir/cache/hive_registrar.dart');

      // Second run — should succeed without duplicates
      final secondResult = await capability.execute({'name': 'Product'});
      expect(secondResult.success, isTrue);

      // Verify no duplicate entries — the content should contain the
      // expected invocation exactly once in each of the two extensions.
      final secondRegistrarContent = registrarFile.readAsStringSync();

      // Count occurrences of the ProductAdapter registration string
      final searchStr = 'registerAdapter(ProductAdapter())';
      final firstIdx = secondRegistrarContent.indexOf(searchStr);
      final lastIdx = secondRegistrarContent.lastIndexOf(searchStr);

      // Must appear at least twice (once per extension)
      expect(firstIdx, greaterThan(-1), reason: 'ProductAdapter not found');
      expect(lastIdx, greaterThan(-1), reason: 'ProductAdapter not found');

      // Each occurrence should be in a different extension section
      // (the split yields two sections separated by IsolatedHiveRegistrar)
      final parts = secondRegistrarContent.split('IsolatedHiveRegistrar');
      final hiveCount = searchStr.allMatches(parts.first).length;
      final isolatedCount = searchStr.allMatches(parts.last).length;

      expect(
        hiveCount,
        equals(1),
        reason: 'HiveRegistrar must have exactly one ProductAdapter',
      );
      expect(
        isolatedCount,
        equals(1),
        reason: 'IsolatedHiveRegistrar must have exactly one ProductAdapter',
      );
    });
  });
}
