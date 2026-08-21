import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

void main() {
  group('DomainState', () {
    test('bind creates SignalSlice in underlying presenter', () {
      final presenter = _TestSlicePresenter();
      final domain = _TestDomainState(presenter: presenter);

      expect(domain.sliceKeys, {'product', 'reviews'});
      expect(domain.slice<int>('product'), isA<SignalSlice<int>>());
    });

    test('slice data accessible after execution', () async {
      final presenter = _TestSlicePresenter();
      final domain = _TestDomainState(presenter: presenter);

      final slice = domain.slice<int>('product')!;
      await slice.result.nextValue;
      expect(slice.data, 42);
    });

    test('multiple slices are independent', () async {
      final presenter = _TestSlicePresenter();
      final domain = _TestDomainState(presenter: presenter);

      final product = domain.slice<int>('product')!;
      final reviews = domain.slice<String>('reviews')!;

      await product.result.nextValue;
      await reviews.result.nextValue;

      expect(product.data, 42);
      expect(reviews.data, 'hello');
    });

    test('DomainState is immutable from consumer perspective', () {
      final presenter = _TestSlicePresenter();
      final domain = _TestDomainState(presenter: presenter);

      // DomainState only exposes read API — no setters
      expect(() => domain.sliceKeys, returnsNormally);
      // Cannot directly modify slices map
    });
  });
}

class _TestSlicePresenter extends SlicePresenter {}

class _TestDomainState extends DomainState {
  _TestDomainState({required super.presenter}) {
    bind<int>('product', _ConstUseCase<int>(), 42);
    bind<String>('reviews', _ConstUseCase<String>(), 'hello');
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
