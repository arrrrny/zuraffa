import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/product/product.dart';

class ProductState {
  const ProductState({
    this.error,
    this.productList = const <Product>[],
    this.offset = 0,
    this.limit = 10,
    this.hasMore = true,
    this.product,
    this.isWatching = false,
    this.isWatchingList = false,
  });

  /// The current error, if any
  final AppFailure? error;

  /// The single Product entity
  final Product? product;

  /// The list of Product entities
  final List<Product> productList;

  /// The current offset for pagination
  final int offset;

  /// The maximum number of items to fetch
  final int limit;

  /// Whether more items are available to fetch
  final bool hasMore;

  /// Whether watch is in progress
  final bool isWatching;

  /// Whether watchList is in progress
  final bool isWatchingList;

  ProductState copyWith({
    AppFailure? error,
    List<Product>? productList,
    int? offset,
    int? limit,
    bool? hasMore,
    Product? product,
    bool? isWatching,
    bool? isWatchingList,
  }) => ProductState(
    error: error ?? this.error,
    productList: productList ?? this.productList,
    offset: offset ?? this.offset,
    limit: limit ?? this.limit,
    hasMore: hasMore ?? this.hasMore,
    product: product ?? this.product,
    isWatching: isWatching ?? this.isWatching,
    isWatchingList: isWatchingList ?? this.isWatchingList,
  );

  bool get isLoading => isWatching || isWatchingList;

  bool get hasError => error != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductState &&
          other.error == error &&
          other.productList == productList &&
          other.offset == offset &&
          other.limit == limit &&
          other.hasMore == hasMore &&
          other.product == product &&
          other.isWatching == isWatching &&
          other.isWatchingList == isWatchingList;

  @override
  int get hashCode =>
      error.hashCode +
      productList.hashCode +
      offset.hashCode +
      limit.hashCode +
      hasMore.hashCode +
      product.hashCode +
      isWatching.hashCode +
      isWatchingList.hashCode;

  @override
  String toString() =>
      'ProductState(error: $error, productList: $productList, offset: $offset, limit: $limit, hasMore: $hasMore, product: $product)';
}
