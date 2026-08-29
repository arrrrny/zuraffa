import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

/// SC-002 acceptance (spec 038): changing one signal slice in a view rebuilds
/// only the subtree bound to that slice; sibling slice builders and unrelated
/// widgets are NOT rebuilt — confirmed by rebuild counting through the full
/// DualLayerPresenter stack.
void main() {
  test('slice change rebuilds only its bound fragment [A2]', () {
    final presenter = DashboardPresenter();
    final view = DashboardView(controller: presenter);
    final host = WidgetHost(view);
    host.mount();

    final salesFragment = view.salesFragment;
    final stockFragment = view.stockFragment;
    final uiFragment = view.headerFragment;

    // After mount: each fragment processed its eager initial emission.
    final salesBase = salesFragment.rebuildCount;
    final stockBase = stockFragment.rebuildCount;
    final uiBase = uiFragment.rebuildCount;
    expect(salesBase, 1);
    expect(stockBase, 1);

    // Change ONLY the sales slice (refresh through the real presenter API).
    presenter.refreshSales();

    expect(
      salesFragment.rebuildCount,
      salesBase + 1,
      reason: 'the sales fragment rebuilt exactly once',
    );
    expect(salesFragment.output, 'sales:2');
    expect(
      stockFragment.rebuildCount,
      stockBase,
      reason: 'SC-002: the sibling stock fragment did NOT rebuild',
    );
    expect(
      uiFragment.rebuildCount,
      uiBase,
      reason: 'SC-002: the unrelated UI signal builder did NOT rebuild',
    );
    expect(
      host.buildCount,
      1,
      reason: 'SC-002: the view shell did NOT rebuild',
    );

    // Change ONLY the stock slice.
    presenter.refreshStock();

    expect(stockFragment.rebuildCount, stockBase + 1);
    expect(stockFragment.output, 'stock:2');
    expect(
      salesFragment.rebuildCount,
      salesBase + 1,
      reason: 'sales fragment unaffected by a stock change',
    );
    expect(host.buildCount, 1);

    host.unmount();
  });
}

class DashboardPresenter extends DualLayerPresenter {
  DashboardPresenter()
    : super(domain: DashboardDomainState(), view: DashboardViewState());

  @override
  DashboardViewState get view => super.view as DashboardViewState;

  @override
  DashboardDomainState get domain => super.domain as DashboardDomainState;

  void refreshSales() => domain.sales.refresh();
  void refreshStock() => domain.stock.refresh();
}

class DashboardDomainState extends DomainState {
  DashboardDomainState() : super(presenter: _DashboardSlicePresenter());

  int _salesCalls = 0;
  int _stockCalls = 0;

  late final sales = bind<int>(
    'sales',
    _CountingUseCase(() => ++_salesCalls),
    null,
  );
  late final stock = bind<int>(
    'stock',
    _CountingUseCase(() => ++_stockCalls),
    null,
  );
}

class _DashboardSlicePresenter extends SlicePresenter {
  _DashboardSlicePresenter() : super();
}

class DashboardViewState extends ViewState {
  DashboardViewState() {
    registerSignal(title);
  }

  final title = Signal<String>('dashboard');
}

class _CountingUseCase extends ZuraffaUseCase<dynamic, int> {
  _CountingUseCase(this._counter);

  final int Function() _counter;

  @override
  SignalResult<int> call(dynamic params, {ZuraffaContext? context}) {
    // Synchronous success — each refresh resolves immediately with a new
    // value, so a refresh is exactly one observable rebuild.
    return SignalResult<int>.success(_counter());
  }
}

class DashboardView extends ControlledWidget<DashboardPresenter> {
  DashboardView({required super.controller});

  late final FragmentBuilder<int> salesFragment;
  late final FragmentBuilder<int> stockFragment;
  late final SignalBuilder<String> headerFragment;

  @override
  Object? build(ViewContext context) {
    salesFragment = context.attach(
      FragmentBuilder<int>(
        slice: controller.domain.sales,
        builder: (context, data) => 'sales:$data',
      ),
    );
    stockFragment = context.attach(
      FragmentBuilder<int>(
        slice: controller.domain.stock,
        builder: (context, data) => 'stock:$data',
      ),
    );
    headerFragment = context.attach(
      SignalBuilder<String>(
        signal: controller.view.title,
        builder: (context, value) => 'title:$value',
      ),
    );
    return null;
  }
}
