import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

/// SC-001 acceptance (spec 038): a developer creates a view with a typed
/// controller, lifecycle hooks, and slice-scoped rebuilds — with zero manual
/// lifecycle wiring or rebuild logic. The view below is hand-shaped exactly
/// like `ViewTemplateGenerator.generateView(..., pureDart: true)` output
/// (A3 proves that artifact compiles; this test proves the pattern RUNS).
void main() {
  test(
    'typed-controller view runs end to end with no manual wiring [A1]',
    () async {
      final presenter = CatalogPresenter();
      final view = CatalogView(controller: presenter);
      final host = WidgetHost(view);

      int initCalls = 0;
      int disposeCalls = 0;
      // The ONLY wiring the developer writes: mount and unmount.
      host.mount();

      // onInit fired exactly once and triggered the products slice refresh.
      expect(view.initSeen, 1);
      initCalls = view.initSeen;

      // While loading, the fragment renders the loading state.
      final products = view.productsFragment;
      expect(products.state, FragmentState.loading);
      expect(products.output, 'products loading');

      // The async use case resolves.
      await pumpEventQueue();

      expect(
        products.state,
        FragmentState.data,
        reason: 'slice data arrived and rebuilt the fragment automatically',
      );
      expect(products.output, 'products:3');
      expect(view.uiFragment.output, 'isLoading: false');

      // Signal change — only the signal builder rebuilt.
      presenter.view.isLoading.value = true;
      expect(view.uiFragment.output, 'isLoading: true');
      expect(
        view.uiFragment.rebuildCount,
        2,
        reason: 'initial eager delivery + one signal change',
      );
      expect(
        products.rebuildCount,
        2,
        reason: 'UI signal change did not rebuild the domain fragment',
      );
      expect(host.buildCount, 1, reason: 'the view shell never re-ran build');

      host.unmount();
      disposeCalls = view.disposeSeen;
      expect(initCalls, 1);
      expect(disposeCalls, 1, reason: 'automatic teardown fired exactly once');
      expect(
        presenter.domain.sliceKeys,
        contains('products'),
        reason: 'the lazy slice was bootstrapped by the view itself',
      );
      expect(
        view.productsFragment.isAttached,
        isFalse,
        reason: 'fragment subscriptions were cancelled automatically',
      );
    },
  );
}

// ── The developer-facing pieces (generated-view shape) ─────────────────────

class CatalogPresenter extends DualLayerPresenter {
  CatalogPresenter()
    : super(domain: CatalogDomainState(), view: CatalogViewState());

  @override
  CatalogViewState get view => super.view as CatalogViewState;

  @override
  CatalogDomainState get domain => super.domain as CatalogDomainState;
}

class CatalogDomainState extends DomainState {
  CatalogDomainState() : super(presenter: _CatalogSlicePresenter());

  // Late-final slice field, mirroring generateDomainState output.
  late final products = bind<Map<String, Object?>>(
    'products',
    _CatalogProductsUseCase(),
    null,
  );
}

class _CatalogSlicePresenter extends SlicePresenter {
  _CatalogSlicePresenter() : super();
}

class CatalogViewState extends ViewState {
  CatalogViewState() {
    registerSignal(isLoading);
  }

  final isLoading = Signal<bool>(false);
}

class _CatalogProductsUseCase
    extends ZuraffaUseCase<dynamic, Map<String, Object?>> {
  @override
  SignalResult<Map<String, Object?>> call(
    dynamic params, {
    ZuraffaContext? context,
  }) {
    final result = SignalResult<Map<String, Object?>>.initial(
      LoadingResult<Map<String, Object?>, AppFailure>.loading(),
    );
    Future(() {
      if (!result.isDisposed) {
        result.emitSuccess({'count': 3});
      }
    });
    return result;
  }
}

class CatalogView extends ControlledWidget<CatalogPresenter> {
  CatalogView({required super.controller});

  int initSeen = 0;
  int disposeSeen = 0;
  late final FragmentBuilder<Map<String, Object?>> productsFragment;
  late final SignalBuilder<bool> uiFragment;

  @override
  void onInit() {
    initSeen++;
    // Typed controller access — no casts, no DI lookups, no manual wiring.
    // Touching the late-final field bootstraps the lazy slice binding.
    controller.domain.products.refresh();
  }

  @override
  void onDispose() => disposeSeen++;

  @override
  Object? build(ViewContext context) {
    productsFragment = context.attach(
      FragmentBuilder<Map<String, Object?>>(
        slice: controller.domain.products,
        onLoading: (context) => 'products loading',
        onError: (context, error) => 'error: ${error.message}',
        builder: (context, data) => 'products:${data['count']}',
      ),
    );
    uiFragment = context.attach(
      SignalBuilder<bool>(
        signal: controller.view.isLoading,
        builder: (context, value) => 'isLoading: $value',
      ),
    );
    return null;
  }
}
