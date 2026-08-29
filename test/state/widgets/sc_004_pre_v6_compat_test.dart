import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

/// SC-004 acceptance (spec 038, FR-006): a view written against the pre-v6
/// pattern — combined state object, full-widget rebuild, no widget layer —
/// compiles and behaves identically on v6. The new widget layer is purely
/// additive; nothing in the pre-v6 path changed.
///
/// The existing pre-v6 suites (slice_presenter_test, dual_layer_presenter_
/// test, signal_slice_test, state_generator_test, golden_test, and the
/// migration tests) re-run unmodified in this branch — that is the "existing
/// pre-v6 view test suite runs against the v6 framework" half of SC-004.
/// This file adds the representative full-rebuild view pattern.
void main() {
  test('pre-v6 combined-state view behaves identically on v6 [A4]', () {
    final presenter = _LegacyPresenter();
    final view = _LegacyFullRebuildView(presenter);

    // Pre-v6 wiring: manual subscription, manual full rebuild.
    view.startListening();
    expect(
      view.rebuildCount,
      1,
      reason: 'eager initial combined state rebuilds the whole view',
    );
    expect(view.lastState['orders'], 1);
    expect(view.lastState['customers'], 1);

    // Any slice change rebuilds the WHOLE view — the pre-v6 contract.
    presenter.refresh('orders');
    expect(view.rebuildCount, 2);
    expect(view.lastState['orders'], 2);

    presenter.refresh('customers');
    expect(
      view.rebuildCount,
      3,
      reason:
          'a different slice change also rebuilds the whole view '
          '(pre-v6 full-rebuild semantics preserved)',
    );
    expect(view.lastState['customers'], 2);
    expect(
      view.lastState['orders'],
      2,
      reason: 'combined state still carries all slices',
    );

    // The v6 widget layer coexists without interfering: mounting a v6 view
    // does not disturb the legacy subscription.
    final host = WidgetHost<_Nil>(_NilView(controller: _Nil()));
    host.mount();
    host.unmount();
    expect(
      view.rebuildCount,
      3,
      reason: 'v6 mount/unmount does not disturb legacy subscriptions',
    );

    view.stopListening();
    presenter.refresh('orders');
    expect(view.rebuildCount, 3, reason: 'manual dispose semantics unchanged');
  });
}

class _Nil {}

class _NilView extends ControlledWidget<_Nil> {
  _NilView({required super.controller});
}

class _LegacyPresenter extends SlicePresenter {
  int _orders = 0;
  int _customers = 0;

  _LegacyPresenter() : super() {
    bind<int>('orders', _AdvancingUseCase(() => ++_orders), null);
    bind<int>('customers', _AdvancingUseCase(() => ++_customers), null);
  }

  void refresh(String key) => slice<int>(key)?.refresh();
}

/// A use case whose value advances whenever it is (re)executed.
class _AdvancingUseCase extends ZuraffaUseCase<dynamic, int> {
  _AdvancingUseCase(this._next);

  final int Function() _next;

  @override
  SignalResult<int> call(dynamic params, {ZuraffaContext? context}) =>
      SignalResult<int>.success(_next());
}

class _LegacyFullRebuildView {
  _LegacyFullRebuildView(this._presenter);

  final _LegacyPresenter _presenter;
  SignalSubscription? _subscription;
  int rebuildCount = 0;
  Map<String, dynamic> lastState = {};

  void startListening() {
    // Pre-v6 pattern: ONE subscription to the combined state object drives
    // the ENTIRE view rebuild.
    _subscription = _presenter.combinedState.listen((state) {
      rebuildCount++;
      lastState = state;
    });
  }

  void stopListening() {
    _subscription?.cancel();
  }
}
