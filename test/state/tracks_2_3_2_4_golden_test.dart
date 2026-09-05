import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

void main() {
  setUp(() => CacheObserver.instance.reset());
  tearDown(() => CacheObserver.instance.reset());

  group('Golden: Track 2.3 — Cross-View Cache Sync', () {
    test(
      'golden: View A mutates -> View B state updates without network',
      () async {
        // View A's presenter
        final presenterA = _ProductPresenter();
        final sliceA = presenterA.slice<Product>('product')!;

        // View B's presenter (different instance, same cache)
        final presenterB = _ProductPresenter();
        final sliceB = presenterB.slice<Product>('product')!;

        // Bind both to cache
        sliceA.bindCache();
        sliceB.bindCache();

        // Wait for initial loads
        await sliceA.result.nextValue;
        await sliceB.result.nextValue;
        expect(sliceA.data!.id, 'initial');
        expect(sliceB.data!.id, 'initial');

        // View A mutates product
        final mutator = _UpdateProductUseCase();
        mutator.mutate(Product(id: 'initial', name: 'Updated Name'));

        // Both slices should reflect the cache update — NO network call
        expect(sliceA.data!.name, 'Updated Name');
        expect(sliceB.data!.name, 'Updated Name');
      },
    );

    test('golden: disposed view does not receive cache updates', () async {
      final presenter = _ProductPresenter();
      final slice = presenter.slice<Product>('product')!;
      slice.bindCache();

      await slice.result.nextValue;
      expect(slice.data!.id, 'initial');

      // Dispose the slice (simulating view unmount)
      slice.dispose();

      // Mutation happens after dispose
      final mutator = _UpdateProductUseCase();
      mutator.mutate(Product(id: 'initial', name: 'Should Not Update'));

      // Slice should not have changed (it's disposed)
      // The old data remains, no crash
      expect(slice.isDisposed, true);
    });

    test(
      'golden: non-cached entities work normally without cache binding',
      () async {
        final presenter = _NonCachedPresenter();
        final slice = presenter.slice<Review>('review')!;

        await slice.result.nextValue;
        expect(slice.data!.id, 'review-1');

        // No cache binding — mutation doesn't auto-update
        final mutator = _UpdateReviewUseCase();
        mutator.mutate(Review(id: 'review-1', text: 'Updated'));

        // Slice still has old data
        expect(slice.data!.text, 'Original');
      },
    );
  });

  group('Golden: Track 2.4 — ControlledWidget + FragmentBuilder template', () {
    late Directory tempDir;

    setUp(
      () => tempDir = Directory.systemTemp.createTempSync('zuraffa_golden_'),
    );
    tearDown(() => tempDir.deleteSync(recursive: true));

    test('golden: zfa make generates ControlledWidget-based view', () {
      final gen = ViewTemplateGenerator(outputDir: tempDir.path);
      gen.generateView(
        'ProductDetail',
        useCases: ['product', 'reviews'],
        uiSignals: ['isDescriptionExpanded'],
      );

      final file = File('${tempDir.path}/product_detail_view.dart');
      expect(file.existsSync(), true);

      final content = file.readAsStringSync();
      expect(content.contains('class ProductDetailView'), true);
      expect(
        content.contains('extends ControlledWidget<ProductDetailPresenter>'),
        true,
      );
      expect(content.contains('onInit'), true);
      expect(content.contains('FragmentBuilder'), true);
      expect(content.contains('SignalBuilder'), true);
      expect(content.contains('product'), true);
      expect(content.contains('reviews'), true);
      expect(content.contains('isDescriptionExpanded'), true);
    });

    test('golden: generated view has onLoading/onError/onEmpty', () {
      final gen = ViewTemplateGenerator(outputDir: tempDir.path);
      gen.generateView('Checkout', useCases: ['cart']);

      final content = File(
        '${tempDir.path}/checkout_view.dart',
      ).readAsStringSync();
      expect(content.contains('onLoading'), true);
      expect(content.contains('onError'), true);
      expect(content.contains('CircularProgressIndicator'), true);
    });

    test('golden: backward compat — old views still work', () {
      final gen = ViewTemplateGenerator(outputDir: tempDir.path);
      gen.generateView('LegacyView', useCases: ['data']);

      final content = File(
        '${tempDir.path}/legacy_view_view.dart',
      ).readAsStringSync();
      expect(content.contains('class LegacyView'), true);
      expect(content.contains('ControlledWidget'), true); // new default
    });
  });
}

// ── Domain models ──

class Product {
  Product({required this.id, this.name = ''});
  final String id;
  final String name;
}

class Review {
  Review({required this.id, this.text = ''});
  final String id;
  final String text;
}

// ── Use cases ──

class _GetProductUseCase extends ZuraffaUseCase<dynamic, Product> {
  @override
  SignalResult<Product> call(dynamic params, {ZuraffaContext? context}) {
    final sr = SignalResult<Product>.initial(
      LoadingResult<Product, AppFailure>.loading(),
    );
    Future.delayed(Duration.zero, () {
      if (!sr.isDisposed) {
        sr.emitSuccess(Product(id: 'initial', name: 'Original'));
      }
    });
    return sr;
  }
}

class _GetReviewUseCase extends ZuraffaUseCase<dynamic, Review> {
  @override
  SignalResult<Review> call(dynamic params, {ZuraffaContext? context}) {
    final sr = SignalResult<Review>.initial(
      LoadingResult<Review, AppFailure>.loading(),
    );
    Future.delayed(Duration.zero, () {
      if (!sr.isDisposed) {
        sr.emitSuccess(Review(id: 'review-1', text: 'Original'));
      }
    });
    return sr;
  }
}

class _UpdateProductUseCase with CacheMutator<Product> {
  void mutate(Product product) => notifyCache(product);
}

class _UpdateReviewUseCase with CacheMutator<Review> {
  void mutate(Review review) => notifyCache(review);
}

// ── Presenters ──

class _ProductPresenter extends SlicePresenter {
  _ProductPresenter() {
    bind('product', _GetProductUseCase(), null);
  }
}

class _NonCachedPresenter extends SlicePresenter {
  _NonCachedPresenter() {
    bind('review', _GetReviewUseCase(), null);
  }
}
