import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/zuraffa.dart';

void main() {
  group('DualLayerPresenter', () {
    test('separates domain and view state', () {
      final presenter = _TestDualLayerPresenter();
      expect(presenter.domain, isA<DomainState>());
      expect(presenter.view, isA<ViewState>());
    });

    test('domain slices accessible through presenter', () async {
      final presenter = _TestDualLayerPresenter();
      final product = presenter.domain.slice<int>('product')!;

      await product.result.nextValue;
      expect(product.data, 42);
    });

    test('view state signals accessible through presenter', () {
      final presenter = _TestDualLayerPresenter();
      final view = presenter.view as _TestViewState;
      expect(view.isDropdownOpen.value, false);

      view.isDropdownOpen.value = true;
      expect(view.isDropdownOpen.value, true);
    });

    test('combinedState merges domain and view data', () async {
      final presenter = _TestDualLayerPresenter();
      final product = presenter.domain.slice<int>('product')!;
      await product.result.nextValue;

      final combined = presenter.combinedState;
      expect(combined['product'], 42);
    });

    test('dispose cleans up both domain and view state', () {
      final presenter = _TestDualLayerPresenter();
      presenter.dispose();

      // View state signals are disposed.
      expect(presenter.view.isActive, false);
      // Domain slices are disposed via the underlying SlicePresenter.
      expect(() => presenter.domain.slice<int>('product'), throwsStateError);
    });
  });
}

class _TestSlicePresenter extends SlicePresenter {}

class _TestDomainState extends DomainState {
  _TestDomainState({required super.presenter}) {
    bind<int>('product', _ConstUseCase<int>(), 42);
  }
}

class _TestViewState extends ViewState {
  _TestViewState() : super() {
    registerSignal(isDropdownOpen);
  }

  final isDropdownOpen = Signal<bool>(false);
}

class _TestDualLayerPresenter extends DualLayerPresenter {
  _TestDualLayerPresenter()
    : super(
        domain: _TestDomainState(presenter: _TestSlicePresenter()),
        view: _TestViewState(),
      );
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
