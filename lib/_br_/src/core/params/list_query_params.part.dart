// dart format off
part of '../../../../src/core/params/list_query_params.dart';

// === zorphy:zorphy contribution.
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint
final class _ZorphyCopyWithSentinel {
  const _ZorphyCopyWithSentinel();
}

const Object _sentinel = _ZorphyCopyWithSentinel();

final class ListQueryParams<T> implements ZorphyValueBase {
  const ListQueryParams.fromTrusted({
    this.search,
    this.filter,
    this.sort,
    this.limit,
    this.offset,
    this.params,
  });

  final String? search;

  final Filter<T>? filter;

  final Sort<T>? sort;

  final int? limit;

  final int? offset;

  final Map<String, dynamic>? params;

  ListQueryParams<T> copyWith({
    Object? search = _sentinel,
    Object? filter = _sentinel,
    Object? sort = _sentinel,
    Object? limit = _sentinel,
    Object? offset = _sentinel,
    Object? params = _sentinel,
  }) {
    return ListQueryParams<T>.fromTrusted(
      search: identical(search, _sentinel) ? this.search : search as String?,
      filter: identical(filter, _sentinel) ? this.filter : filter as Filter<T>?,
      sort: identical(sort, _sentinel) ? this.sort : sort as Sort<T>?,
      limit: identical(limit, _sentinel) ? this.limit : limit as int?,
      offset: identical(offset, _sentinel) ? this.offset : offset as int?,
      params: identical(params, _sentinel)
          ? this.params
          : params as Map<String, dynamic>?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ListQueryParams &&
        this.search == other.search &&
        this.filter == other.filter &&
        this.sort == other.sort &&
        this.limit == other.limit &&
        this.offset == other.offset &&
        this.params == other.params;
  }

  @override
  int get hashCode =>
      Object.hashAll([search, filter, sort, limit, offset, params]);

  @override
  String toString() =>
      'ListQueryParams(search: $search, filter: $filter, sort: $sort, limit: $limit, offset: $offset, params: $params)';
}

