import 'widget_host.dart';

/// Base class for all zuraffa v6 views with typed controller access and
/// automatic lifecycle management.
///
/// `ControlledWidget` is the pure-Dart presentation contract of v6 Track 2.4:
/// subclasses receive a typed controller `C`, and the hosting [WidgetHost]
/// invokes [onInit] once on mount and [onDispose] once on unmount — no manual
/// lifecycle wiring anywhere (spec 038 FR-001, FR-007).
///
/// The controller is a final field set at construction, so it is always
/// available — never null, never uninitialized — including inside [onInit].
///
/// Views rebuild granularly: instead of the view shell re-running, the
/// fragments attached in [build] (see [FragmentBuilder], [SignalBuilder])
/// each rebuild only when their own slice or signal changes.
///
/// ```dart
/// class ProductDetailView extends ControlledWidget<ProductDetailPresenter> {
///   ProductDetailView({required super.controller});
///
///   @override
///   void onInit() {
///     // Trigger initial data loading for the domain slices.
///     controller.domain.slice('product')?.refresh();
///   }
///
///   @override
///   void onDispose() {
///     // Optional teardown — subscriptions are already cancelled by the host.
///   }
///
///   @override
///   Object? build(ViewContext context) {
///     context.attach(FragmentBuilder<Product>(
///       slice: controller.domain.slice<Product>('product')!,
///       builder: (context, product) => ProductCard(product: product),
///     ));
///     return null;
///   }
/// }
/// ```
abstract class ControlledWidget<C> {
  /// Creates a view bound to [controller].
  ///
  /// The controller is typed as `C` and available immediately — before
  /// [onInit] and for the whole lifetime of the view.
  const ControlledWidget({required this.controller});

  /// The typed controller (presenter) that owns this view's business logic,
  /// use-case invocations, and state.
  final C controller;

  /// Called exactly once after the view is mounted, before the first
  /// [build].
  ///
  /// The [controller] is guaranteed to be initialized here. Override to
  /// trigger initial data loading — e.g. `controller.domain.slice(k)?.refresh()`.
  /// The base implementation is a no-op, so plain overrides are fine.
  void onInit() {}

  /// Called exactly once when the view is unmounted, after every attached
  /// fragment has been detached.
  ///
  /// Override to clean up timers or resources the controller does not own.
  /// Fragment subscriptions are already cancelled by the host, so most views
  /// do not need this hook. The base implementation is a no-op.
  void onDispose() {}

  /// Wires the view's reactive fragments and returns an opaque render
  /// output.
  ///
  /// Runs exactly once per mount. Granular rebuilds happen at the fragment
  /// level afterwards — the shell itself does not re-run (that is the point
  /// of the v6 pattern). Attach fragments via [ViewContext.attach]; the
  /// returned value is interpreted by the hosting layer (a Flutter binding
  /// renders it; tests and tools read fragment outputs directly).
  ///
  /// The default implementation returns `null`, so a view whose entire UI is
  /// expressed through attached fragments needs no override.
  Object? build(ViewContext context) => null;
}
