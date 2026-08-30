/// ProductState (fixture for spec 043).
library;

import '../../../domain/entities/product/product.dart';

/// Immutable UI state for the product page.
class ProductState {
  /// Creates the state.
  const ProductState({this.product, this.isLoading = false, this.error});

  /// The loaded product, if any.
  final Product? product;

  /// Whether a load is in flight.
  final bool isLoading;

  /// Last error message, if any.
  final String? error;

  /// Returns a copy with the given fields replaced.
  ProductState copyWith({Product? product, bool? isLoading, String? error}) =>
      ProductState(
        product: product ?? this.product,
        isLoading: isLoading ?? this.isLoading,
        error: error ?? this.error,
      );
}
