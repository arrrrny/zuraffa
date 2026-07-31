import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/zuraffa.dart';

void main() {
  group('SlicePresenter', () {
    test('bind creates slice and stores it', () {
      final presenter = _TestPresenter();
      expect(presenter.sliceKeys, {'product', 'reviews'});
      expect(presenter.sliceCount, 2);
    });

    test('slice retrieves by key', () {
      final presenter = _TestPresenter();
      expect(presenter.slice<int>('product'), isA<SignalSlice<int>>());
      expect(presenter.slice<String>('reviews'), isA<SignalSlice<String>>());
    });

    test('combinedState exposes all slices', () async {
      final presenter = _TestPresenter();
      final combined = presenter.combinedState;

      // Wait for slices to resolve
      await Future.delayed(const Duration(milliseconds: 10));

      expect(combined.value['product'], 42);
      expect(combined.value['reviews'], 'hello');
    });

    test('updating slice A does not affect slice B listeners', () async {
      final presenter = _TestPresenter();
      final productSlice = presenter.slice<int>('product')!;
      final reviewsSlice = presenter.slice<String>('reviews')!;

      // Wait for initial resolution so listeners attach post-resolve
      await productSlice.result.nextValue;
      await reviewsSlice.result.nextValue;

      var productUpdates = 0;
      var reviewsUpdates = 0;

      productSlice.listen((_, __) => productUpdates++);
      reviewsSlice.listen((_, __) => reviewsUpdates++);

      // Refresh only product
      productSlice.refresh(100);
      await productSlice.result.nextValue;

      // product listener should have fired (initial + refresh)
      expect(productUpdates, greaterThanOrEqualTo(2));
      // reviews listener should only have fired once (initial)
      expect(reviewsUpdates, 1);
    });

    test('refreshAll re-executes all slices', () async {
      final presenter = _TestPresenter();
      await Future.delayed(const Duration(milliseconds: 10));

      final product = presenter.slice<int>('product')!;
      final reviews = presenter.slice<String>('reviews')!;

      presenter.refreshAll();

      await product.result.nextValue;
      await reviews.result.nextValue;

      expect(product.isSuccess, true);
      expect(reviews.isSuccess, true);
    });

    test('dispose cleans up all slices', () {
      final presenter = _TestPresenter();
      presenter.dispose();
      expect(presenter.isDisposed, true);
      expect(() => presenter.slice<int>('product'), throwsStateError);
    });

    test('duplicate slice key throws', () {
      final presenter = _TestPresenter();
      expect(
        () => presenter.bind('product', _ConstUseCase<String>(), 'x'),
        throwsStateError,
      );
    });
  });
}

class _TestPresenter extends SlicePresenter {
  _TestPresenter() {
    bind('product', _ConstUseCase<int>(), 42);
    bind('reviews', _ConstUseCase<String>(), 'hello');
  }
}

class _ConstUseCase<T> extends ZuraffaUseCase<T, T> {
  @override
  SignalResult<T> call(T params, {ZuraffaContext? context}) {
    final sr = SignalResult<T>.initial(LoadingResult<T, AppFailure>.loading());
    Future.delayed(Duration.zero, () {
      if (!sr.isDisposed) sr.emitSuccess(params);
    });
    return sr;
  }
}
