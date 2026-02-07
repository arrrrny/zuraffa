import 'package:meta/meta.dart';
import 'package:zorphy/zorphy.dart';
import 'params.dart';

/// Parameters for querying a list of entities.
///
/// Use [ListQueryParams] to pass common query options like typed filtering,
/// sorting, and pagination to list-based UseCases.
///
/// The type parameter [T] represents the entity type being queried,
/// enabling type-safe [Filter], [Field], and [Sort] references.
@immutable
class ListQueryParams<T> {
  /// A search string for filtering results.
  final String? search;

  /// A type-safe filter to apply to the query.
  final Filter<T>? filter;

  /// A type-safe sort specification.
  final Sort<T>? sort;

  /// Maximum number of items to return.
  final int? limit;

  /// Number of items to skip.
  final int? offset;

  /// Optional additional parameters.
  final Params? params;

  /// Arbitrary extra parameters as an escape hatch.
  final Map<String, dynamic>? extra;

  /// Create a [ListQueryParams] instance.
  const ListQueryParams({
    this.search,
    this.filter,
    this.sort,
    this.limit,
    this.offset,
    this.params,
    this.extra,
  });

  /// Serializes the query parameters to a flat map.
  Map<String, dynamic> toQueryMap() {
    return <String, dynamic>{
      if (search != null) 'search': search,
      if (filter != null) 'filter': filter!.toJson(),
      if (sort != null) 'sort': sort!.toJson(),
      if (limit != null) 'limit': limit,
      if (offset != null) 'offset': offset,
      if (extra != null) ...extra!,
    };
  }

  /// Create a copy of [ListQueryParams] with optional new values.
  ListQueryParams<T> copyWith({
    String? search,
    Filter<T>? filter,
    Sort<T>? sort,
    int? limit,
    int? offset,
    Params? params,
    Map<String, dynamic>? extra,
    bool clearSearch = false,
    bool clearFilter = false,
    bool clearSort = false,
    bool clearExtra = false,
  }) {
    return ListQueryParams<T>(
      search: clearSearch ? null : (search ?? this.search),
      filter: clearFilter ? null : (filter ?? this.filter),
      sort: clearSort ? null : (sort ?? this.sort),
      limit: limit ?? this.limit,
      offset: offset ?? this.offset,
      params: params ?? this.params,
      extra: clearExtra ? null : (extra ?? this.extra),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ListQueryParams<T> &&
          runtimeType == other.runtimeType &&
          search == other.search &&
          filter == other.filter &&
          sort == other.sort &&
          limit == other.limit &&
          offset == other.offset &&
          params == other.params &&
          extra == other.extra;

  @override
  int get hashCode =>
      search.hashCode ^
      filter.hashCode ^
      sort.hashCode ^
      limit.hashCode ^
      offset.hashCode ^
      params.hashCode ^
      extra.hashCode;

  @override
  String toString() =>
      'ListQueryParams<$T>(search: $search, filter: $filter, sort: $sort, limit: $limit, offset: $offset, params: $params, extra: $extra)';
}
