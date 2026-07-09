# Presentation Layer

Zuraffa's presentation pattern is **Controller-first** (a Clean Architecture adaptation of Model-View-ViewModel) with an optional **Presenter** layer for complex orchestration.

## Architecture

```
View (CleanView) → Controller (ChangeNotifier) → UseCase → Repository → DataSource
                     ↑ (Provider Consumer)
              ControlledWidgetBuilder rebuilds on notifyListeners()
```

Controllers live as long as their View state lives (not recreated on each rebuild). They manage UI state, execute UseCases, and notify the view of changes via Provider's `Consumer`.

## Controller — `lib/src/presentation/controller.dart`

The central class for all presentation logic. Extends `ChangeNotifier` and mixes in `WidgetsBindingObserver` and `RouteAware`.

```dart
class ProductController extends Controller with StatefulController<ProductState> {
  final GetProductsUseCase _getProducts;
  final CreateProductUseCase _createProduct;

  ProductController(this._getProducts, this._createProduct);

  @override
  ProductState createInitialState() => ProductState.initial();

  Future<void> loadProducts() async {
    final result = await execute(_getProducts.call(NoParams()));
    result.fold(
      (products) => updateState((state) => state.copyWith(products: products)),
      (failure) => updateState((state) => state.copyWith(error: failure.message)),
    );
  }
}
```

### Key Features

| Feature | Description |
|---|---|
| `execute()` | Run a single UseCase with auto-cancellation on dispose |
| `executeStream()` | Subscribe to a `StreamUseCase` with auto-cleanup |
| `executeAll()` | Run multiple UseCases in parallel |
| `executeSequential()` | Run UseCases one at a time |
| `cancelAll()` | Cancel all pending operations |
| Lifecycle callbacks | `onInitState`, `onResumed`, `onPaused`, `onDisposed` |

### StatefulController Mixin

Adds typed state management:

```dart
mixin StatefulController<S> on Controller {
  S get viewState;
  void updateState(S Function(S state) updater);    // Update + notifyListeners
  void resetState();                                 // Reset to initial
  S createInitialState();                            // Override to define initial state
}
```

Each `updateState()` call triggers `refreshUI()` → `notifyListeners()` → view rebuilds via Provider's `Consumer`.

## View — `lib/src/presentation/view.dart`

```dart
class ProductView extends CleanView<ProductController, ProductState> {
  const ProductView({super.key});

  @override
  CleanViewState<ProductController, ProductState> createState() => _ProductViewState();
}

class _ProductViewState extends CleanViewState<ProductController, ProductState> {
  @override
  Widget build(BuildContext context) {
    return ControlledWidgetBuilder<ProductController>(
      builder: (context, controller) {
        final state = controller.viewState;
        if (state.isLoading) return const CircularProgressIndicator();
        return ListView.builder(
          itemCount: state.products.length,
          itemBuilder: (context, index) => Text(state.products[index].name),
        );
      },
    );
  }
}
```

**`CleanViewState`** provides:
- `controller` — Access to the controller (injected via constructor)
- `globalKey` — Required on the root widget (for access to state)
- Lifecycle hooks: `onInitState`, `onViewStateChanged`

### ControlledWidgetBuilder

```dart
class ControlledWidgetBuilder<Con extends Controller> extends StatelessWidget {
  final Widget Function(BuildContext context, Con controller) builder;
  // ...
}
```

A `StatelessWidget` wrapping Provider's `Consumer<Con>`. Only rebuilds the subtree when the controller notifies listeners. A `ControlledWidgetBuilderWithChild` variant exists for performance optimization.

## Presenter — `lib/src/presentation/presenter.dart`

Optional layer for flows that coordinate multiple UseCases (e.g., checkout, multi-step forms):

```dart
class CheckoutPresenter extends Presenter {
  final GetCartUseCase _getCart;
  final CreateOrderUseCase _createOrder;
  final ProcessPaymentUseCase _processPayment;

  CheckoutPresenter(this._getCart, this._createOrder, this._processPayment);

  Future<Result<Order, AppFailure>> checkout() async {
    // Orchestrate multiple UseCases with shared state
  }
}
```

Presenters have lifecycle management (disposable subscriptions and cancel tokens) and registered UseCases that auto-dispose.

## Responsive Views — `lib/src/presentation/responsive_view.dart`

`ResponsiveViewState` extends `CleanViewState` with responsive breakpoints using the `responsive_builder` package:

```dart
class _ProductViewState extends ResponsiveViewState<ProductController, ProductState> {
  @override
  Widget desktop() => DesktopProductLayout(controller: controller);

  @override
  Widget tablet() => TabletProductLayout(controller: controller);

  @override
  Widget mobile() => MobileProductLayout(controller: controller);

  @override
  Widget watch() => WatchProductLayout(controller: controller);
}
```

Breakpoints cascade: desktop → tablet → mobile → watch (less-specific layouts inherit from more-specific).

## Adaptive Views — `lib/src/presentation/adaptive_view.dart`

`AdaptiveViewState` extends `CleanViewState` with platform-aware layout resolution:

```dart
class _ProductViewState extends AdaptiveViewState<ProductController, ProductState> {
  @override
  Map<Object, WidgetBuilder> get layouts => {
    PlatformClass.macos: (ctx, ctrl) => MacOSProductLayout(controller: ctrl),
    PlatformClass.desktop: (ctx, ctrl) => DesktopProductLayout(controller: ctrl),
    PlatformClass.mobile: (ctx, ctrl) => MobileProductLayout(controller: ctrl),
    'default': (ctx, ctrl) => DefaultProductLayout(controller: ctrl),
  };
}
```

Layout resolution uses compound keys sorted by specificity (e.g., `macos_desktop` > `macos` > `desktop` > `default`).

## Platform Detection — `lib/src/presentation/platform/`

| File | Content |
|---|---|
| `platform_context.dart` | `PlatformContext` — current platform + device class detection |
| `device_class.dart` | `DeviceClass` enum (mobile, tablet, desktop, watch) |
| `platform_class.dart` | `PlatformClass` enum (iOS, android, macOS, windows, linux, web) |
| `platform_layout_resolver.dart` | Concrete layout picking logic |

## App Shells — `lib/src/presentation/shells/`

Platform-adaptive app shells:

| Shell | Purpose |
|---|---|
| `AppShellResolver` | Resolves the correct shell per platform |
| `MobileAppShell` | Bottom navigation, drawer |
| `DesktopAppShell` | Sidebar navigation |
| `MacOSAppShell` | macOS-specific navigation |
| `TabletAppShell` | Hybrid navigation |

## Generated Code Example

When generating with `zfa make Product --with=vpc --state`:

```
lib/src/presentation/
├── controllers/
│   └── product_controller.dart    # Extends Controller + StatefulController
├── presenters/
│   └── product_presenter.dart     # Extends Presenter (if --presenter flag set)
├── states/
│   └── product_state.dart         # Immutable state class with copyWith
└── views/
    └── product_view.dart          # CleanView with responsive/adaptive layout
```

## Source Map

```
lib/src/presentation/
├── controller.dart            # Controller base class with lifecycle, UseCase execution
├── controlled_widget.dart     # ControlledWidgetBuilder (Provider Consumer wrapper)
├── presenter.dart             # Optional multi-UseCase orchestration
├── view.dart                  # CleanView + CleanViewState base classes
├── responsive_view.dart       # ResponsiveViewState with breakpoints
├── adaptive_view.dart         # AdaptiveViewState with platform-aware layouts
├── platform/
│   ├── platform_context.dart       # Platform detection
│   ├── device_class.dart           # Device class enum
│   ├── platform_class.dart         # Platform enum
│   └── platform_layout_resolver.dart # Layout resolution
└── shells/
    ├── app_shell_resolver.dart     # Shell resolution per platform
    ├── desktop_app_shell.dart      # Desktop sidebar shell
    ├── macos_app_shell.dart        # macOS-specific shell
    ├── mobile_app_shell.dart       # Mobile bottom-nav shell
    └── tablet_app_shell.dart       # Tablet hybrid shell
```

## Change Guidance

- **State management choice:** Zuraffa uses Provider (ChangeNotifier). Controllers are long-lived and state is typed via `StatefulController`.
- **Adding new view layouts:** Extend `ResponsiveViewState` for breakpoint-based layouts, or `AdaptiveViewState` for platform-aware layouts.
- **Complex UseCase orchestration:** Extract into a `Presenter` subclass rather than bloating the Controller.
- **Related tests:** `test/presentation/stateful_controller_test.dart`, `test/presentation/platform_layout_resolver_test.dart`
