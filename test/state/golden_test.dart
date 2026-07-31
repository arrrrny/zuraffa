import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/zuraffa.dart';

/// Golden test: N-use-case presenter -> N slices generated in .state.dart
void main() {
  group('Golden: Signal Slices', () {
    test('golden: 3-use-case presenter has 3 isolated slices', () async {
      final presenter = _ProductDetailPresenter();

      expect(presenter.sliceCount, 3);
      expect(presenter.sliceKeys, {'product', 'reviews', 'related'});

      // Each slice is independent
      final product = presenter.slice<Product>('product')!;
      final reviews = presenter.slice<List<Review>>('reviews')!;
      final related = presenter.slice<List<Product>>('related')!;

      // Trigger and await each slice resolution
      await product.result.nextValue;
      await reviews.result.nextValue;
      await related.result.nextValue;

      expect(product.data, isA<Product>());
      expect(reviews.data, isA<List<Review>>());
      expect(related.data, isA<List<Product>>());
    });

    test('golden: combinedState has all slice data', () async {
      final presenter = _ProductDetailPresenter();
      final combined = presenter.combinedState;

      await Future.delayed(const Duration(milliseconds: 20));

      final state = combined.value;
      expect(state['product'], isA<Product>());
      expect(state['reviews'], isA<List<Review>>());
      expect(state['related'], isA<List<Product>>());
    });

    test('golden: updating one slice does not trigger others', () async {
      final presenter = _ProductDetailPresenter();
      final product = presenter.slice<Product>('product')!;
      final reviews = presenter.slice<List<Review>>('reviews')!;

      // Wait for initial resolution
      await product.result.nextValue;
      await reviews.result.nextValue;

      var productCount = 0;
      var reviewsCount = 0;

      product.listen((_, __) => productCount++);
      reviews.listen((_, __) => reviewsCount++);

      // Refresh only product
      product.refresh('new');
      await product.result.nextValue;

      // Product got initial + refresh = 2+
      expect(productCount, greaterThanOrEqualTo(2));
      // Reviews only got initial = 1
      expect(reviewsCount, 1);
    });

    test('golden: backward compat combinedState works', () async {
      final presenter = _ProductDetailPresenter();
      final combined = presenter.combinedState;

      await Future.delayed(const Duration(milliseconds: 20));

      // Old-style view can read full state map
      final state = combined.value;
      expect(state.containsKey('product'), true);
      expect(state.containsKey('reviews'), true);
      expect(state.containsKey('related'), true);
    });
  });
}

// ── Domain models ──

class Product {
  Product({this.id = '1'});
  final String id;
}

class Review {
  Review({this.text = 'great'});
  final String text;
}

// ── Use cases ──

class _GetProductUseCase extends ZuraffaUseCase<String, Product> {
  @override
  SignalResult<Product> call(String params, {ZuraffaContext? context}) {
    final sr = SignalResult<Product>.initial(
      LoadingResult<Product, AppFailure>.loading(),
    );
    Future.delayed(Duration.zero, () {
      if (!sr.isDisposed) sr.emitSuccess(Product(id: params));
    });
    return sr;
  }
}

class _GetReviewsUseCase extends ZuraffaUseCase<String, List<Review>> {
  @override
  SignalResult<List<Review>> call(String params, {ZuraffaContext? context}) {
    final sr = SignalResult<List<Review>>.initial(
      LoadingResult<List<Review>, AppFailure>.loading(),
    );
    Future.delayed(Duration.zero, () {
      if (!sr.isDisposed) sr.emitSuccess([Review(text: 'nice')]);
    });
    return sr;
  }
}

class _GetRelatedUseCase extends ZuraffaUseCase<String, List<Product>> {
  @override
  SignalResult<List<Product>> call(String params, {ZuraffaContext? context}) {
    final sr = SignalResult<List<Product>>.initial(
      LoadingResult<List<Product>, AppFailure>.loading(),
    );
    Future.delayed(Duration.zero, () {
      if (!sr.isDisposed) sr.emitSuccess([Product(id: 'related-1')]);
    });
    return sr;
  }
}

// ── Presenter ──

class _ProductDetailPresenter extends SlicePresenter {
  _ProductDetailPresenter() {
    bind('product', _GetProductUseCase(), 'p1');
    bind('reviews', _GetReviewsUseCase(), 'p1');
    bind('related', _GetRelatedUseCase(), 'p1');
  }
}
