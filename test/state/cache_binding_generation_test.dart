import 'dart:io';
import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

/// Tests that StateGenerator emits `..bindCache()` for @Cacheable slices
/// (Track 2.3 AC#1) and leaves non-cacheable slices untouched.
void main() {
  late Directory tempDir;
  late StateGenerator gen;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('zuraffa_cache_gen_');
    gen = StateGenerator(outputDir: tempDir.path);
  });

  tearDown(() => tempDir.deleteSync(recursive: true));

  group('Cache-binding generation (Track 2.3 AC#1)', () {
    test('cacheable slice emits ..bindCache() cascade', () {
      gen.generateDomainState(
        'ProductDetail',
        useCases: [
          UseCaseBinding(
            sliceKey: 'product',
            useCaseFieldName: 'getProductUseCase',
            paramsConstructor: 'GetProductParams',
            returnType: 'Product',
          ),
        ],
        cacheableSliceKeys: {'product'},
      );

      final content = File(
        '${tempDir.path}/product_detail_domain_state.dart',
      ).readAsStringSync();

      // The generated field must use a cascade so the field type stays
      // SignalSlice<T> while still subscribing to the CacheObserver.
      expect(
        content.contains("..bindCache()"),
        true,
        reason: 'cacheable slice should emit ..bindCache() cascade',
      );
      expect(content.contains('bind<Product>'), true);
    });

    test('multiple cacheable slices all emit ..bindCache()', () {
      gen.generateDomainState(
        'OrderDetail',
        useCases: [
          UseCaseBinding(
            sliceKey: 'order',
            useCaseFieldName: 'getOrderUseCase',
            paramsConstructor: 'GetOrderParams',
            returnType: 'Order',
          ),
          UseCaseBinding(
            sliceKey: 'items',
            useCaseFieldName: 'getItemsUseCase',
            paramsConstructor: 'GetItemsParams',
            returnType: 'List<OrderItem>',
          ),
          UseCaseBinding(
            sliceKey: 'history',
            useCaseFieldName: 'getHistoryUseCase',
            paramsConstructor: 'GetHistoryParams',
            returnType: 'List<History>',
          ),
        ],
        cacheableSliceKeys: {'order', 'items'},
      );

      final content = File(
        '${tempDir.path}/order_detail_domain_state.dart',
      ).readAsStringSync();

      // Count occurrences of ..bindCache()
      final count = '..bindCache()'.allMatches(content).length;
      expect(
        count,
        2,
        reason: 'exactly 2 cacheable slices should emit ..bindCache()',
      );
    });

    test('non-cacheable slices do NOT emit ..bindCache()', () {
      gen.generateDomainState(
        'ReviewList',
        useCases: [
          UseCaseBinding(
            sliceKey: 'reviews',
            useCaseFieldName: 'getReviewsUseCase',
            paramsConstructor: 'GetReviewsParams',
            returnType: 'List<Review>',
          ),
        ],
        // No cacheableSliceKeys — defaults to null
      );

      final content = File(
        '${tempDir.path}/review_list_domain_state.dart',
      ).readAsStringSync();

      expect(
        content.contains('..bindCache()'),
        false,
        reason: 'non-cacheable slice must NOT emit ..bindCache()',
      );
      expect(content.contains('bind<List<Review>>'), true);
    });

    test('mixed cacheable and non-cacheable slices', () {
      gen.generateDomainState(
        'Dashboard',
        useCases: [
          UseCaseBinding(
            sliceKey: 'profile',
            useCaseFieldName: 'getProfileUseCase',
            paramsConstructor: 'GetProfileParams',
            returnType: 'Profile',
          ),
          UseCaseBinding(
            sliceKey: 'settings',
            useCaseFieldName: 'getSettingsUseCase',
            paramsConstructor: 'GetSettingsParams',
            returnType: 'Settings',
          ),
        ],
        cacheableSliceKeys: {'profile'}, // only profile is cacheable
      );

      final content = File(
        '${tempDir.path}/dashboard_domain_state.dart',
      ).readAsStringSync();

      final count = '..bindCache()'.allMatches(content).length;
      expect(
        count,
        1,
        reason: 'only the cacheable slice should emit ..bindCache()',
      );
    });

    test('UseCaseBinding.cacheable flag is set correctly', () {
      final cacheable = UseCaseBinding(
        sliceKey: 'product',
        useCaseFieldName: 'getProductUseCase',
        paramsConstructor: 'GetProductParams',
        returnType: 'Product',
        cacheable: true,
      );
      final nonCacheable = UseCaseBinding(
        sliceKey: 'reviews',
        useCaseFieldName: 'getReviewsUseCase',
        paramsConstructor: 'GetReviewsParams',
        returnType: 'List<Review>',
      );

      expect(cacheable.cacheable, true);
      expect(nonCacheable.cacheable, false);
    });
  });
}
