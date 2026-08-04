import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

void main() {
  group('Golden: Track 6.2 — @Cacheable DDA Plugin', () {
    test('golden: @Cacheable on method collects entry', () {
      final gen = CacheGenerator();
      gen.addCacheableMethod(
        className: 'ProductRepositoryImpl',
        methodName: 'getProduct',
        importUri:
            'package:myapp/data/repositories/product_repository_impl.dart',
        returnType: 'Future<Product>',
        parameters: [const ParameterInfo(name: 'id', type: 'String')],
        ttl: const Duration(hours: 1),
      );

      expect(gen.hasEntries, isTrue);

      final output = gen.generate();

      expect(output, contains('ZfaCacheStore'));
      expect(output, contains('buildKey'));
      expect(output, contains('ProductRepositoryImpl'));
      expect(output, contains('getProduct'));
      expect(output, contains('zfa DDA pipeline'));
    });

    test('golden: offlineFirst strategy generates cache-then-network', () {
      final gen = CacheGenerator();
      gen.addCacheableMethod(
        className: 'ProductRepositoryImpl',
        methodName: 'getProductList',
        importUri:
            'package:myapp/data/repositories/product_repository_impl.dart',
        returnType: 'Future<List<Product>>',
        parameters: const [],
        strategy: CacheStrategy.offlineFirst,
      );

      final output = gen.generate();

      // offlineFirst: emit cache, then fetch network
      expect(output, contains('cachedSignal'));
      expect(output, contains('.get('));
      expect(output, contains('.put('));
    });

    test('golden: networkFirst strategy generates network-then-cache', () {
      final gen = CacheGenerator();
      gen.addCacheableMethod(
        className: 'CategoryRepositoryImpl',
        methodName: 'getCategories',
        importUri:
            'package:myapp/data/repositories/category_repository_impl.dart',
        returnType: 'Future<List<Category>>',
        parameters: const [],
        strategy: CacheStrategy.networkFirst,
      );

      final output = gen.generate();

      // networkFirst: try network, catch falls back to cache
      expect(output, contains('try {'));
      expect(output, contains('catch (e)'));
      expect(output, contains('.put('));
    });

    test('golden: cacheOnly strategy generates cache-only logic', () {
      final gen = CacheGenerator();
      gen.addCacheableMethod(
        className: 'ConfigRepositoryImpl',
        methodName: 'getCachedConfig',
        importUri:
            'package:myapp/data/repositories/config_repository_impl.dart',
        returnType: 'Future<Config?>',
        parameters: const [],
        strategy: CacheStrategy.cacheOnly,
      );

      final output = gen.generate();

      expect(output, contains('jsonDecode'));
      expect(output, contains('ConfigRepositoryImpl'));
    });

    test('golden: networkOnly strategy generates pass-through', () {
      final gen = CacheGenerator();
      gen.addCacheableMethod(
        className: 'LiveRepositoryImpl',
        methodName: 'getLiveFeed',
        importUri: 'package:myapp/data/repositories/live_repository_impl.dart',
        returnType: 'Future<List<Feed>>',
        parameters: const [],
        strategy: CacheStrategy.networkOnly,
      );

      final output = gen.generate();

      // networkOnly: pass through, no cache read/write
      expect(output, contains('networkOnly'));
      expect(output, contains('_source.getLiveFeed'));
    });

    test('golden: @CacheInvalidate generates invalidation calls', () {
      final gen = CacheGenerator();
      gen.addInvalidatorMethod(
        className: 'ProductRepositoryImpl',
        methodName: 'updateProduct',
        importUri:
            'package:myapp/data/repositories/product_repository_impl.dart',
        methods: ['getProduct', 'getProductList'],
        parameters: const [],
      );

      final output = gen.generate();

      expect(output, contains('WithInvalidate'));
      expect(output, contains('invalidateByPrefix'));
      expect(output, contains('getProduct'));
      expect(output, contains('getProductList'));
    });

    test('golden: TTL check skips expired entries', () {
      final gen = CacheGenerator();
      gen.addCacheableMethod(
        className: 'UserRepositoryImpl',
        methodName: 'getUser',
        importUri: 'package:myapp/data/repositories/user_repository_impl.dart',
        returnType: 'Future<User>',
        parameters: [const ParameterInfo(name: 'id', type: 'String')],
        ttl: const Duration(minutes: 30),
      );

      final output = gen.generate();

      // TTL enforcement in the store
      expect(output, contains('ttlMs'));
      expect(output, contains('cachedAt'));
      expect(output, contains('isExpired'));
    });

    test('golden: cache key derived from method name + arguments', () {
      final gen = CacheGenerator();
      gen.addCacheableMethod(
        className: 'ProductRepositoryImpl',
        methodName: 'getProduct',
        importUri:
            'package:myapp/data/repositories/product_repository_impl.dart',
        returnType: 'Future<Product>',
        parameters: [const ParameterInfo(name: 'id', type: 'String')],
        keyPrefix: 'product_detail',
      );

      final output = gen.generate();

      // Custom key prefix used
      expect(output, contains('product_detail'));
      expect(output, contains('buildKey'));
    });

    test('generator: direct CacheGenerator produces valid output', () {
      final gen = CacheGenerator();
      gen.addCacheableMethod(
        className: 'OrderRepositoryImpl',
        methodName: 'getOrders',
        importUri: 'package:myapp/data/order_repository_impl.dart',
        returnType: 'Future<List<Order>>',
        parameters: [
          const ParameterInfo(name: 'userId', type: 'String'),
          const ParameterInfo(
            name: 'status',
            type: 'String',
            isNamed: true,
            isOptional: true,
          ),
        ],
        ttl: const Duration(hours: 2),
        strategy: CacheStrategy.offlineFirst,
      );

      final output = gen.generate();

      expect(output, contains('ZfaCacheStore'));
      expect(output, contains('OrderRepositoryImpl'));
      expect(output, contains('getOrders'));
      expect(output, contains('userId'));
      expect(output, contains('buildKey'));
      expect(output, contains('jsonEncode'));
    });

    test(
      'acceptance: mixed @Cacheable + @CacheInvalidate produce complete file',
      () {
        final gen = CacheGenerator();

        // Cacheable: getProduct
        gen.addCacheableMethod(
          className: 'ProductRepositoryImpl',
          methodName: 'getProduct',
          importUri:
              'package:myapp/data/repositories/product_repository_impl.dart',
          returnType: 'Future<Product>',
          parameters: [const ParameterInfo(name: 'id', type: 'String')],
          ttl: const Duration(hours: 1),
        );

        // Cacheable: getProductList
        gen.addCacheableMethod(
          className: 'ProductRepositoryImpl',
          methodName: 'getProductList',
          importUri:
              'package:myapp/data/repositories/product_repository_impl.dart',
          returnType: 'Future<List<Product>>',
          parameters: const [],
          strategy: CacheStrategy.offlineFirst,
        );

        // CacheInvalidate: updateProduct
        gen.addInvalidatorMethod(
          className: 'ProductRepositoryImpl',
          methodName: 'updateProduct',
          importUri:
              'package:myapp/data/repositories/product_repository_impl.dart',
          methods: ['getProduct', 'getProductList'],
          parameters: const [],
        );

        final output = gen.generate();

        // ZfaCacheStore class
        expect(output, contains('class ZfaCacheStore'));
        expect(output, contains('Future<String?> get('));
        expect(output, contains('Future<void> put('));
        expect(output, contains('Future<void> invalidate('));
        expect(output, contains('buildKey'));

        // Cached method wrappers
        expect(output, contains('getProduct'));
        expect(output, contains('getProductList'));

        // Invalidation
        expect(output, contains('updateProduct'));
        expect(output, contains('invalidate'));

        // Import for repository
        expect(output, contains('product_repository_impl.dart'));
      },
    );
  });
}
