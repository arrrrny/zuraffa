import 'package:flutter/widgets.dart';

/// Base widget for all zuraffa v6 views with typed controller access
/// and lifecycle hooks.
///
/// ```dart
/// class ProductDetailView extends ControlledWidget<ProductDetailPresenter> {
///   const ProductDetailView({super.key, required super.controller});
///
///   @override
///   void onInit() {
///     controller.domain.slice<Product>('product')?.refresh();
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return FragmentBuilder<Product>(
///       slice: controller.domain.slice<Product>('product')!,
///       builder: (context, product) => ProductCard(product: product),
///     );
///   }
/// }
/// ```
abstract class ControlledWidget<C> extends StatefulWidget {
  const ControlledWidget({super.key, required this.controller});

  /// The presenter/controller for this view.
  final C controller;

  /// Called once after the widget is inserted into the tree.
  /// Override to trigger initial data loading.
  void onInit() {}

  /// Called when the widget is removed from the tree.
  /// Override to clean up subscriptions or timers.
  void onDispose() {}

  @override
  State<ControlledWidget<C>> createState() => _ControlledWidgetState<C>();
}

class _ControlledWidgetState<C> extends State<ControlledWidget<C>> {
  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Subclasses override build() via the abstract widget's build method.
    // This is a fallback that should never be called.
    throw UnimplementedError('Subclasses must override build()');
  }
}
