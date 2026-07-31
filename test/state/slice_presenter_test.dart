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

      // Await each slice resolution instead of wall-clock delay
      await presenter.slice<int>('product')!.result.nextValue;
      await presenter.slice<String>('reviews')!.result.nextValue;

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

      productSlice.listen((_, _) => productUpdates++);
      reviewsSlice.listen((_, _) => reviewsUpdates++);

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
      final product = presenter.slice<int>('product')!;
      final reviews = presenter.slice<String>('reviews')!;

      // Trigger initial execution
      await product.result.nextValue;
      await reviews.result.nextValue;
      final productCallsBefore = _ProductUseCase.invocationCount;
      final reviewsCallsBefore = _ReviewsUseCase.invocationCount;

      presenter.refreshAll();

      // Wait for the refreshed results to resolve
      await product.result.nextValue;
      await reviews.result.nextValue;

      // Both use cases must have been re-invoked (counts increased)
      expect(_ProductUseCase.invocationCount, greaterThan(productCallsBefore));
      expect(_ReviewsUseCase.invocationCount, greaterThan(reviewsCallsBefore));
      expect(_ReviewsUseCase.invocationCount, greaterThan(reviewsCallsBefore));
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
        () => presenter.bind('product', _ProductUseCase(), 1),
        throwsStateError,
      );
    });
  });
}

class _ProductUseCase extends ZuraffaUseCase<int, int> {
  static int invocationCount = 0;

  @override
  SignalResult<int> call(int params, {ZuraffaContext? context}) {
    invocationCount++;
    final sr = SignalResult<int>.initial(
      LoadingResult<int, AppFailure>.loading(),
    );
    Future.delayed(Duration.zero, () {
      if (!sr.isDisposed) sr.emitSuccess(params);
    });
    return sr;
  }
}

class _ReviewsUseCase extends ZuraffaUseCase<String, String> {
  static int invocationCount = 0;

  @override
  SignalResult<String> call(String params, {ZuraffaContext? context}) {
    invocationCount++;
    final sr = SignalResult<String>.initial(
      LoadingResult<String, AppFailure>.loading(),
    );
    Future.delayed(Duration.zero, () {
      if (!sr.isDisposed) sr.emitSuccess(params);
    });
    return sr;
  }
}

class _TestPresenter extends SlicePresenter {
  _TestPresenter() {
    bind('product', _ProductUseCase(), 42);
    bind('reviews', _ReviewsUseCase(), 'hello');
  }
}
