import 'package:flutter/widgets.dart';

import '../slices/signal_slice.dart';

/// A widget that rebuilds only when its bound [SignalSlice] changes.
///
/// Unlike v5's full-state rebuild, [FragmentBuilder] subscribes to a
/// single slice, achieving O(1) rebuild granularity.
///
/// ```dart
/// FragmentBuilder<Product>(
///   slice: presenter.slice<Product>('product'),
///   builder: (context, product, error) {
///     if (product == null) return const LoadingWidget();
///     return ProductCard(product: product);
///   },
/// )
/// ```
class FragmentBuilder<T> extends StatefulWidget {
  const FragmentBuilder({
    super.key,
    required this.slice,
    required this.builder,
    this.loadingBuilder,
    this.errorBuilder,
  });

  /// The slice to subscribe to.
  final SignalSlice<T> slice;

  /// Called with the slice's data and error state.
  final Widget Function(BuildContext context, T? data, Object? error) builder;

  /// Optional widget to show while loading.
  final WidgetBuilder? loadingBuilder;

  /// Optional widget to show on error.
  final Widget Function(BuildContext context, Object error)? errorBuilder;

  @override
  State<FragmentBuilder<T>> createState() => _FragmentBuilderState<T>();
}

class _FragmentBuilderState<T> extends State<FragmentBuilder<T>> {
  T? _data;
  Object? _error;
  late final _subscription = widget.slice.listen((data, err) {
    setState(() {
      _data = data;
      _error = err;
    });
  });

  @override
  void initState() {
    super.initState();
    // Eager read current state
    _data = widget.slice.data;
    _error = widget.slice.error;
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.slice.isLoading &&
        _data == null &&
        widget.loadingBuilder != null) {
      return widget.loadingBuilder!(context);
    }
    if (_error != null && widget.errorBuilder != null) {
      return widget.errorBuilder!(context, _error!);
    }
    return widget.builder(context, _data, _error);
  }
}
