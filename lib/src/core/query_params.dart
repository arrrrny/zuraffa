import 'package:meta/meta.dart';
import 'package:zorphy/zorphy.dart';
import 'params.dart';

/// Parameters for querying a single entity by a field (usually ID or slug).
///
/// The type parameter [T] represents the entity type being queried,
/// enabling type-safe [Filter] references when the entity has filterable fields.
@immutable
class QueryParams<T> {
  /// Type-safe filter to identify the entity.
  final Filter<T>? filter;

  /// Optional additional parameters for the query.
  final Params? params;

  /// Create a [QueryParams] instance.
  const QueryParams({this.filter, this.params});

  /// Serializes the query parameters to a flat map.
  Map<String, dynamic> toQueryMap() {
    return <String, dynamic>{
      if (filter != null) 'filter': filter!.toJson(),
      if (params != null) ...?params!.params,
    };
  }

  /// Create a copy of [QueryParams] with optional new values.
  QueryParams<T> copyWith({
    Filter<T>? filter,
    Params? params,
    bool clearFilter = false,
    bool clearParams = false,
  }) {
    return QueryParams<T>(
      filter: clearFilter ? null : (filter ?? this.filter),
      params: clearParams ? null : (params ?? this.params),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QueryParams<T> &&
          runtimeType == other.runtimeType &&
          filter == other.filter &&
          params == other.params;

  @override
  int get hashCode => filter.hashCode ^ params.hashCode;

  @override
  String toString() => 'QueryParams<$T>(filter: $filter, params: $params)';
}

/// Extension to query a single entity from an iterable using QueryParams.
extension QueryParamsExtension<T> on Iterable<T> {
  /// Query a single entity matching the filter.
  /// Throws if no entity matches.
  T query(QueryParams<T>? params) {
    if (params?.filter == null) {
      return first;
    }
    return where((item) => params!.filter!.matches(item)).first;
  }
}
