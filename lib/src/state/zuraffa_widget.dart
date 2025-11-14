import 'package:flutter/widgets.dart';
import 'zuraffa_scope.dart';
import 'zuraffa_ref.dart';
import 'provider_base.dart';

/// ZuraffaWidget - Base class for widgets that use providers
///
/// Replaces StatelessWidget with automatic provider integration.
/// The ref is automatically injected into your build method.
///
/// Example:
/// ```dart
/// class ProductPage extends ZuraffaWidget {
///   final String productId;
///
///   const ProductPage({Key? key, required this.productId}) : super(key: key);
///
///   @override
///   Widget build(BuildContext context, ZuraffaRef ref) {
///     final product = ref.watch(getProductProvider(productId));
///
///     return Scaffold(
///       appBar: AppBar(title: Text(product.name)),
///       body: Text(product.description),
///     );
///   }
/// }
/// ```
abstract class ZuraffaWidget extends StatefulWidget {
  const ZuraffaWidget({Key? key}) : super(key: key);

  /// Build your widget with access to ref
  ///
  /// Use ref.watch() to subscribe to providers and rebuild when they change.
  /// Use ref.read() to access providers without subscribing.
  Widget build(BuildContext context, ZuraffaRef ref);

  @override
  State<ZuraffaWidget> createState() => _ZuraffaWidgetState();
}

class _ZuraffaWidgetState extends State<ZuraffaWidget> {
  late ZuraffaRefImpl _ref;
  final Set<ProviderBase> _previousWatchedProviders = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Get container from scope
    final container = ZuraffaScope.of(context);

    // Create or recreate ref
    if (!_isInitialized) {
      _ref = ZuraffaRefImpl(container);
      _setupListeners();
      _isInitialized = true;
    } else {
      // Update container if it changed
      _ref = ZuraffaRefImpl(container);
      _setupListeners();
    }
  }

  bool _isInitialized = false;

  void _setupListeners() {
    // Remove old listeners
    for (final provider in _previousWatchedProviders) {
      ZuraffaScope.of(context).unlisten(provider, _onProviderChange);
    }
    _previousWatchedProviders.clear();

    // Will be populated during build
  }

  void _onProviderChange() {
    if (mounted && _ref.mounted) {
      setState(() {
        // Rebuild when a watched provider changes
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Clear previous watched providers before build
    final previousProviders = Set<ProviderBase>.from(_previousWatchedProviders);
    _previousWatchedProviders.clear();

    // Build widget
    final widget = this.widget.build(context, _ref);

    // Get newly watched providers
    final newlyWatchedProviders = _ref.watchedProviders;
    _previousWatchedProviders.addAll(newlyWatchedProviders);

    // Setup listeners for newly watched providers
    for (final provider in newlyWatchedProviders) {
      if (!previousProviders.contains(provider)) {
        ZuraffaScope.of(context).listen(provider, _onProviderChange);
      }
    }

    // Remove listeners for no-longer-watched providers
    for (final provider in previousProviders) {
      if (!newlyWatchedProviders.contains(provider)) {
        ZuraffaScope.of(context).unlisten(provider, _onProviderChange);
      }
    }

    return widget;
  }

  @override
  void dispose() {
    // Remove all listeners
    for (final provider in _previousWatchedProviders) {
      ZuraffaScope.maybeOf(context)?.unlisten(provider, _onProviderChange);
    }

    _ref.dispose();
    super.dispose();
  }
}

/// Consumer widget for using providers without extending ZuraffaWidget
///
/// Useful when you need to use providers in a StatelessWidget or
/// only need providers for a small part of your widget tree.
///
/// Example:
/// ```dart
/// class MyWidget extends StatelessWidget {
///   @override
///   Widget build(BuildContext context) {
///     return ZuraffaConsumer(
///       builder: (context, ref) {
///         final count = ref.watch(counterProvider);
///         return Text('Count: $count');
///       },
///     );
///   }
/// }
/// ```
class ZuraffaConsumer extends ZuraffaWidget {
  final Widget Function(BuildContext context, ZuraffaRef ref) builder;

  const ZuraffaConsumer({
    Key? key,
    required this.builder,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, ZuraffaRef ref) {
    return builder(context, ref);
  }
}
