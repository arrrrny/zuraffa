import 'package:flutter/widgets.dart';
import 'package:zuraffa/zuraffa.dart';

/// A widget that rebuilds only when its bound [SignalSlice] changes,
/// with built-in skeleton loading, error boundary, and empty state.
///
/// ```dart
/// FragmentBuilder<Product>(
///   slice: presenter.domain.slice<Product>('product'),
///   onLoading: (context) => const ProductSkeleton(),
///   onError: (context, error) => ErrorCard(error: error),
///   onEmpty: (context) => const EmptyProductView(),
///   builder: (context, product) => ProductCard(product: product),
/// )
/// ```
class FragmentBuilder<T> extends StatefulWidget {
  const FragmentBuilder({
    super.key,
    required this.slice,
    required this.builder,
    this.onLoading,
    this.onError,
    this.onEmpty,
  });

  final SignalSlice<T> slice;
  final Widget Function(BuildContext context, T data) builder;
  final WidgetBuilder? onLoading;
  final Widget Function(BuildContext context, AppFailure error)? onError;
  final WidgetBuilder? onEmpty;

  @override
  State<FragmentBuilder<T>> createState() => _FragmentBuilderState<T>();
}

class _FragmentBuilderState<T> extends State<FragmentBuilder<T>> {
  T? _data;
  AppFailure? _error;
  bool _isLoading = true;
  late final _subscription = widget.slice.listen((data, err) {
    setState(() {
      _data = data;
      _error = err;
      _isLoading = widget.slice.isLoading && data == null;
    });
  });

  @override
  void initState() {
    super.initState();
    _data = widget.slice.data;
    _error = widget.slice.error;
    _isLoading = widget.slice.isLoading && _data == null;
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && widget.onLoading != null) {
      return widget.onLoading!(context);
    }
    if (_error != null && widget.onError != null) {
      return widget.onError!(context, _error!);
    }
    if (_data == null && widget.onEmpty != null) {
      return widget.onEmpty!(context);
    }
    if (_data != null) {
      return widget.builder(context, _data as T);
    }
    // Fallback: loading without skeleton
    return const SizedBox.shrink();
  }
}
