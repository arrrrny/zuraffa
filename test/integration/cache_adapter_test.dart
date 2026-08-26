@Tags(['integration', 'slow'])
import 'dart:io';

import 'package:test/test.dart';
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

      // Read first registrar content for comparison
      final registrarFile = File('$outputDir/cache/hive_registrar.dart');
      final firstRegistrarContent = registrarFile.readAsStringSync();

      // Verify the first run produced valid output before running again
      expect(
        firstRegistrarContent,
        contains('registerAdapter(ProductAdapter())'),
      );

      // Second run — should succeed without duplicates
      final secondResult = await capability.execute({'name': 'Product'});
      expect(secondResult.success, isTrue);

      // Verify no duplicate entries — the content should contain the
      // expected invocation exactly once in each of the two extensions,
      // and the second run should NOT add duplicates beyond what the
      // first run produced.
      final secondRegistrarContent = registrarFile.readAsStringSync();

      // The second run should preserve all first-run content
      expect(secondRegistrarContent, contains(firstRegistrarContent));

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

    // ─────────────────────────────────────────────────────────────────────
    // NEW TESTS FOR PENDING BEHAVIORS
    // ─────────────────────────────────────────────────────────────────────

    test('generates adapter for enum entity', () async {
      // A2: Enum entity support
      // Create enum in enums directory
      final enumsDir = Directory('$outputDir/domain/entities/enums');
      await enumsDir.create(recursive: true);
      await File('$outputDir/domain/entities/enums/index.dart').writeAsString('''
enum ProductStatus {
  draft,
  active,
  archived,
}
''');

      // Create cache directory with cache file
      final cacheDir = Directory('$outputDir/cache');
      await cacheDir.create(recursive: true);
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
      final result = await capability.execute({'name': 'ProductStatus'});

      // Debug output
      print('Result success: ${result.success}');
      print('Result message: ${result.message}');
      print('Result files: ${result.files}');
      print('Result data: ${result.data}');

      expect(result.success, isTrue);

      final manualAdditionsFile = File('$outputDir/cache/hive_manual_additions.txt');
      expect(manualAdditionsFile.existsSync(), isTrue);
      final manualContent = manualAdditionsFile.readAsStringSync();
      print('Manual Additions Content (enum):\n$manualContent');
      expect(manualContent, contains('../domain/entities/enums/index.dart|ProductStatus'));

      final registrarFile = File('$outputDir/cache/hive_registrar.dart');
      expect(registrarFile.existsSync(), isTrue);
      final registrarContent = registrarFile.readAsStringSync();
      print('Registrar Content (enum):\n$registrarContent');
      expect(registrarContent, contains('AdapterSpec<ProductStatus>()'));
      expect(registrarContent, contains('registerAdapter(ProductStatusAdapter())'));
    });

    test('generates adapter for entity with no sub-entities', () async {
      // A3: Simple entity without sub-entities
      final simpleDir = Directory('$outputDir/domain/entities/simple_entity');
      await simpleDir.create(recursive: true);
      await File(
        '$outputDir/domain/entities/simple_entity/simple_entity.dart',
      ).writeAsString('''
class SimpleEntity {
  final String id;
  final String name;

  SimpleEntity({required this.id, required this.name});
}

class SimpleEntityPatch {
  final String? id;
  final String? name;

  SimpleEntityPatch({this.id, this.name});
}

class SimpleEntityFields {
  static const Field<SimpleEntity, String> id = Field(name: 'id');
  static const Field<SimpleEntity, String> name = Field(name: 'name');
}
''');

      // Create cache directory with cache file - use matching name
      final cacheDir = Directory('$outputDir/cache');
      await cacheDir.create(recursive: true);
      await File('$outputDir/cache/simple_entity_cache.dart').writeAsString('''
import 'package:zuraffa/zuraffa.dart';
import '../domain/entities/simple_entity/simple_entity.dart';

Future<void> initSimpleCache() async {
  await Hive.openBox<SimpleEntity>('simple_entities');
}
''');
      await File('$outputDir/cache/timestamp_cache.dart').writeAsString('''
import 'package:zuraffa/zuraffa.dart';

Future<void> initTimestampCache() async {
  await Hive.openBox<int>('cache_timestamps');
}
''');

      // Delete any existing manual additions and registrar to start fresh
      final manualAdditionsFile = File('$outputDir/cache/hive_manual_additions.txt');
      if (await manualAdditionsFile.exists()) {
        await manualAdditionsFile.delete();
      }
      final registrarFile = File('$outputDir/cache/hive_registrar.dart');
      if (await registrarFile.exists()) {
        await registrarFile.delete();
      }

      final plugin = CachePlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(
          dryRun: false,
          force: true,
          verbose: true,
        ),
      );

      final capability = CreateCacheAdapterCapability(plugin);
      final result = await capability.execute({'name': 'SimpleEntity'});

      // Debug output
      print('Result success: ${result.success}');
      print('Result message: ${result.message}');
      print('Result files: ${result.files}');
      print('Result data: ${result.data}');

      expect(result.success, isTrue);

      expect(manualAdditionsFile.existsSync(), isTrue);
      final manualContent = manualAdditionsFile.readAsStringSync();
      print('Manual Additions Content (simple):\n$manualContent');
      // Only SimpleEntity should be added - count only non-comment lines with '|'
      final entityLines = manualContent.split('\n').where((l) => l.contains('|') && !l.trim().startsWith('#')).length;
      expect(entityLines, equals(1));
      expect(manualContent, contains('simple_entity/simple_entity.dart|SimpleEntity'));

      expect(registrarFile.existsSync(), isTrue);
      final registrarContent = registrarFile.readAsStringSync();
      print('Registrar Content (simple):\n$registrarContent');
      // Only one adapter should be registered
      expect(registrarContent, contains('AdapterSpec<SimpleEntity>()'));
      expect(registrarContent, contains('registerAdapter(SimpleEntityAdapter())'));
      // Should NOT contain Category or Variant
      expect(registrarContent, isNot(contains('Category')));
      expect(registrarContent, isNot(contains('Variant')));
    });

    test('preserves existing adapters when adding new entity', () async {
      // A4: Cross-entity preservation
      // First, create and register Product
      final productDir = Directory('$outputDir/domain/entities/product');
      await productDir.create(recursive: true);
      await File(
        '$outputDir/domain/entities/product/product.dart',
      ).writeAsString('''
class Product {
  final String id;
  Product({required this.id});
}
''');

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

      // First run - register Product
      final firstResult = await capability.execute({'name': 'Product'});
      expect(firstResult.success, isTrue);

      final registrarFile = File('$outputDir/cache/hive_registrar.dart');
      final firstRegistrarContent = registrarFile.readAsStringSync();
      expect(firstRegistrarContent, contains('registerAdapter(ProductAdapter())'));

      // Now create and register a NEW entity: Order
      final orderDir = Directory('$outputDir/domain/entities/order');
      await orderDir.create(recursive: true);
      await File(
        '$outputDir/domain/entities/order/order.dart',
      ).writeAsString('''
class Order {
  final String id;
  final String customerId;

  Order({required this.id, required this.customerId});
}
''');

      await File('$outputDir/cache/order_cache.dart').writeAsString('''
import 'package:zuraffa/zuraffa.dart';
import '../domain/entities/order/order.dart';

Future<void> initOrderCache() async {
  await Hive.openBox<Order>('orders');
}
''');

      // Second run - register Order (should preserve Product)
      final secondResult = await capability.execute({'name': 'Order'});
      expect(secondResult.success, isTrue);

      final secondRegistrarContent = registrarFile.readAsStringSync();
      print('Registrar Content after Order:\n$secondRegistrarContent');

      // Both Product and Order should be registered
      expect(secondRegistrarContent, contains('registerAdapter(ProductAdapter())'));
      expect(secondRegistrarContent, contains('registerAdapter(OrderAdapter())'));

      // Check manual additions has both
      final manualAdditionsFile = File('$outputDir/cache/hive_manual_additions.txt');
      final manualContent = manualAdditionsFile.readAsStringSync();
      expect(manualContent, contains('product/product.dart|Product'));
      expect(manualContent, contains('order/order.dart|Order'));
    });

    test('adds only new sub-entity when entity updated incrementally', () async {
      // A6: Incremental sub-entity discovery
      // Create Product with Category sub-entity
      final productDir = Directory('$outputDir/domain/entities/product');
      await productDir.create(recursive: true);
      await File(
        '$outputDir/domain/entities/product/product.dart',
      ).writeAsString('''
class Product {
  final String id;
  final Category category;

  Product({required this.id, required this.category});
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

      // First run - Product + Category
      final firstResult = await capability.execute({'name': 'Product'});
      expect(firstResult.success, isTrue);

      final registrarFile = File('$outputDir/cache/hive_registrar.dart');
      final firstRegistrarContent = registrarFile.readAsStringSync();
      expect(firstRegistrarContent, contains('registerAdapter(ProductAdapter())'));
      expect(firstRegistrarContent, contains('registerAdapter(CategoryAdapter())'));

      // Now add a NEW sub-entity: Variant
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

      // Update Product to reference Variant
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
  final List<Variant>? variants;

  ProductPatch({this.id, this.category, this.variants});
}

class ProductFields {
  static const Field<Product, String> id = Field(name: 'id');
  static const Field<Product, Category> category = Field(name: 'category');
  static const Field<Product, List<Variant>> variants = Field(name: 'variants');
}
''');

      // Re-run capability for Product (should discover new Variant)
      final secondResult = await capability.execute({'name': 'Product'});
      expect(secondResult.success, isTrue);

      final secondRegistrarContent = registrarFile.readAsStringSync();
      print('Registrar Content after adding Variant:\n$secondRegistrarContent');

      // All three should be present
      expect(secondRegistrarContent, contains('registerAdapter(ProductAdapter())'));
      expect(secondRegistrarContent, contains('registerAdapter(CategoryAdapter())'));
      expect(secondRegistrarContent, contains('registerAdapter(VariantAdapter())'));

      // Count occurrences - should be exactly one per extension per entity
      final parts = secondRegistrarContent.split('IsolatedHiveRegistrar');
      final productCount = 'registerAdapter(ProductAdapter())'.allMatches(parts.first).length;
      final categoryCount = 'registerAdapter(CategoryAdapter())'.allMatches(parts.first).length;
      final variantCount = 'registerAdapter(VariantAdapter())'.allMatches(parts.first).length;

      expect(productCount, equals(1));
      expect(categoryCount, equals(1));
      expect(variantCount, equals(1));
    });

    test('handles circular sub-entity references without infinite loop', () async {
      // E2: Circular references (A -> B -> A)
      final entityADir = Directory('$outputDir/domain/entities/entity_a');
      await entityADir.create(recursive: true);
      await File(
        '$outputDir/domain/entities/entity_a/entity_a.dart',
      ).writeAsString('''
class EntityA {
  final String id;
  final EntityB? b;

  EntityA({required this.id, this.b});
}

class EntityAPatch {
  final String? id;
  final EntityB? b;

  EntityAPatch({this.id, this.b});
}

class EntityAFields {
  static const Field<EntityA, String> id = Field(name: 'id');
  static const Field<EntityA, EntityB> b = Field(name: 'b');
}
''');

      final entityBDir = Directory('$outputDir/domain/entities/entity_b');
      await entityBDir.create(recursive: true);
      await File(
        '$outputDir/domain/entities/entity_b/entity_b.dart',
      ).writeAsString('''
class EntityB {
  final String id;
  final EntityA? a;

  EntityB({required this.id, this.a});
}

class EntityBPatch {
  final String? id;
  final EntityA? a;

  EntityBPatch({this.id, this.a});
}

class EntityBFields {
  static const Field<EntityB, String> id = Field(name: 'id');
  static const Field<EntityB, EntityA> a = Field(name: 'a');
}
''');

      final cacheDir = Directory('$outputDir/cache');
      await cacheDir.create(recursive: true);
      await File('$outputDir/cache/entity_a_cache.dart').writeAsString('''
import 'package:zuraffa/zuraffa.dart';
import '../domain/entities/entity_a/entity_a.dart';

Future<void> initEntityACache() async {
  await Hive.openBox<EntityA>('entity_as');
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

      // Should complete without hanging (infinite loop protection)
      final result = await capability.execute({'name': 'EntityA'});
      expect(result.success, isTrue);

      final registrarFile = File('$outputDir/cache/hive_registrar.dart');
      final registrarContent = registrarFile.readAsStringSync();
      print('Registrar Content (circular):\n$registrarContent');

      // Both entities should be registered exactly once
      expect(registrarContent, contains('registerAdapter(EntityAAdapter())'));
      expect(registrarContent, contains('registerAdapter(EntityBAdapter())'));

      final parts = registrarContent.split('IsolatedHiveRegistrar');
      final aCount = 'registerAdapter(EntityAAdapter())'.allMatches(parts.first).length;
      final bCount = 'registerAdapter(EntityBAdapter())'.allMatches(parts.first).length;

      expect(aCount, equals(1), reason: 'EntityA should be registered exactly once');
      expect(bCount, equals(1), reason: 'EntityB should be registered exactly once');
    });

    test('creates registrar from scratch when it does not exist', () async {
      // E5: Registrar creation from scratch (no pre-existing cache files)
      final entityDir = Directory('$outputDir/domain/entities/standalone_entity');
      await entityDir.create(recursive: true);
      await File(
        '$outputDir/domain/entities/standalone_entity/standalone_entity.dart',
      ).writeAsString('''
class StandaloneEntity {
  final String id;
  final String value;

  StandaloneEntity({required this.id, required this.value});
}

class StandaloneEntityPatch {
  final String? id;
  final String? value;

  StandaloneEntityPatch({this.id, this.value});
}

class StandaloneEntityFields {
  static const Field<StandaloneEntity, String> id = Field(name: 'id');
  static const Field<StandaloneEntity, String> value = Field(name: 'value');
}
''');

      // NO cache files exist yet
      final cacheDir = Directory('$outputDir/cache');
      await cacheDir.create(recursive: true);
      // Only create timestamp_cache.dart (minimal trigger)
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
      final result = await capability.execute({'name': 'StandaloneEntity'});

      // Debug output
      print('Result success: ${result.success}');
      print('Result message: ${result.message}');
      print('Result files: ${result.files}');
      print('Result data: ${result.data}');

      expect(result.success, isTrue);

      final registrarFile = File('$outputDir/cache/hive_registrar.dart');
      expect(registrarFile.existsSync(), isTrue);
      final registrarContent = registrarFile.readAsStringSync();
      print('Registrar Content (from scratch):\n$registrarContent');

      // Verify full registrar structure
      expect(registrarContent, contains('extension HiveRegistrar on HiveInterface'));
      expect(registrarContent, contains('extension IsolatedHiveRegistrar on IsolatedHiveInterface'));
      expect(registrarContent, contains('@GenerateAdapters('));
      expect(registrarContent, contains("part 'hive_registrar.g.dart';"));
      expect(registrarContent, contains('AdapterSpec<StandaloneEntity>()'));
      expect(registrarContent, contains('registerAdapter(StandaloneEntityAdapter())'));

      // Manual additions should be created with header
      final manualAdditionsFile = File('$outputDir/cache/hive_manual_additions.txt');
      expect(manualAdditionsFile.existsSync(), isTrue);
      final manualContent = manualAdditionsFile.readAsStringSync();
      print('Manual Additions Content (from scratch):\n$manualContent');
      expect(manualContent, contains('# Hive Manual Additions'));
      expect(manualContent, contains('standalone_entity/standalone_entity.dart|StandaloneEntity'));
    });
  });
}
