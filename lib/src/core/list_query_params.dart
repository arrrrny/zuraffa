import 'package:meta/meta.dart';
import 'params.dart';

/// Parameters for querying a list of entities.
///
/// Use [ListQueryParams] to pass common query options like filtering,
/// sorting, and pagination to list-based UseCases.
@immutable
class ListQueryParams {
  /// A search string for filtering results.
  final String? search;

  /// A map of filters to apply to the query.
  final Map<String, dynamic>? filters;

  /// The field name to sort by.
  final String? sortBy;

  /// Whether to sort in descending order.
  final bool descending;

  /// Maximum number of items to return.
  final int? limit;

  /// Number of items to skip.
  final int? offset;

  /// Optional additional parameters.
  final Params? params;

  /// Create a [ListQueryParams] instance.
  const ListQueryParams({
    this.search,
    this.filters,
    this.sortBy,
    this.descending = true,
    this.limit,
    this.offset,
    this.params,
  });

  /// Create a copy of [ListQueryParams] with optional new values.
  ListQueryParams copyWith({
    String? search,
    Map<String, dynamic>? filters,
    String? sortBy,
    bool? descending,
    int? limit,
    int? offset,
    Params? params,
    bool clearSearch = false,
    bool clearFilters = false,
    bool clearSort = false,
  }) {
    return ListQueryParams(
      search: clearSearch ? null : (search ?? this.search),
      filters: clearFilters ? null : (filters ?? this.filters),
      sortBy: clearSort ? null : (sortBy ?? this.sortBy),
      descending: descending ?? this.descending,
      limit: limit ?? this.limit,
      offset: offset ?? this.offset,
      params: params ?? this.params,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ListQueryParams &&
          runtimeType == other.runtimeType &&
          search == other.search &&
          filters == other.filters &&
          sortBy == other.sortBy &&
          descending == other.descending &&
          limit == other.limit &&
          offset == other.offset &&
          params == other.params;

  @override
  int get hashCode =>
      search.hashCode ^
      filters.hashCode ^
      sortBy.hashCode ^
      descending.hashCode ^
      limit.hashCode ^
      offset.hashCode ^
      params.hashCode;

  @override
  String toString() =>
      'ListQueryParams(search: $search, filters: $filters, sortBy: $sortBy, descending: $descending, limit: $limit, offset: $offset, params: $params)';
}
